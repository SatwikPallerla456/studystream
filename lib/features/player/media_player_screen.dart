import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/display_utils.dart';
import '../../data/db/app_database.dart';
import '../../data/providers/app_providers.dart';
import '../../domain/services/progress_writer.dart';
import '../../domain/services/resume_service.dart';
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
  });

  final String itemId;
  final double? initialPositionSeconds;

  @override
  ConsumerState<MediaPlayerScreen> createState() => _MediaPlayerScreenState();
}

class _MediaPlayerScreenState extends ConsumerState<MediaPlayerScreen>
    with WidgetsBindingObserver {
  late final AppDatabase _database;
  final _subscriptions = <StreamSubscription<dynamic>>[];
  Item? _item;
  Player? _player;
  VideoController? _videoController;
  MediaProgressWriter? _progressWriter;
  String? _error;
  bool _loading = true;
  bool _navigating = false;
  bool _completionHandled = false;
  double _speed = 1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _database = ref.read(appDatabaseProvider);
    _load();
  }

  Future<void> _load() async {
    try {
      final item = await _database.getItemById(widget.itemId);
      if (item == null) throw StateError('This lesson no longer exists.');
      if (item.unavailable) {
        throw StateError('This file is missing. Relink it from the library.');
      }
      final isRemote =
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
      final player = Player();
      final controller = VideoController(player);
      final speed = saved?.playbackSpeed ?? preferences.defaultPlaybackSpeed;
      final exactPosition = widget.initialPositionSeconds;
      final resume = exactPosition == null
          ? ResumeService.mediaResumeSeconds(
              saved?.lastPositionSeconds ?? 0,
              durationSeconds:
                  saved?.durationSeconds ?? item.durationSeconds ?? 0,
              completed: saved?.completed ?? false,
              rewindSeconds: preferences.resumeRewindSeconds,
            )
          : exactPosition.clamp(0, double.infinity);
      await player.open(Media(item.filePath), play: false);
      await player.setRate(speed);
      if (resume > 0) {
        await player.seek(Duration(milliseconds: (resume * 1000).round()));
      }
      final writer =
          MediaProgressWriter(
            database: _database,
            item: item,
            completionThreshold: preferences.completionThreshold,
            resumeRewindSeconds: preferences.resumeRewindSeconds,
          )..seed(
            position: Duration(
              milliseconds:
                  ((exactPosition ?? saved?.lastPositionSeconds ?? 0) * 1000)
                      .round(),
            ),
            duration: Duration(
              milliseconds:
                  ((saved?.durationSeconds ?? item.durationSeconds ?? 0) * 1000)
                      .round(),
            ),
            speed: speed,
          );
      _subscriptions
        ..add(
          player.stream.position.listen((position) {
            writer.schedule(
              position: position,
              duration: player.state.duration,
              speed: _speed,
            );
          }),
        )
        ..add(
          player.stream.playing.listen((playing) {
            WakelockPlus.toggle(enable: playing);
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
      setState(() {
        _item = item;
        _player = player;
        _videoController = controller;
        _progressWriter = writer;
        _speed = speed;
        _loading = false;
      });
    } catch (error) {
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
      return 'The lesson file is missing or has moved. Relink it from the library to keep your saved progress.';
    }
    if (message.contains('unsupported') ||
        message.contains('codec') ||
        message.contains('format')) {
      return 'This media format is not supported by the player on this device.';
    }
    return 'StudyStream could not start this lesson. Check that the file is accessible and try again.';
  }

  Future<void> _completedNaturally({required bool autoAdvance}) async {
    final writer = _progressWriter;
    if (writer != null) await writer.flush(forceComplete: true);
    if (autoAdvance) {
      await _navigate(forward: true, countdown: true);
    } else if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Lesson completed')));
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
    final next = forward
        ? await _database.getNextSequentialItem(item.id)
        : await _database.getPreviousSequentialItem(item.id);
    if (!mounted) return;
    if (countdown) {
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
      context.go('/library/${item.libraryId}');
      return;
    }
    context.pushReplacement(_routeFor(next));
  }

  String _routeFor(Item item) => switch (item.itemType) {
    'video' || 'audio' => '/player/${item.id}',
    'pdf' => '/pdf/${item.id}',
    _ => '/resource/${item.id}',
  };

  Future<void> _back() async {
    await _progressWriter?.flush();
    if (!mounted) return;
    context.go('/library/${_item?.libraryId ?? ''}');
  }

  Future<void> _setSpeed(double speed) async {
    await _player?.setRate(speed);
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
          content: Text(value ? 'Marked complete' : 'Marked incomplete'),
        ),
      );
    }
  }

  void _showStudyTools() {
    final item = _item;
    final player = _player;
    if (item == null || player == null) return;
    showLessonToolsSheet(
      context: context,
      database: _database,
      item: item,
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
      allowedExtensions: const ['srt', 'vtt', 'ass', 'ssa'],
      allowMultiple: false,
      withData: false,
    );
    final path = picked?.files.single.path;
    if (path == null) return;
    try {
      await player.setSubtitleTrack(
        SubtitleTrack.uri(path, title: picked!.files.single.name),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('External subtitles loaded')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not load subtitles: $error')),
        );
      }
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
              title: 'Audio & subtitles',
              description:
                  'Choose an embedded track or add a subtitle file from this device.',
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

  void _togglePlay() => _player?.playOrPause();

  void _seekRelative(int seconds) {
    final player = _player;
    if (player == null) return;
    final target = player.state.position + Duration(seconds: seconds);
    player.seek(target < Duration.zero ? Duration.zero : target);
  }

  void _toggleMute() {
    final player = _player;
    if (player == null) return;
    player.setVolume(player.state.volume == 0 ? 100 : 0);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) unawaited(_progressWriter?.flush());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    unawaited(WakelockPlus.disable());
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
        const SingleActivator(LogicalKeyboardKey.space): _togglePlay,
        const SingleActivator(LogicalKeyboardKey.arrowLeft): () =>
            _seekRelative(-10),
        const SingleActivator(LogicalKeyboardKey.arrowRight): () =>
            _seekRelative(10),
        const SingleActivator(LogicalKeyboardKey.keyM): _toggleMute,
        const SingleActivator(LogicalKeyboardKey.keyN): () =>
            _navigate(forward: true),
        const SingleActivator(LogicalKeyboardKey.keyP): () =>
            _navigate(forward: false),
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          appBar: AppTopBar(
            title: cleanDisplayTitle(
              item?.userTitle ?? item?.title ?? 'Player',
            ),
            showBack: true,
            showHome: true,
            onBack: _back,
            actions: [
              if (!compact)
                IconButton(
                  tooltip: 'Previous lesson',
                  onPressed: item == null
                      ? null
                      : () => _navigate(forward: false),
                  icon: const Icon(Icons.skip_previous),
                ),
              IconButton(
                tooltip: 'Study tools',
                onPressed: item == null ? null : _showStudyTools,
                icon: const Icon(Icons.note_alt_outlined),
              ),
              if (!compact) ...[
                IconButton(
                  tooltip: 'Audio and subtitle tracks',
                  onPressed: item == null ? null : _showTracks,
                  icon: const Icon(Icons.closed_caption_outlined),
                ),
                PopupMenuButton<double>(
                  tooltip: 'Playback speed',
                  initialValue: _speed,
                  onSelected: _setSpeed,
                  itemBuilder: (_) => [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0]
                      .map(
                        (speed) =>
                            PopupMenuItem(value: speed, child: Text('$speed×')),
                      )
                      .toList(),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Center(
                      child: Text(
                        '$_speed×',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ),
                PopupMenuButton<String>(
                  tooltip: 'Lesson actions',
                  onSelected: (value) => _setCompleted(value == 'complete'),
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: 'complete',
                      child: Text('Mark complete'),
                    ),
                    PopupMenuItem(
                      value: 'incomplete',
                      child: Text('Mark incomplete'),
                    ),
                  ],
                ),
                IconButton(
                  tooltip: 'Next lesson',
                  onPressed: item == null
                      ? null
                      : () => _navigate(forward: true),
                  icon: const Icon(Icons.skip_next),
                ),
              ] else
                PopupMenuButton<String>(
                  tooltip: 'Player options',
                  onSelected: (value) {
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
                    const PopupMenuItem(
                      value: 'previous',
                      child: Text('Previous lesson'),
                    ),
                    const PopupMenuItem(
                      value: 'next',
                      child: Text('Next lesson'),
                    ),
                    const PopupMenuDivider(),
                    const PopupMenuItem(
                      value: 'tracks',
                      child: Text('Audio and subtitles'),
                    ),
                    for (final speed in const [
                      0.5,
                      0.75,
                      1.0,
                      1.25,
                      1.5,
                      1.75,
                      2.0,
                    ])
                      PopupMenuItem(
                        value: 'speed:$speed',
                        child: Text(
                          speed == _speed
                              ? 'Playback speed: $speed× ✓'
                              : 'Playback speed: $speed×',
                        ),
                      ),
                    const PopupMenuDivider(),
                    const PopupMenuItem(
                      value: 'complete',
                      child: Text('Mark complete'),
                    ),
                    const PopupMenuItem(
                      value: 'incomplete',
                      child: Text('Mark incomplete'),
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

  Widget _body() {
    if (_loading) return const _PlayerLoadingState();
    if (_error != null) {
      return StudyPage(
        maxWidth: 760,
        child: ContentState(
          icon: Icons.play_disabled_outlined,
          title: 'This lesson cannot be played',
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
        item: item,
        speed: _speed,
        onSetSpeed: _setSpeed,
        onPrevious: () => _navigate(forward: false),
        onNext: () => _navigate(forward: true),
        onStudy: _showStudyTools,
      );
    }
    return ColoredBox(
      color: context.studyColors.player,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Center(
            child: Video(
              controller: _videoController!,
              controls: AdaptiveVideoControls,
              fit: BoxFit.contain,
            ),
          ),
          StreamBuilder<bool>(
            stream: _player!.stream.buffering,
            initialData: _player!.state.buffering,
            builder: (context, snapshot) {
              if (snapshot.data != true) return const SizedBox.shrink();
              return Semantics(
                liveRegion: true,
                label: 'Buffering lesson',
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
    required this.item,
    required this.speed,
    required this.onSetSpeed,
    required this.onPrevious,
    required this.onNext,
    required this.onStudy,
  });

  final Player player;
  final Item item;
  final double speed;
  final ValueChanged<double> onSetSpeed;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onStudy;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: context.studyColors.player,
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
                color: context.studyColors.playerRaised,
                border: Border.all(color: const Color(0xFF34443D)),
                borderRadius: BorderRadius.circular(AppRadius.xl),
                boxShadow: AppElevation.level2,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  StudyArtwork(
                    path: item.thumbnailPath,
                    kind: 'audio',
                    size: AppBreakpoints.isCompact(context) ? 148 : 188,
                    radius: AppRadius.xl,
                  ),
                  const SizedBox(height: AppSpace.lg),
                  const StudyStatusBadge(
                    label: 'Audio lesson',
                    icon: Icons.graphic_eq_rounded,
                    tone: StudyStatusTone.primary,
                  ),
                  const SizedBox(height: AppSpace.sm),
                  Text(
                    cleanDisplayTitle(item.userTitle ?? item.title),
                    textAlign: TextAlign.center,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(
                      context,
                    ).textTheme.headlineMedium?.copyWith(color: Colors.white),
                  ),
                  const SizedBox(height: AppSpace.xxs),
                  Text(
                    'Local audio · Progress saves automatically',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFFB8C6BF),
                    ),
                  ),
                  const SizedBox(height: AppSpace.lg),
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
                        tooltip: 'Previous lesson',
                        color: Colors.white,
                        onPressed: onPrevious,
                        icon: const Icon(Icons.skip_previous_rounded),
                      ),
                      IconButton(
                        tooltip: 'Back 10 seconds',
                        color: Colors.white,
                        onPressed: () => player.seek(
                          player.state.position - const Duration(seconds: 10),
                        ),
                        icon: const Icon(Icons.replay_10_rounded),
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
                          onPressed: player.playOrPause,
                          icon: Icon(
                            snapshot.data == true
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpace.xs),
                      IconButton(
                        tooltip: 'Forward 10 seconds',
                        color: Colors.white,
                        onPressed: () => player.seek(
                          player.state.position + const Duration(seconds: 10),
                        ),
                        icon: const Icon(Icons.forward_10_rounded),
                      ),
                      IconButton(
                        tooltip: 'Next lesson',
                        color: Colors.white,
                        onPressed: onNext,
                        icon: const Icon(Icons.skip_next_rounded),
                      ),
                    ],
                  ),
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
                          for (final value in const [
                            .5,
                            .75,
                            1.0,
                            1.25,
                            1.5,
                            1.75,
                            2.0,
                          ])
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
        border: Border.all(color: const Color(0xFF34443D)),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: const Color(0xFF85D9C1), size: 20),
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
        label: 'Preparing lesson',
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
                  child: CircularProgressIndicator(color: Color(0xFF85D9C1)),
                ),
              ),
              const SizedBox(height: AppSpace.lg),
              Text(
                'Preparing your lesson',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(color: Colors.white),
              ),
              const SizedBox(height: AppSpace.xs),
              const Text(
                'Loading media and restoring your place…',
                style: TextStyle(color: Color(0xFFB8C6BF)),
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
