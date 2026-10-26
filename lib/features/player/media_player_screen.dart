import 'dart:async';
import 'dart:io';
import 'dart:ui' show AppExitResponse;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:media_kit/media_kit.dart';
import '../../data/playback/playback_engine.dart';
import 'native_playback_tools.dart';
import 'native_output_tools.dart';
import 'advanced_player_screen.dart';
import 'custom_player_strip.dart';
import '../../domain/services/advanced_player_repository.dart';
import '../../domain/services/player_library_repository.dart';
import 'desktop_playback_windows.dart';
import '../../domain/services/player_controls_repository.dart';
import '../../data/playback/remote_playback_controller.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/display_utils.dart';
import '../../data/db/app_database.dart';
import '../../data/media/subtitle_sidecars.dart';
import '../../domain/catalog/catalog_playback.dart';
import '../../domain/catalog/media_experience.dart';
import '../../domain/catalog/media_catalog_repository.dart';
import '../../data/providers/app_providers.dart';
import '../../domain/services/progress_writer.dart';
import '../../domain/services/resume_service.dart';
import '../../domain/models/app_preferences.dart';
import '../../shared/widgets/app_top_bar.dart';
import '../../shared/widgets/content_state.dart';
import '../../shared/widgets/lesson_tools_sheet.dart';
import '../../shared/widgets/next_item_countdown_dialog.dart';
import '../../shared/widgets/study_ui.dart';

class MediaPlayerScreen extends ConsumerStatefulWidget {
  const MediaPlayerScreen({
    super.key,
    required this.itemId,
    this.initialPositionSeconds,
    this.fromQueue = false,
    this.multipartRepresentationId,
  });

  final String itemId;
  final double? initialPositionSeconds;
  final bool fromQueue;
  final String? multipartRepresentationId;

  @override
  ConsumerState<MediaPlayerScreen> createState() => _MediaPlayerScreenState();
}

class _MediaPlayerScreenState extends ConsumerState<MediaPlayerScreen>
    with WidgetsBindingObserver {
  late final AppDatabase _database;
  final _subscriptions = <StreamSubscription<dynamic>>[];
  Item? _item;
  MediaExperience _experience = const MediaExperience(
    LibraryKind.mixed,
    'video',
  );
  PlaybackEngine? _player;
  MediaProgressWriter? _progressWriter;
  String? _error;
  bool _loading = true;
  bool _navigating = false;
  bool _completionHandled = false;
  double _speed = 1;
  PlayerControls _controls = PlayerControls();
  Map<String, String> _behavior = {};
  Map<String, String> _playerSkin = {};
  Color _skinColor(String key, Color fallback) {
    final raw = _playerSkin[key]?.replaceFirst('#', '');
    return raw == null
        ? fallback
        : Color(0xff000000 | int.parse(raw, radix: 16));
  }

  bool _trackAnnounced = false;
  bool _chromeHidden = false, _stopped = false, _closingWindow = false;
  bool get _fullscreen =>
      _player is NativeVlcEngine &&
      (_player! as NativeVlcEngine).diagnostics['fullscreen'] == true;
  bool get _controlsHidden =>
      _chromeHidden ||
      (_fullscreen && _behavior['fullscreenControls'] == 'false');
  Timer? _chromeTimer;
  void _revealControls() {
    if (_chromeHidden && mounted) setState(() => _chromeHidden = false);
    _chromeTimer?.cancel();
    final mode = _behavior['autoHide'] ?? 'In fullscreen only';
    final fullscreen =
        (_player is NativeVlcEngine) &&
        (_player! as NativeVlcEngine).diagnostics['fullscreen'] == true;
    if (mode == 'Always' || mode == 'In fullscreen only' && fullscreen) {
      _chromeTimer = Timer(
        Duration(
          seconds:
              (double.tryParse(_behavior['hideAfter'] ?? '3')?.round() ?? 3)
                  .clamp(1, 10),
        ),
        () {
          if (mounted && _player?.state.playing == true)
            setState(() => _chromeHidden = true);
        },
      );
    }
  }

  void _mouseAction(String action) {
    if (action != 'none') _performAction(action);
    _revealControls();
  }

  bool _rememberPath(String path) {
    if (_behavior['saveHistory'] == 'false') return false;
    final pattern = _behavior['historyExclusion'] ?? '';
    if (pattern.isEmpty) return true;
    try {
      return !RegExp(pattern).hasMatch(path);
    } catch (_) {
      return false;
    }
  }

  void _scrollAction(double dx, double dy) {
    final horizontal = dx.abs() > dy.abs(),
        action = dx.abs() > dy.abs()
            ? _controls.horizontalScroll
            : _controls.verticalScroll;
    final delta = (horizontal ? dx : dy) * (_controls.reverseScroll ? -1 : 1);
    if (action == 'volume')
      _player?.setVolume((_player!.state.volume + delta / 5).clamp(0, 100));
    if (action == 'seek') _seekRelative((delta / 4).round());
    _revealControls();
  }

  Timer? _sleepTimer;
  Object? _remoteOwner;
  late final Future<void> Function() _exitPreparation = _prepareForExit;
  Future<void> _prepareForExit() async {
    await _player?.pause();
    await _progressWriter?.flush();
    if (_player is NativeVlcEngine)
      await (_player! as NativeVlcEngine).prepareExit();
  }

  Future<bool> _finishPolicy() async {
    final action = _behavior['finished'] ?? 'Stop';
    if (!DesktopPlaybackWindows.available ||
        action == 'Stop' ||
        _player is! NativeVlcEngine)
      return false;
    try {
      await _prepareForExit();
      if (action == 'Quit')
        await DesktopPlaybackWindows.prepareOtherWindowsForExit();
      await (_player! as NativeVlcEngine).finishWindow(action);
      return true;
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Playback stopped. The window could not complete its finish action.',
            ),
          ),
        );
      return false;
    }
  }

  Future<void> _takeSnapshot() async {
    final player = _player;
    if (player is! NativeVlcEngine || !player.supports('snapshot'))
      throw UnsupportedError('Snapshot');
    final path = await player.snapshot();
    if (path == null || !mounted) return;
    if (_behavior['snapshotPreview'] == 'false') {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Snapshot saved')));
      return;
    }
    final file = File(path);
    for (var i = 0; i < 30; i++) {
      if (await file.exists() && await file.length() > 0) break;
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Snapshot saved'),
        content: Image.file(
          file,
          cacheWidth: 640,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => const Text(
            'The snapshot preview is unavailable. Open the selected save folder to view it.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  late final RemotePlaybackController _remoteController;

  void Function()? _releaseLibraryProcessing;
  @override
  void initState() {
    super.initState();
    _releaseLibraryProcessing = ref.read(libraryProcessingProvider).hold();
    WidgetsBinding.instance.addObserver(this);
    _database = ref.read(appDatabaseProvider);
    _remoteController = ref.read(remotePlaybackControllerProvider);
    _load();
  }

  Future<void> _load() async {
    PlaybackEngine? initializing;
    try {
      if (_player != null) {
        for (final subscription in _subscriptions) {
          await subscription.cancel();
        }
        _subscriptions.clear();
        await _progressWriter?.dispose();
        await _player?.dispose();
        _player = null;
        _progressWriter = null;
      }
      _completionHandled = false;
      _trackAnnounced = false;
      final item = await _database.getItemById(widget.itemId);
      if (item == null) throw StateError('This file no longer exists.');
      _experience = MediaExperience(
        await MediaCatalogRepository(_database).libraryKind(item.libraryId),
        item.itemType,
      );
      final title = widget.multipartRepresentationId;
      if (title != null) {
        // Also validates that every referenced part is still available.
        await CatalogPlayback(
          _database,
        ).adjacentPart(title, item.id, forward: true);
      }
      final requestedPosition = widget.initialPositionSeconds;
      if (requestedPosition != null &&
          (!requestedPosition.isFinite || requestedPosition < 0))
        throw const FormatException('Invalid playback position');
      if (item.unavailable) {
        throw StateError('This file is missing. Relink it from the library.');
      }
      final isRemote =
          item.filePath.startsWith('remote:') ||
          item.filePath.startsWith('http://') ||
          item.filePath.startsWith('https://');
      if (!isRemote && !await File(item.filePath).exists()) {
        throw StateError(
          'This file could not be found. Rescan or relink it from the library.',
        );
      }
      final saved = await _database.getPlaybackByItemId(item.id);
      final preferences = await ref
          .read(appPreferencesRepositoryProvider)
          .load();
      if (!mounted) return;
      final source = await ref.read(lanSyncClientProvider).sourceFor(item);
      if (!mounted) return;
      _playerSkin = await AdvancedPlayerRepository(_database).skin();
      final controlRepository = PlayerControlsRepository(_database);
      _controls = await controlRepository.load();
      _behavior = await controlRepository.nativePreferences();
      if (DesktopPlaybackWindows.available &&
          !ref.read(independentPlaybackWindowProvider) &&
          _behavior['embeddedVideo'] == 'false') {
        await DesktopPlaybackWindows.open(
          item.id,
          database: _database,
          position: widget.initialPositionSeconds,
          fromQueue: widget.fromQueue,
          title: widget.multipartRepresentationId,
        );
        if (mounted) _back();
        return;
      }
      final player = initializing = await PlaybackEngine.create(
        nativePreferences: await controlRepository.nativePreferences(),
        globalShortcuts: _controls.global,
        nextSnapshotSequence: () => _database.transaction(() async {
          await _database.customStatement(
            'INSERT INTO app_settings (key, value, updated_at) VALUES (?, ?, ?) ON CONFLICT(key) DO UPDATE SET value = CAST(value AS INTEGER) + 1, updated_at = excluded.updated_at',
            [
              'player.snapshot.sequence',
              '1',
              DateTime.now().millisecondsSinceEpoch,
            ],
          );
          return int.parse(
            (await _database.getSetting('player.snapshot.sequence'))!,
          );
        }),
      );
      if (player is NativeVlcEngine) {
        _subscriptions.add(player.actions.listen(_performAction));
        _subscriptions.add(
          player.fullscreenChanges.listen((_) {
            if (mounted) {
              setState(() {});
              _revealControls();
            }
          }),
        );
      }
      final speed = saved?.playbackSpeed ?? preferences.defaultPlaybackSpeed;
      final exactPosition =
          widget.initialPositionSeconds ??
          (_behavior['resume'] == 'false' ||
                  _behavior['continue'] == 'Never' ||
                  !_rememberPath(item.filePath)
              ? 0.0
              : null);
      var resume = exactPosition == null
          ? ResumeService.mediaResumeSeconds(
              saved?.lastPositionSeconds ?? 0,
              durationSeconds:
                  saved?.durationSeconds ?? item.durationSeconds ?? 0,
              completed: saved?.completed ?? false,
              rewindSeconds: preferences.resumeRewindSeconds,
            )
          : exactPosition.clamp(0, double.infinity);
      if (exactPosition == null &&
          resume > 0 &&
          _behavior['continue'] == 'Ask' &&
          mounted) {
        final keep = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Continue playback?'),
            content: Text(
              'Resume ${cleanDisplayTitle(item.userTitle ?? item.title)} at ${_AudioSurface._time(Duration(seconds: resume.floor()))}?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Start over'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Resume'),
              ),
            ],
          ),
        );
        if (keep != true) resume = 0;
      }
      if (!mounted) {
        await player.dispose();
        return;
      }
      await player.open(
        Media(
          source.uri.scheme == 'file' ? item.filePath : source.uri.toString(),
          httpHeaders: source.headers,
        ),
        play: false,
      );
      if (!mounted) {
        await player.dispose();
        return;
      }
      // Opening enqueues a native load; seeking before duration arrives can be ignored.
      if (player.state.duration == Duration.zero) {
        await player.stream.duration
            .firstWhere((duration) => duration > Duration.zero)
            .timeout(const Duration(seconds: 15));
      }
      if (!mounted) {
        await player.dispose();
        return;
      }
      await player.setRate(speed);
      final savedVolume = double.tryParse(
        await _database.getSetting('player.lastVolume') ?? '',
      );
      final startupVolume =
          double.tryParse(_behavior['startupVolume'] ?? '75') ?? 75;
      await player.setVolume(
        (_behavior['rememberVolume'] != 'false' && savedVolume != null
                ? savedVolume
                : startupVolume)
            .clamp(0, 100),
      );
      if (player is NativeVlcEngine) {
        await player.windowPreferences({
          ...await controlRepository.nativePreferences(),
          'independentPlaybackWindow':
              '${ref.read(independentPlaybackWindowProvider)}',
          'windowFrameKey': 'Tangerine.player.${item.id}',
          'windowTitle': item.filename,
          'videoWidth': '${player.state.width ?? 0}',
          'videoHeight': '${player.state.height ?? 0}',
        });
        final device = _behavior['outputDevice'];
        if (player.supports('devices') && device != null && device.isNotEmpty) {
          try {
            await player.setOutputDevice(device);
          } catch (_) {
            await player.setOutputDevice('');
          }
        }
        await (await NativePlaybackSettings.load(
          _database,
          item.id,
        )).apply(player);
      }
      final subtitle = await _database.getSetting('subtitle.${item.id}');
      if (subtitle != null && await File(subtitle).exists()) {
        try {
          await SubtitleSidecars.validate(
            item.filePath.startsWith('remote:') ? item.filename : item.filePath,
            subtitle,
          );
          await player.setSubtitleTrack(SubtitleTrack.uri(subtitle));
        } on FormatException {
          // A stale/mismatched companion must not prevent the title opening.
        } on FileSystemException {
          // A removed companion can be chosen again from the track picker.
        }
      }
      if (resume > 0) {
        await player.seek(Duration(milliseconds: (resume * 1000).round()));
      }
      if (!mounted) {
        await player.dispose();
        return;
      }
      if (player is NativeVlcEngine && Platform.isMacOS) {
        final repo = AdvancedPlayerRepository(_database),
            addons = await AdvancedPlayerRepository(_database).list('addons');
        for (final addon in addons.where((a) => a['enabled'] == true)) {
          try {
            await player.runAddon(
              addon['source'] as String,
              title: item.userTitle ?? item.title,
            );
          } catch (_) {
            addon['enabled'] = false;
            await repo.saveList('addons', addons);
            if (mounted)
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'An add-on failed and was disabled. Review it in Advanced player → Customize.',
                  ),
                ),
              );
          }
        }
      }
      final writer =
          MediaProgressWriter(
            database: _database,
            item: item,
            saveHistory: _rememberPath(item.filePath),
            completionThreshold: preferences.completionThreshold,
            resumeRewindSeconds: preferences.resumeRewindSeconds,
            onError: (error) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Progress could not be saved. Check available storage and try again.',
                    ),
                  ),
                );
              }
            },
          )..seed(
            position: Duration(milliseconds: (resume * 1000).round()),
            duration: Duration(
              milliseconds:
                  ((player.state.duration.inMilliseconds / 1000) * 1000)
                      .round(),
            ),
            speed: speed,
          );
      _subscriptions
        ..add(
          player.stream.volume.listen((volume) {
            if (_behavior['rememberVolume'] != 'false' && volume.isFinite)
              unawaited(
                _database.setSetting(
                  'player.lastVolume',
                  '${volume.clamp(0, 100)}',
                ),
              );
          }),
        )
        ..add(
          player.stream.position.listen((position) {
            if (_stopped) return;
            writer.schedule(
              position: position,
              duration: player.state.duration,
              speed: _speed,
            );
          }),
        )
        ..add(
          player.stream.playing.listen((playing) {
            if (playing) {
              _revealControls();
              if (!_trackAnnounced &&
                  DesktopPlaybackWindows.available &&
                  player is NativeVlcEngine) {
                _trackAnnounced = true;
                unawaited(
                  DesktopPlaybackWindows.notifyTrack(
                    cleanDisplayTitle(item.userTitle ?? item.title),
                    player.diagnostics['minimized'] == true,
                  ).catchError((Object _) {}),
                );
              }
            }
            unawaited(_setWakelock(playing));
            if (!playing) unawaited(writer.flush());
          }),
        )
        ..add(
          player.stream.completed.listen((completed) {
            if (completed && !_navigating && !_completionHandled) {
              _completionHandled = true;
              unawaited(
                _completedNaturally(autoAdvance: preferences.autoAdvance),
              );
            }
          }),
        )
        ..add(
          player.stream.error.listen((message) {
            if (message.isEmpty || !mounted) return;
            setState(() {
              _error = _friendlyPlaybackError(message);
              _loading = false;
            });
          }),
        );
      if (!mounted) {
        await writer.dispose();
        await player.dispose();
        return;
      }
      initializing = null;
      setState(() {
        _item = item;
        _player = player;
        _progressWriter = writer;
        _speed = speed;
        _loading = false;
      });
      if (DesktopPlaybackWindows.available)
        DesktopPlaybackWindows.prepareExit = _exitPreparation;
      _remoteOwner = _remoteController.attach(
        status: () => {
          'active': mounted && _player != null,
          'itemId': item.id,
          'title': item.userTitle ?? item.title,
          'playing': player.state.playing,
          'position': player.state.position.inMilliseconds / 1000,
          'duration': player.state.duration.inMilliseconds / 1000,
          'rate': player.state.rate,
          'volume': player.state.volume,
        },
        perform: (action, value) async {
          if (!mounted) return;
          switch (action) {
            case 'play':
              await player.play();
            case 'pause':
              await player.pause();
              await _progressWriter?.flush();
            case 'seek':
              await player.seek(
                Duration(
                  milliseconds: (value! * 1000).round().clamp(
                    0,
                    player.state.duration.inMilliseconds,
                  ),
                ),
              );
            case 'rate':
              await _setSpeed(value!);
            case 'volume':
              await player.setVolume(value!);
            case 'mute':
              _toggleMute();
            case 'next':
              await _navigate(forward: true);
            case 'previous':
              await _navigate(forward: false);
          }
        },
      );
      _chromeHidden =
          _behavior['compactStartup'] == 'true' && _experience.video;
      if (_behavior['startFullscreen'] == 'true' &&
          _experience.video &&
          player is NativeVlcEngine &&
          player.supports('fullscreen'))
        await player.toggleFullscreen();
      if (widget.fromQueue || _behavior['startPlaying'] != 'false')
        await player.play();
    } catch (error) {
      await initializing?.dispose();
      if (_player != null) {
        for (final subscription in _subscriptions) {
          await subscription.cancel();
        }
        _subscriptions.clear();
        await _progressWriter?.dispose();
        await _player?.dispose();
        _player = null;
        _progressWriter = null;
      }
      if (!mounted) return;
      setState(() {
        _error = _friendlyPlaybackError(error.toString());
        _loading = false;
      });
    }
  }

  String _friendlyPlaybackError(String raw) {
    final message = raw.toLowerCase();
    if (message.contains('missing') ||
        message.contains('not be found') ||
        message.contains('no longer exists')) {
      return 'The media file is missing or has moved. Relink it from the library to keep your saved progress.';
    }
    if (message.contains('unsupported') ||
        message.contains('codec') ||
        message.contains('format')) {
      return 'This media format is not supported by the player on this device.';
    }
    if (message.contains('host') || message.contains('connect')) {
      return 'Connect to this library’s desktop host in Settings, then reopen the media.';
    }
    return 'Tangerine could not start this media. Check that the file is accessible and try again.';
  }

  Future<void> _completedNaturally({required bool autoAdvance}) async {
    final writer = _progressWriter;
    if (writer != null) await writer.flush(forceComplete: true);
    if (_behavior['stopEach'] != 'true' &&
        (autoAdvance && _experience.sequential ||
            widget.fromQueue ||
            widget.multipartRepresentationId != null)) {
      await _navigate(forward: true, countdown: true);
    } else if (mounted) {
      if (await _finishPolicy()) return;
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_experience.completedLabel)));
    }
  }

  Future<void> _navigate({
    required bool forward,
    bool countdown = false,
  }) async {
    if (_navigating) return;
    final item = _item;
    if (item == null) return;
    _navigating = true;
    await _progressWriter?.flush();
    final title = widget.multipartRepresentationId;
    if (title != null) {
      try {
        final next = await CatalogPlayback(
          _database,
        ).adjacentPart(title, item.id, forward: forward);
        if (!mounted) return;
        if (next == null) {
          _navigating = false;
          if (countdown && await _finishPolicy()) return;
          if (!mounted) return;
          if (countdown) {
            context.pushReplacement('/details/${Uri.encodeComponent(title)}');
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  forward ? 'End of this title' : 'First part of this title',
                ),
              ),
            );
          }
          return;
        }
        context.pushReplacement(
          CatalogPlayback.partRoute(
            title,
            next.id,
            position: countdown ? 0 : null,
          ),
        );
      } on Object {
        _navigating = false;
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'This title’s parts changed or a file is unavailable. Reopen its details.',
              ),
            ),
          );
      }
      return;
    }
    final queueRepository = ref.read(playerLibraryRepositoryProvider);
    final queue = await queueRepository.load();
    final queueActive = widget.fromQueue && queue.current?.itemId == item.id;
    final nextId = queueActive
        ? await queueRepository.advance(
            currentItemId: item.id,
            forward: forward,
            automatic: countdown,
          )
        : null;
    final television =
        !queueActive &&
        await MediaCatalogRepository(_database).libraryKind(item.libraryId) ==
            LibraryKind.television;
    final sequential = _experience.course;
    final next = queueActive
        ? (nextId == null ? null : await _database.getItemById(nextId))
        : television
        ? await CatalogPlayback(_database).nextEpisode(item, forward: forward)
        : !sequential
        ? null
        : forward
        ? await _database.getNextSequentialItem(item.id)
        : await _database.getPreviousSequentialItem(item.id);
    if (queueActive && nextId == item.id && countdown) {
      await _player?.seek(Duration.zero);
      await _player?.play();
      _completionHandled = false;
      _navigating = false;
      return;
    }
    if (!mounted) return;
    if (countdown && next == null && await _finishPolicy()) return;
    if (!mounted) return;
    if (countdown && !queueActive) {
      final action = await showNextItemCountdownDialog(
        context: context,
        nextTitle: next == null
            ? 'Library complete'
            : cleanDisplayTitle(next.userTitle ?? next.title),
        nextType: next?.itemType ?? 'done',
      );
      if (!mounted) return;
      if (action == NextCountdownAction.backToLibrary) {
        context.go('/library/${item.libraryId}');
        return;
      }
      if (action != NextCountdownAction.startNow &&
          action != NextCountdownAction.autoStart) {
        _navigating = false;
        return;
      }
    }
    if (next == null) {
      _navigating = false;
      if (!countdown) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Choose another title or start a playback queue.'),
          ),
        );
        return;
      }
      context.go('/library/${item.libraryId}');
      return;
    }
    context.pushReplacement(
      '${_routeFor(next)}${queueActive ? '?queue=1' : ''}',
    );
  }

  String _routeFor(Item item) => switch (item.itemType) {
    'video' || 'audio' => '/player/${item.id}',
    'pdf' => '/pdf/${item.id}',
    _ => '/resource/${item.id}',
  };

  Future<void> _back() async {
    await _progressWriter?.flush();
    if (!mounted) return;
    context.go(
      ref.read(independentPlaybackWindowProvider)
          ? '/'
          : '/library/${_item?.libraryId ?? ''}',
    );
  }

  Future<void> _showQueue() async {
    final playing = _player?.state.playing ?? false;
    await _player?.pause();
    await _progressWriter?.flush();
    if (!mounted) return;
    final next = await context.push<String>(
      '/playlists?current=${widget.itemId}',
    );
    if (!mounted) return;
    if (next != null && (next != widget.itemId || !widget.fromQueue)) {
      context.pushReplacement('/player/$next?queue=1');
    } else if (playing || next != null) {
      await _player?.play();
    }
  }

  Future<void> _setSpeed(double speed) async {
    await _player?.setRate(speed);
    final player = _player;
    if (player != null) {
      _progressWriter?.schedule(
        position: player.state.position,
        duration: player.state.duration,
        speed: speed,
      );
    }
    if (mounted) setState(() => _speed = speed);
  }

  Future<void> _setCompleted(bool value) async {
    final item = _item;
    if (item == null) return;
    await _progressWriter?.flush();
    await _database.setItemCompletion(item: item, completed: value);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _experience
                .completionLabel(!value)
                .replaceFirst('Mark ', 'Marked '),
          ),
        ),
      );
    }
  }

  void _showStudyTools() {
    final item = _item;
    final player = _player;
    if (item == null || player == null || !_experience.notes) return;
    showLessonToolsSheet(
      context: context,
      database: _database,
      item: item,
      title: _experience.course ? 'Study tools' : 'Notes & bookmarks',
      currentPositionSeconds: player.state.position.inMilliseconds / 1000,
      onJumpToPosition: (seconds) {
        player.seek(Duration(milliseconds: (seconds * 1000).round()));
      },
    );
  }

  Future<void> _pickExternalSubtitle() async {
    final player = _player;
    if (player == null) return;
    final picked = await FilePicker.platform.pickFiles(
      dialogTitle: 'Choose a subtitle file',
      type: FileType.custom,
      allowedExtensions: const ['srt', 'vtt', 'ass', 'ssa', 'idx'],
      allowMultiple: false,
      withData: false,
    );
    final path = picked?.files.single.path;
    if (path == null) return;
    await _loadSubtitle(path);
  }

  Future<void> _loadSubtitle(String path) async {
    final player = _player, item = _item;
    if (player == null || item == null) return;
    try {
      await SubtitleSidecars.validate(
        item.filePath.startsWith('remote:') ? item.filename : item.filePath,
        path,
      );
      if (!mounted || !identical(player, _player)) return;
      await player.setSubtitleTrack(
        SubtitleTrack.uri(path, title: File(path).uri.pathSegments.last),
      );
      await _database.setSetting('subtitle.${item.id}', path);
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('External subtitles loaded')),
        );
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error is FormatException
                  ? error.message.toString()
                  : 'The subtitle could not be loaded.',
            ),
          ),
        );
    }
  }

  Future<void> _nearbySubtitles() async {
    final item = _item;
    if (item == null || item.filePath.startsWith('remote:')) return;
    try {
      final files = await SubtitleSidecars.discover(item.filePath);
      if (!mounted || _item?.id != item.id) return;
      final path = await showDialog<String>(
        context: context,
        builder: (context) => SimpleDialog(
          title: const Text('Subtitles for this file'),
          children: [
            if (files.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No matching subtitles were found beside this file. Edition labels must match. You can also choose an external file.',
                ),
              ),
            for (final file in files)
              SimpleDialogOption(
                onPressed: () => Navigator.pop(context, file.path),
                child: Text(file.uri.pathSegments.last),
              ),
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
      if (path != null && mounted && _item?.id == item.id)
        await _loadSubtitle(path);
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error is FormatException
                  ? error.message.toString()
                  : 'The subtitle folder could not be opened. Choose an external file.',
            ),
          ),
        );
    }
  }

  void _showTracks() {
    final player = _player;
    if (player == null) return;
    showStudyAdaptiveModal<void>(
      context: context,
      builder: (modalContext) => StreamBuilder<Tracks>(
        stream: player.stream.tracks,
        initialData: player.state.tracks,
        builder: (context, tracksSnapshot) => StreamBuilder<Track>(
          stream: player.stream.track,
          initialData: player.state.track,
          builder: (context, selectedSnapshot) {
            final tracks = tracksSnapshot.data ?? const Tracks();
            final selected = selectedSnapshot.data ?? const Track();
            return StudyModalFrame(
              title: _experience.video ? 'Audio & subtitles' : 'Audio tracks',
              description: _experience.video
                  ? 'Choose an audio track or subtitle.'
                  : 'Choose an available audio track.',
              icon: Icons.closed_caption_outlined,
              primaryAction: FilledButton(
                onPressed: () => Navigator.pop(modalContext),
                child: const Text('Done'),
              ),
              child: SizedBox(
                height: MediaQuery.sizeOf(context).height.clamp(360, 560),
                child: ListView(
                  children: [
                    Text(
                      'Audio track',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppSpace.xs),
                    if (tracks.audio.isEmpty)
                      const _TrackEmptyState(
                        icon: Icons.volume_off_outlined,
                        message: 'No alternate audio tracks are available.',
                      )
                    else
                      RadioGroup<AudioTrack>(
                        groupValue: selected.audio,
                        onChanged: (value) {
                          if (value != null) player.setAudioTrack(value);
                        },
                        child: Column(
                          children: [
                            for (final track in tracks.audio)
                              RadioListTile<AudioTrack>(
                                value: track,
                                title: Text(_trackTitle(track)),
                              ),
                          ],
                        ),
                      ),
                    if (_experience.video) ...[
                      const Divider(height: AppSpace.xl),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Subtitles',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () {
                              Navigator.pop(modalContext);
                              _pickExternalSubtitle();
                            },
                            icon: const Icon(Icons.add_rounded),
                            label: const Text('External file'),
                          ),
                        ],
                      ),
                      TextButton.icon(
                        onPressed: () {
                          Navigator.pop(modalContext);
                          _advanced(tab: 1);
                        },
                        icon: const Icon(Icons.travel_explore),
                        label: const Text('Search online subtitles'),
                      ),
                      if (_item?.filePath.startsWith('remote:') == false)
                        TextButton.icon(
                          onPressed: () {
                            Navigator.pop(modalContext);
                            _nearbySubtitles();
                          },
                          icon: const Icon(Icons.folder_open),
                          label: const Text('Find subtitles beside this file'),
                        ),
                      const SizedBox(height: AppSpace.xs),
                      if (tracks.subtitle.isEmpty)
                        const _TrackEmptyState(
                          icon: Icons.subtitles_off_outlined,
                          message: 'No embedded subtitles are available.',
                        )
                      else
                        RadioGroup<SubtitleTrack>(
                          groupValue: selected.subtitle,
                          onChanged: (value) {
                            if (value != null) player.setSubtitleTrack(value);
                          },
                          child: Column(
                            children: [
                              for (final track in tracks.subtitle)
                                RadioListTile<SubtitleTrack>(
                                  value: track,
                                  title: Text(_trackTitle(track)),
                                ),
                            ],
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  String _trackTitle(dynamic track) {
    if (track.id == 'auto') return 'Automatic';
    if (track.id == 'no') return 'Off';
    return track.title?.toString().trim().isNotEmpty == true
        ? track.title.toString()
        : track.language?.toString().trim().isNotEmpty == true
        ? track.language.toString().toUpperCase()
        : 'Track ${track.id}';
  }

  void _performAction(String action) {
    unawaited(
      _dispatchAction(action).catchError((Object error) {
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                error is UnsupportedError
                    ? 'This control is unavailable on this platform.'
                    : 'The player action could not finish.',
              ),
            ),
          );
      }),
    );
  }

  Future<void> _dispatchAction(String action) async {
    final player = _player;
    if (player == null) return;
    if (action.startsWith('pointer.')) {
      if (action == 'pointer.single') _mouseAction(_controls.singleClick);
      if (action == 'pointer.double') _mouseAction(_controls.doubleClick);
      if (action == 'pointer.hover') _revealControls();
      if (action.startsWith('pointer.scroll:')) {
        final fields = action.split(':');
        if (fields.length == 3)
          _scrollAction(
            double.tryParse(fields[1]) ?? 0,
            double.tryParse(fields[2]) ?? 0,
          );
      }
      return;
    }
    switch (action) {
      case 'window.close':
        if (_closingWindow) return;
        _closingWindow = true;
        try {
          await player.pause();
          await _progressWriter?.flush();
          if (player is NativeVlcEngine) await player.closeWindow();
        } catch (_) {
          _closingWindow = false;
          rethrow;
        }
      case 'playPause':
        _stopped = false;
        _togglePlay();
        _revealControls();
      case 'stop':
        await _progressWriter?.flush();
        _stopped = true;
        await player.pause();
        await player.seek(Duration.zero);
        _revealControls();
      case 'seekBack':
        _seekRelative(-_controls.skipSeconds);
      case 'seekForward':
        _seekRelative(_controls.skipSeconds);
      case 'mute':
        _toggleMute();
      case 'next':
        await _navigate(forward: true);
      case 'previous':
        await _navigate(forward: false);
      case 'volumeUp':
        await player.setVolume(
          (player.state.volume + _controls.volumeStep).clamp(0, 100),
        );
      case 'volumeDown':
        await player.setVolume(
          (player.state.volume - _controls.volumeStep).clamp(0, 100),
        );
      case 'position':
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '${_AudioSurface._time(player.state.position)} / ${_AudioSurface._time(player.state.duration)}',
              ),
            ),
          );
      case 'hideUI':
        setState(() => _chromeHidden = !_chromeHidden);
      case 'escape':
        if (player is NativeVlcEngine && player.supports('escape'))
          await player.exitPresentation();
        _revealControls();
      case 'fullscreen':
        if (player is NativeVlcEngine && player.supports('fullscreen')) {
          await player.toggleFullscreen();
          _revealControls();
          if (mounted) setState(() {});
        } else {
          throw UnsupportedError('Fullscreen');
        }
      case 'miniPlayer':
        if (player is NativeVlcEngine && player.supports('mini'))
          await player.toggleMini();
        else
          throw UnsupportedError('Mini player');
      case 'snapshot':
        if (player is NativeVlcEngine && player.supports('snapshot'))
          await _takeSnapshot();
        else
          throw UnsupportedError('Snapshot');
      case 'record':
        if (player is NativeVlcEngine && player.supports('outputs'))
          await player.toggleRecording();
        else
          throw UnsupportedError('Recording');
      case 'nextFrame':
        if (player is NativeVlcEngine && player.supports('frame'))
          await player.nextFrame();
        else
          throw UnsupportedError('Frame stepping');
      case 'nextChapter':
        if (player is NativeVlcEngine && player.supports('chapters'))
          await player.setChapter(
            ((player.diagnostics['chapter'] as num?)?.toInt() ?? 0) + 1,
          );
      case 'previousChapter':
        if (player is NativeVlcEngine && player.supports('chapters'))
          await player.setChapter(
            (((player.diagnostics['chapter'] as num?)?.toInt() ?? 0) - 1).clamp(
              0,
              100000,
            ),
          );
    }
  }

  void _playerAction(String action) {
    if (action == 'newWindow') {
      unawaited(
        DesktopPlaybackWindows.open(
          widget.itemId,
          database: _database,
          position: _player!.state.position.inMilliseconds / 1000,
          fromQueue: widget.fromQueue,
          title: widget.multipartRepresentationId,
        ).catchError((Object _) {
          if (mounted)
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'A playback window could not open. Close an unused window and try again.',
                ),
              ),
            );
        }),
      );
    }
    if (action == 'queue') _showQueue();
    if (action == 'outputs' && _player is NativeVlcEngine) {
      showStudyAdaptiveModal<void>(
        context: context,
        builder: (_) => NativeOutputTools(
          engine: _player! as NativeVlcEngine,
          onSnapshot: _takeSnapshot,
        ),
      );
    }
    if (action.startsWith('sleep:')) _setSleep(int.parse(action.substring(6)));
    if (action == 'complete') _setCompleted(true);
    if (action == 'incomplete') _setCompleted(false);
  }

  void _setSleep(int minutes) {
    _sleepTimer?.cancel();
    if (minutes > 0) {
      _sleepTimer = Timer(Duration(minutes: minutes), () async {
        await _player?.pause();
        await _progressWriter?.flush();
      });
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          minutes == 0
              ? 'Sleep timer cancelled'
              : 'Playback will pause in $minutes minutes',
        ),
      ),
    );
  }

  void _togglePlay() {
    _stopped = false;
    _player?.playOrPause();
    _revealControls();
  }

  Future<void> _setWakelock(bool enabled) async {
    try {
      await WakelockPlus.toggle(
        enable: enabled && _behavior['preventSleep'] != 'false',
      );
    } on PlatformException {
      // Playback remains usable when keeping the display awake is unavailable.
    } on MissingPluginException {
      // Some desktop hosts and test harnesses do not expose this capability.
    }
  }

  void _seekRelative(int seconds) {
    final player = _player;
    if (player == null) return;
    final target = player.state.position + Duration(seconds: seconds);
    final end = player.state.duration;
    player.seek(
      target < Duration.zero
          ? Duration.zero
          : end > Duration.zero && target > end
          ? end
          : target,
    );
  }

  void _toggleMute() {
    final player = _player;
    if (player == null) return;
    player.setVolume(player.state.volume == 0 ? 100 : 0);
  }

  @override
  Future<AppExitResponse> didRequestAppExit() async {
    await _progressWriter?.flush();
    return AppExitResponse.exit;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) unawaited(_progressWriter?.flush());
    if (state == AppLifecycleState.paused &&
        (Platform.isAndroid || Platform.isIOS))
      unawaited(_player?.pause());
  }

  @override
  void dispose() {
    _releaseLibraryProcessing?.call();
    if (identical(DesktopPlaybackWindows.prepareExit, _exitPreparation))
      DesktopPlaybackWindows.prepareExit = null;
    WidgetsBinding.instance.removeObserver(this);
    _sleepTimer?.cancel();
    _chromeTimer?.cancel();
    _remoteController.detach(_remoteOwner);
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    if (_player != null) unawaited(_setWakelock(false));
    unawaited(_progressWriter?.dispose());
    unawaited(_player?.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final item = _item;
    final compact = MediaQuery.sizeOf(context).width < 700;
    return CallbackShortcuts(
      bindings: {
        for (final row in <(bool, int)>[
          (false, _controls.veryShortSkip),
          (true, _controls.mediumSkip),
        ])
          for (final forward in [false, true])
            SingleActivator(
              forward
                  ? LogicalKeyboardKey.arrowRight
                  : LogicalKeyboardKey.arrowLeft,
              control: !row.$1,
              shift: row.$1,
            ): () =>
                _seekRelative(forward ? row.$2 : -row.$2),
        for (final forward in [false, true])
          SingleActivator(
            forward
                ? LogicalKeyboardKey.arrowRight
                : LogicalKeyboardKey.arrowLeft,
            alt: true,
          ): () =>
              _seekRelative(forward ? _controls.longSkip : -_controls.longSkip),
        for (final binding in _controls.local.entries)
          ?PlayerControls.activator(binding.value): () =>
              _performAction(binding.key),
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          appBar: _controlsHidden && _experience.video
              ? null
              : AppTopBar(
                  title: cleanDisplayTitle(
                    item?.userTitle ?? item?.title ?? 'Player',
                  ),
                  showBack: true,
                  showHome: true,
                  onBack: _back,
                  actions: [
                    if (_player is NativeVlcEngine)
                      IconButton(
                        tooltip: 'Advanced player workflows',
                        onPressed: () => _advanced(),
                        icon: const Icon(Icons.video_settings),
                      ),
                    if (_player is NativeVlcEngine)
                      IconButton(
                        tooltip: 'Playback tools',
                        onPressed: () => showStudyAdaptiveModal<void>(
                          context: context,
                          builder: (_) => NativePlaybackTools(
                            engine: _player! as NativeVlcEngine,
                            database: _database,
                            itemId: widget.itemId,
                            video: _experience.video,
                          ),
                        ),
                        icon: const Icon(Icons.tune),
                      ),
                    if (!compact &&
                        (_experience.sequential ||
                            widget.fromQueue ||
                            widget.multipartRepresentationId != null))
                      IconButton(
                        tooltip: 'Previous',
                        onPressed: item == null
                            ? null
                            : () => _navigate(forward: false),
                        icon: const Icon(Icons.skip_previous),
                      ),
                    if (_experience.notes)
                      IconButton(
                        tooltip: _experience.notesLabel,
                        onPressed: item == null ? null : _showStudyTools,
                        icon: const Icon(Icons.note_alt_outlined),
                      ),
                    if (!compact) ...[
                      IconButton(
                        tooltip: _experience.video
                            ? 'Audio and subtitle tracks'
                            : 'Audio tracks',
                        onPressed: item == null ? null : _showTracks,
                        icon: const Icon(Icons.closed_caption_outlined),
                      ),
                      PopupMenuButton<double>(
                        tooltip: 'Playback speed',
                        initialValue: _speed,
                        onSelected: _setSpeed,
                        itemBuilder: (_) => playbackSpeeds
                            .map(
                              (speed) => PopupMenuItem(
                                value: speed,
                                child: Text('$speed×'),
                              ),
                            )
                            .toList(),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: Center(
                            child: Text(
                              '$_speed×',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ),
                      PopupMenuButton<String>(
                        tooltip: 'Playback actions',
                        onSelected: _playerAction,
                        itemBuilder: (_) => [
                          if (DesktopPlaybackWindows.available)
                            const PopupMenuItem(
                              value: 'newWindow',
                              child: Text('Open independent playback window'),
                            ),
                          const PopupMenuItem(
                            value: 'queue',
                            child: Text('Queue & playlists'),
                          ),
                          if (_player is NativeVlcEngine)
                            const PopupMenuItem(
                              value: 'outputs',
                              child: Text('Outputs & windows'),
                            ),
                          for (final minutes in [15, 30, 60, 0])
                            PopupMenuItem(
                              value: 'sleep:$minutes',
                              child: Text(
                                minutes == 0
                                    ? 'Cancel sleep timer'
                                    : 'Sleep in $minutes minutes',
                              ),
                            ),

                          if (_experience.completion)
                            PopupMenuItem(
                              value: 'complete',
                              child: Text(_experience.completionLabel(false)),
                            ),
                          if (_experience.completion)
                            PopupMenuItem(
                              value: 'incomplete',
                              child: Text(_experience.completionLabel(true)),
                            ),
                        ],
                      ),
                      IconButton(
                        tooltip: 'Next',
                        onPressed: item == null
                            ? null
                            : () => _navigate(forward: true),
                        icon: const Icon(Icons.skip_next),
                      ),
                    ] else
                      PopupMenuButton<String>(
                        tooltip: 'Player options',
                        onSelected: (value) {
                          _playerAction(value);
                          if (value == 'previous') _navigate(forward: false);
                          if (value == 'next') _navigate(forward: true);
                          if (value == 'complete') _setCompleted(true);
                          if (value == 'incomplete') _setCompleted(false);
                          if (value == 'tracks') _showTracks();
                          if (value.startsWith('speed:')) {
                            _setSpeed(double.parse(value.substring(6)));
                          }
                        },
                        itemBuilder: (_) => [
                          if (DesktopPlaybackWindows.available)
                            const PopupMenuItem(
                              value: 'newWindow',
                              child: Text('Open independent playback window'),
                            ),
                          const PopupMenuItem(
                            value: 'queue',
                            child: Text('Queue & playlists'),
                          ),
                          if (_player is NativeVlcEngine)
                            const PopupMenuItem(
                              value: 'outputs',
                              child: Text('Outputs & windows'),
                            ),
                          for (final minutes in [15, 30, 60, 0])
                            PopupMenuItem(
                              value: 'sleep:$minutes',
                              child: Text(
                                minutes == 0
                                    ? 'Cancel sleep timer'
                                    : 'Sleep in $minutes minutes',
                              ),
                            ),
                          const PopupMenuItem(
                            value: 'previous',
                            child: Text('Previous'),
                          ),
                          const PopupMenuItem(
                            value: 'next',
                            child: Text('Next'),
                          ),
                          const PopupMenuDivider(),
                          PopupMenuItem(
                            value: 'tracks',
                            child: Text(
                              _experience.video
                                  ? 'Audio and subtitles'
                                  : 'Audio tracks',
                            ),
                          ),
                          for (final speed in playbackSpeeds)
                            PopupMenuItem(
                              value: 'speed:$speed',
                              child: Text(
                                speed == _speed
                                    ? 'Playback speed: $speed× ✓'
                                    : 'Playback speed: $speed×',
                              ),
                            ),
                          const PopupMenuDivider(),
                          if (_experience.completion)
                            PopupMenuItem(
                              value: 'complete',
                              child: Text(_experience.completionLabel(false)),
                            ),
                          if (_experience.completion)
                            PopupMenuItem(
                              value: 'incomplete',
                              child: Text(_experience.completionLabel(true)),
                            ),
                        ],
                      ),
                  ],
                ),
          body: _body(),
        ),
      ),
    );
  }

  int _customizationVersion = 0;
  Future<void> _advanced({int tab = 0}) async {
    final player = _player;
    if (player is! NativeVlcEngine) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AdvancedPlayerScreen(
          activePlayer: player,
          itemId: widget.itemId,
          title: _item?.userTitle ?? _item?.title,
          initialTab: tab,
        ),
      ),
    );
    final skin = await AdvancedPlayerRepository(_database).skin();
    if (mounted)
      setState(() {
        _customizationVersion++;
        _playerSkin = skin;
      });
  }

  Future<void> _queuePolicy(bool shuffle) async {
    try {
      final repo = ref.read(playerLibraryRepositoryProvider),
          state = await ref.read(playerLibraryRepositoryProvider).load();
      if (shuffle) {
        await repo.setShuffle(!state.shuffle);
      } else {
        await repo.setRepeat(
          QueueRepeat.values[(state.repeat.index + 1) %
              QueueRepeat.values.length],
        );
      }
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              shuffle
                  ? 'Shuffle ${!state.shuffle ? 'enabled' : 'disabled'}'
                  : 'Repeat updated',
            ),
          ),
        );
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Queue policy could not be saved.')),
        );
    }
  }

  Widget _nativeTransport() => CustomPlayerStrip(
    key: ValueKey(_customizationVersion),
    player: _player!,
    database: _database,
    onTracks: _showTracks,
    onTogglePlay: _togglePlay,
    onSnapshot: _takeSnapshot,
    onQueue: _showQueue,
    onPrevious: _experience.sequential || widget.fromQueue
        ? () => _navigate(forward: false)
        : null,
    onNext: _experience.sequential || widget.fromQueue
        ? () => _navigate(forward: true)
        : null,
    onShuffle: () => _queuePolicy(true),
    onRepeat: () => _queuePolicy(false),
    onCustomize: () => _advanced(tab: 3),
  );

  Widget _body() {
    if (_loading) return const _PlayerLoadingState();
    if (_error != null) {
      return StudyPage(
        maxWidth: 760,
        child: ContentState(
          icon: Icons.play_disabled_outlined,
          title: 'This media cannot be played',
          message: _error!,
          action: FilledButton.icon(
            onPressed: _back,
            icon: const Icon(Icons.arrow_back_rounded),
            label: const Text('Back to library'),
          ),
          secondaryAction: OutlinedButton.icon(
            onPressed: () {
              setState(() {
                _loading = true;
                _error = null;
              });
              _load();
            },
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Try again'),
          ),
          tone: ContentStateTone.error,
        ),
      );
    }
    final item = _item!;
    if (item.itemType == 'audio') {
      return _AudioSurface(
        player: _player!,
        customControls: _nativeTransport(),
        skin: _playerSkin,
        item: item,
        skipSeconds: _controls.skipSeconds,
        onTogglePlay: _togglePlay,
        onSeekRelative: _seekRelative,
        showArtwork: _behavior['coverArt'] != 'false',
        saveHistory: _rememberPath(item.filePath),
        speed: _speed,
        onSetSpeed: _setSpeed,
        onPrevious:
            _experience.sequential ||
                widget.fromQueue ||
                widget.multipartRepresentationId != null
            ? () => _navigate(forward: false)
            : null,
        onNext:
            _experience.sequential ||
                widget.fromQueue ||
                widget.multipartRepresentationId != null
            ? () => _navigate(forward: true)
            : null,
        onStudy: _experience.notes ? _showStudyTools : null,
      );
    }
    return ColoredBox(
      color: _skinColor('canvas', context.studyColors.player),
      child: Column(
        children: [
          Expanded(
            child: MouseRegion(
              onHover: (_) => _revealControls(),
              child: Listener(
                onPointerSignal: (event) {
                  if (event is PointerScrollEvent)
                    GestureBinding.instance.pointerSignalResolver.register(
                      event,
                      (signal) => _scrollAction(
                        -event.scrollDelta.dx,
                        -event.scrollDelta.dy,
                      ),
                    );
                },
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _mouseAction(_controls.singleClick),
                  onDoubleTap: () => _mouseAction(_controls.doubleClick),
                  child: _player!.videoSurface(),
                ),
              ),
            ),
          ),
          if (_player is NativeVlcEngine && !_controlsHidden)
            Opacity(
              opacity:
                  (double.tryParse(_behavior['controlsOpacity'] ?? '1') ?? 1)
                      .clamp(.1, 1),
              child: _nativeTransport(),
            ),
          StreamBuilder<bool>(
            stream: _player!.stream.buffering,
            initialData: _player!.state.buffering,
            builder: (context, snapshot) {
              if (snapshot.data != true) return const SizedBox.shrink();
              return Semantics(
                liveRegion: true,
                label: 'Buffering media',
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpace.md,
                      vertical: AppSpace.sm,
                    ),
                    decoration: BoxDecoration(
                      color: context.studyColors.playerRaised.withValues(
                        alpha: .92,
                      ),
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(width: AppSpace.sm),
                        Text(
                          'Buffering…',
                          style: TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _AudioSurface extends StatelessWidget {
  const _AudioSurface({
    required this.player,
    this.customControls,
    this.skin = const {},
    required this.item,
    required this.speed,
    required this.onSetSpeed,
    required this.onPrevious,
    required this.onNext,
    required this.onStudy,
    this.showArtwork = true,
    this.saveHistory = true,
    required this.skipSeconds,
    required this.onTogglePlay,
    required this.onSeekRelative,
  });

  final PlaybackEngine player;
  final Widget? customControls;
  final Map<String, String> skin;
  Color _skinColor(String key, Color fallback) {
    final raw = skin[key]?.replaceFirst('#', '');
    return raw == null
        ? fallback
        : Color(0xff000000 | int.parse(raw, radix: 16));
  }

  final Item item;
  final bool showArtwork, saveHistory;
  final int skipSeconds;
  final VoidCallback onTogglePlay;
  final ValueChanged<int> onSeekRelative;
  final double speed;
  final ValueChanged<double> onSetSpeed;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final VoidCallback? onStudy;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: _skinColor('canvas', context.studyColors.player),
      child: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(
            AppBreakpoints.isCompact(context) ? AppSpace.sm : AppSpace.lg,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Container(
              padding: EdgeInsets.all(
                AppBreakpoints.isCompact(context) ? AppSpace.md : AppSpace.xl,
              ),
              decoration: BoxDecoration(
                color: _skinColor('panel', context.studyColors.playerRaised),
                border: Border.all(
                  color: _skinColor('divider', const Color(0xFF403C38)),
                ),
                borderRadius: BorderRadius.circular(AppRadius.xl),
                boxShadow: AppElevation.level2,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (showArtwork)
                    StudyArtwork(
                      path: item.thumbnailPath,
                      kind: 'audio',
                      size: MediaQuery.sizeOf(context).height < 750 ? 84 : 128,
                      radius: AppRadius.xl,
                    ),
                  const SizedBox(height: AppSpace.lg),
                  StudyStatusBadge(
                    label: 'Now playing',
                    icon: Icons.graphic_eq_rounded,
                    tone: StudyStatusTone.primary,
                  ),
                  const SizedBox(height: AppSpace.sm),
                  Text(
                    cleanDisplayTitle(item.userTitle ?? item.title),
                    textAlign: TextAlign.center,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: _skinColor('text', Colors.white),
                    ),
                  ),
                  const SizedBox(height: AppSpace.xxs),
                  Text(
                    '${item.filePath.startsWith('remote:') ? 'Desktop audio' : 'Local audio'} · ${saveHistory ? 'Progress saves automatically' : 'Activity saving disabled'}',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: _skinColor('muted', const Color(0xFFB3ABA5)),
                    ),
                  ),
                  const SizedBox(height: AppSpace.lg),
                  if (customControls != null)
                    customControls!
                  else ...[
                    StreamBuilder<Duration>(
                      stream: player.stream.position,
                      initialData: player.state.position,
                      builder: (context, positionSnapshot) {
                        return StreamBuilder<Duration>(
                          stream: player.stream.duration,
                          initialData: player.state.duration,
                          builder: (context, durationSnapshot) {
                            final position =
                                positionSnapshot.data ?? Duration.zero;
                            final duration =
                                durationSnapshot.data ?? Duration.zero;
                            final max = duration.inMilliseconds <= 0
                                ? 1.0
                                : duration.inMilliseconds.toDouble();
                            return Column(
                              children: [
                                Slider(
                                  value: position.inMilliseconds
                                      .clamp(0, max.toInt())
                                      .toDouble(),
                                  max: max,
                                  onChanged: duration == Duration.zero
                                      ? null
                                      : (value) => player.seek(
                                          Duration(milliseconds: value.round()),
                                        ),
                                ),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      _time(position),
                                      style: const TextStyle(
                                        color: Color(0xFFCBD6D0),
                                      ),
                                    ),
                                    Text(
                                      duration == Duration.zero
                                          ? 'Loading duration'
                                          : _time(duration),
                                      style: const TextStyle(
                                        color: Color(0xFFCBD6D0),
                                      ),
                                    ),
                                  ],
                                ),
                                StreamBuilder<double>(
                                  stream: player.stream.volume,
                                  initialData: player.state.volume,
                                  builder: (context, snapshot) => Row(
                                    children: [
                                      const Icon(
                                        Icons.volume_down_rounded,
                                        color: Colors.white,
                                      ),
                                      Expanded(
                                        child: Slider(
                                          value: (snapshot.data ?? 100).clamp(
                                            0,
                                            100,
                                          ),
                                          max: 100,
                                          onChanged: player.setVolume,
                                        ),
                                      ),
                                      const Icon(
                                        Icons.volume_up_rounded,
                                        color: Colors.white,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          },
                        );
                      },
                    ),
                    const SizedBox(height: AppSpace.md),
                    Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: AppSpace.xxs,
                      runSpacing: AppSpace.xs,
                      children: [
                        IconButton(
                          tooltip: 'Previous',
                          color: Colors.white,
                          onPressed: onPrevious,
                          icon: const Icon(Icons.skip_previous_rounded),
                        ),
                        IconButton(
                          tooltip: 'Back $skipSeconds seconds',
                          color: Colors.white,
                          onPressed: () => onSeekRelative(-skipSeconds),
                          icon: const Icon(Icons.fast_rewind_rounded),
                        ),
                        const SizedBox(width: AppSpace.xs),
                        StreamBuilder<bool>(
                          stream: player.stream.playing,
                          initialData: player.state.playing,
                          builder: (context, snapshot) => IconButton.filled(
                            tooltip: snapshot.data == true ? 'Pause' : 'Play',
                            iconSize: 36,
                            style: IconButton.styleFrom(
                              minimumSize: const Size(68, 68),
                            ),
                            onPressed: onTogglePlay,
                            icon: Icon(
                              snapshot.data == true
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpace.xs),
                        IconButton(
                          tooltip: 'Forward $skipSeconds seconds',
                          color: Colors.white,
                          onPressed: () => onSeekRelative(skipSeconds),
                          icon: const Icon(Icons.fast_forward_rounded),
                        ),
                        IconButton(
                          tooltip: 'Next',
                          color: Colors.white,
                          onPressed: onNext,
                          icon: const Icon(Icons.skip_next_rounded),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: AppSpace.lg),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: AppSpace.xs,
                    runSpacing: AppSpace.xs,
                    children: [
                      PopupMenuButton<double>(
                        tooltip: 'Playback speed',
                        initialValue: speed,
                        onSelected: onSetSpeed,
                        itemBuilder: (_) => [
                          for (final value in playbackSpeeds)
                            PopupMenuItem(value: value, child: Text('$value×')),
                        ],
                        child: _PlayerPill(
                          icon: Icons.speed_rounded,
                          label: '$speed× speed',
                        ),
                      ),
                      StreamBuilder<double>(
                        stream: player.stream.volume,
                        initialData: player.state.volume,
                        builder: (context, snapshot) => InkWell(
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                          onTap: () =>
                              player.setVolume(snapshot.data == 0 ? 100 : 0),
                          child: _PlayerPill(
                            icon: snapshot.data == 0
                                ? Icons.volume_off_rounded
                                : Icons.volume_up_rounded,
                            label: snapshot.data == 0 ? 'Unmute' : 'Mute',
                          ),
                        ),
                      ),
                      if (onStudy != null)
                        InkWell(
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                          onTap: onStudy,
                          child: const _PlayerPill(
                            icon: Icons.note_alt_outlined,
                            label: 'Study tools',
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  static String _time(Duration value) {
    final hours = value.inHours;
    final minutes = value.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');
    return hours > 0 ? '$hours:$minutes:$seconds' : '$minutes:$seconds';
  }
}

class _PlayerPill extends StatelessWidget {
  const _PlayerPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.md,
        vertical: AppSpace.sm,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF1D2924),
        border: Border.all(color: const Color(0xFF403C38)),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: const Color(0xFFE69A50), size: 20),
          const SizedBox(width: AppSpace.xs),
          Text(label, style: const TextStyle(color: Colors.white)),
        ],
      ),
    );
  }
}

class _PlayerLoadingState extends StatelessWidget {
  const _PlayerLoadingState();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: context.studyColors.player,
      child: Semantics(
        liveRegion: true,
        label: 'Preparing media',
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: context.studyColors.playerRaised,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
                child: const Padding(
                  padding: EdgeInsets.all(AppSpace.lg),
                  child: CircularProgressIndicator(color: Color(0xFFE69A50)),
                ),
              ),
              const SizedBox(height: AppSpace.lg),
              Text(
                'Preparing your media',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(color: Colors.white),
              ),
              const SizedBox(height: AppSpace.xs),
              const Text(
                'Loading media and restoring your place…',
                style: TextStyle(color: Color(0xFFB3ABA5)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TrackEmptyState extends StatelessWidget {
  const _TrackEmptyState({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpace.md),
      decoration: BoxDecoration(
        color: context.studyColors.surfaceSubtle,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        children: [
          Icon(icon, color: context.studyColors.textMuted),
          const SizedBox(width: AppSpace.sm),
          Expanded(child: Text(message)),
        ],
      ),
    );
  }
}
