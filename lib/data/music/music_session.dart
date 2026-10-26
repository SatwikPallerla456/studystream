import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:drift/drift.dart' as d;
import 'package:media_kit/media_kit.dart';
import 'package:uuid/uuid.dart';
import '../db/app_database.dart';
import '../sync/lan_sync_client.dart';
import '../../domain/catalog/media_catalog_repository.dart';
import '../../domain/music/music_models.dart';
import '../../domain/music/music_repository.dart';
import '../../domain/services/player_library_repository.dart';
import '../../domain/services/progress_writer.dart';

class MusicTrack {
  MusicTrack(this.item, this.metadata, this.extras, this.media, this.ordinal);
  final Item item;
  final Map<String, dynamic> metadata, extras;
  final Media media;
  int ordinal;
  String get title =>
      item.userTitle ?? metadata['title'] as String? ?? item.title;
  String get artist => metadata['artist'] as String? ?? 'Unknown artist';
}

class _Deck {
  _Deck(this.player, this.slots);
  final Player player;
  final List<MusicTrack> slots;
  StreamSubscription<Playlist>? subscription;
  StreamSubscription<String>? errors;
}

class _Listening {
  _Listening(this.track, this.writer);
  final MusicTrack track;
  final MediaProgressWriter writer;
  final id = const Uuid().v4();
  final started = DateTime.now().millisecondsSinceEpoch;
  double seconds = 0;
  Duration position = Duration.zero, duration = Duration.zero;
}

/// Owns a bounded native playlist (four entries) or two audio decks. File changes
/// stay on one native output in gapless mode; Flutter routes never time handoffs.
class MusicSession extends ChangeNotifier {
  MusicSession(this.db, this.client, this.queue);
  final AppDatabase db;
  final LanSyncClient client;
  final PlayerLibraryRepository queue;
  MusicRepository get repository => MusicRepository(db);
  _Deck? _deck, _nextDeck;
  _Listening? _listen, _nextListen;
  MusicTrack? get track => _listen?.track;
  Player? get player => _deck?.player;
  List<LyricLine> lyrics = [];
  List<CueTrack> cues = [];
  List<Map<String, dynamic>> chapters = [];
  AudioOutputProfile profile = const AudioOutputProfile(
    id: 'default',
    name: 'System default',
  );
  final List<String> _ids = [];
  int _ordinal = 0, _generation = 0;
  bool _notifierDisposed = false;
  void _notify() {
    if (!_notifierDisposed && !_closed) notifyListeners();
  }

  StreamSubscription<dynamic>? _queueSubscription;
  String? _queueSignature;
  bool _closed = false,
      _tickBusy = false,
      _transition = false,
      _meterBusy = false,
      _trimming = false;
  bool gapless = true, repeatOne = false, repeatAll = false;
  bool shuffled = false;
  bool get queued => _entryIds != null;
  double crossfade = 0, volume = 70, visualIntensity = .55;
  String visualStyle = 'auto';
  double energy = 0, beat = 0, grit = 0;
  final List<double> envelope = [];
  String? error, meterMessage;
  Timer? _timer;
  final _clock = Stopwatch()..start();
  int _lastTick = 0, _lastPersist = 0, _lastBeat = 0;
  double _average = .12;
  Future<void> _pending = Future.value();
  Future<void>? _disposal;
  Duration _fadeElapsed = Duration.zero;
  List<String>? _entryIds;
  Map<String, dynamic>? _radioConfig;
  Future<void> _ordered(Future<void> Function() action) {
    final result = _pending.catchError((Object _) {}).then((_) async {
      if (!_closed) await action();
    });
    _pending = result;
    return result.catchError((Object e) {
      if (!_closed) {
        error = e.toString();
        _notify();
      }
      throw e;
    });
  }

  Future<void> initialize(
    String initialId, {
    bool fromQueue = false,
    bool radio = false,
  }) => _ordered(() async {
    MediaKit.ensureInitialized();
    final preferences =
        jsonDecode(await db.getSetting('music.preferences') ?? '{}') as Map;
    gapless = preferences['gapless'] != false;
    crossfade = (preferences['crossfade'] as num? ?? 0).toDouble().clamp(0, 12);
    visualIntensity = (preferences['visualIntensity'] as num? ?? .55)
        .toDouble()
        .clamp(0, 1);
    visualStyle =
        {'auto', 'calm', 'punchy', 'off'}.contains(preferences['visualStyle'])
        ? preferences['visualStyle'] as String
        : 'auto';
    if (radio) {
      final raw = await db.getSetting('music.radio.config');
      if (raw != null)
        _radioConfig = Map<String, dynamic>.from(jsonDecode(raw) as Map);
    }
    final savedProfile = await db.getSetting('music.activeOutput');
    final raw = savedProfile == null
        ? null
        : await db.getSetting('music.output:$savedProfile');
    if (raw != null)
      profile = AudioOutputProfile.fromJson(jsonDecode(raw) as Map);
    volume = profile.volume;
    if (fromQueue) {
      final state = await queue.load();
      _queueSignature = jsonEncode([
        state.playOrder,
        state.repeat.name,
        state.shuffle,
      ]);
      final entries = {for (final entry in state.queue) entry.id: entry};
      for (final id in state.playOrder) {
        final entry = entries[id];
        if (entry != null) {
          _ids.add(entry.itemId);
        }
      }
      _entryIds = [
        for (final id in state.playOrder)
          if (entries.containsKey(id)) id,
      ];
      final selected = state.current?.itemId == initialId
          ? state.playOrder.indexOf(state.currentEntryId!)
          : _ids.indexOf(initialId);
      _ordinal = math.max(0, selected);
      shuffled = state.shuffle;
      repeatOne = state.repeat == QueueRepeat.one;
      repeatAll = state.repeat == QueueRepeat.all;
    }
    if (_ids.isEmpty) {
      _ids.add(initialId);
      _ordinal = 0;
    }
    if (_ids[_ordinal] != initialId)
      throw const FormatException('The music queue changed. Reopen it.');
    final item = await db.getItemById(initialId);
    if (item == null || item.itemType != 'audio')
      throw const FormatException('Select an audio recording');
    final saved = await db.getPlaybackByItemId(initialId);
    await _open(
      _ordinal,
      position: saved?.completed == true
          ? Duration.zero
          : Duration(
              milliseconds: ((saved?.resumePositionSeconds ?? 0) * 1000)
                  .round(),
            ),
    );
    if (fromQueue) {
      final key = queue.queueNamespace == null
          ? PlayerLibraryRepository.settingKey
          : 'player.window.queue:${queue.queueNamespace}';
      _queueSubscription =
          (db.select(db.appSettings)..where((t) => t.key.equals(key)))
              .watch()
              .listen((_) => unawaited(refreshQueue().catchError(_report)));
    }
    _timer = Timer.periodic(const Duration(milliseconds: 40), (_) {
      unawaited(_tick().catchError(_report));
    });
  });
  void _report(Object e) {
    if (!_closed) {
      error = e.toString();
      _notify();
    }
  }

  Future<MusicTrack> _resolve(int ordinal) async {
    final item = await db.getItemById(_ids[ordinal]);
    if (item == null || item.unavailable || item.itemType != 'audio')
      throw const FormatException(
        'A queued recording is missing. Remove it or select another track.',
      );
    final source = await client.sourceFor(item);
    return MusicTrack(
      item,
      await MediaCatalogRepository(db).metadata(item),
      await repository.extras(item),
      Media(source.uri.toString(), httpHeaders: source.headers),
      ordinal,
    );
  }

  Future<_Deck> _make(List<MusicTrack> tracks) async {
    final p = Player();
    final deck = _Deck(p, tracks);
    deck.errors = p.stream.error.listen(_report);
    try {
      await _configure(p);
      await p.setVolume(0);
      await p.open(Playlist(tracks.map((t) => t.media).toList()), play: false);
      return deck;
    } catch (_) {
      await p.dispose();
      rethrow;
    }
  }

  Future<void> _property(Player p, String key, String value) async {
    final native = p.platform;
    if (native is! NativePlayer)
      throw const FormatException(
        'The continuous music backend is unavailable on this platform',
      );
    // The wrapper logs command errors rather than throwing. Read back critical
    // options so an unsupported capability cannot silently look enabled.
    await native.command(['set', key, value]);
    final actual = await native.getProperty(key);
    if (key == 'af') {
      if (value.isNotEmpty &&
          (!actual.contains('tangerine-energy') ||
              value.contains('tangerine-normalize') &&
                  !actual.contains('tangerine-normalize')))
        throw const FormatException(
          'The requested audio filter is unavailable',
        );
    } else if (key != 'vid' && key != 'audio-samplerate' && actual != value) {
      if (num.tryParse(actual) != num.tryParse(value) ||
          num.tryParse(value) == null)
        throw FormatException('The audio backend rejected $key');
    } else if (key == 'audio-samplerate' &&
        int.tryParse(actual) != int.tryParse(value))
      throw const FormatException(
        'The requested output sample rate is unavailable',
      );
  }

  Future<void> _configure(Player p) async {
    await _property(p, 'vid', 'no');
    await _property(
      p,
      'gapless-audio',
      gapless && crossfade == 0 ? 'yes' : 'no',
    );
    await _property(p, 'audio-samplerate', '${profile.sampleRate}');
    await _property(
      p,
      'replaygain',
      profile.normalization == 'album'
          ? 'album'
          : profile.normalization == 'track'
          ? 'track'
          : 'no',
    );
    await _property(p, 'replaygain-preamp', '${profile.preamp}');
    await _property(p, 'replaygain-clip', 'no');
    final filters = <String>[
      '@tangerine-energy:lavfi=[astats=metadata=1:reset=1]',
    ];
    if (profile.normalization == 'dynamic')
      filters.add('@tangerine-normalize:lavfi=[loudnorm=I=-16:TP=-1.5:LRA=11]');
    try {
      await _property(p, 'af', filters.join(','));
    } catch (e) {
      meterMessage =
          'Audio analysis is unavailable in this backend. Ambient artwork stays still.';
      if (profile.normalization == 'dynamic') rethrow;
      await _property(p, 'af', '');
    }
    if (profile.device == 'auto') {
      await p.setAudioDevice(AudioDevice.auto());
    } else {
      final devices = p.state.audioDevices;
      final device = devices.where((d) => d.name == profile.device).firstOrNull;
      if (device == null)
        throw const FormatException(
          'This output device is disconnected. Choose System default or reconnect it.',
        );
      await p.setAudioDevice(device);
      final actual = await (p.platform as NativePlayer).getProperty(
        'audio-device',
      );
      if (actual != profile.device)
        throw const FormatException('The audio output could not be selected');
    }
  }

  void _bind(_Deck deck) {
    deck.subscription = deck.player.stream.playlist.listen((list) {
      if (_closed ||
          !identical(_deck, deck) ||
          _transition ||
          _trimming ||
          list.index < 0 ||
          list.index >= deck.slots.length ||
          list.medias.length != deck.slots.length)
        return;
      final target = deck.slots[list.index];
      if (target.ordinal != _ordinal)
        unawaited(
          _ordered(() async {
            if (!identical(_deck, deck) || target.ordinal == _ordinal) return;
            await _finish(completed: true);
            await _adopt(target);
            await _prepare();
          }).catchError(_report),
        );
    });
  }

  Future<void> _adopt(MusicTrack next, {_Listening? retained}) async {
    _ordinal = next.ordinal;
    _listen =
        retained ??
        _Listening(
          next,
          MediaProgressWriter(
            database: db,
            item: next.item,
            onError: _report,
            resumeRewindSeconds: 0,
          ),
        );
    lyrics = LyricLine.parse(next.extras['lrc'] as String? ?? '');
    cues = next.extras['cue'] is String
        ? CueTrack.decode(next.extras['cue'] as String)
        : [];
    chapters = [];
    final entries = _entryIds;
    if (entries != null && _ordinal < entries.length)
      await queue.select(entries[_ordinal]);
    _lastTick = _clock.elapsedMilliseconds;
    _lastPersist = _lastTick;
    _notify();
    unawaited(_loadChapters(next).catchError(_report));
  }

  Future<void> _loadChapters(MusicTrack expected) async {
    final p = player, native = player?.platform;
    if (native is! NativePlayer) return;
    final count =
        int.tryParse(await native.getProperty('chapter-list/count')) ?? 0;
    final rows = <Map<String, dynamic>>[];
    for (var i = 0; i < count.clamp(0, 500); i++) {
      final title = await native.getProperty('chapter-list/$i/title'),
          time = double.tryParse(
            await native.getProperty('chapter-list/$i/time'),
          );
      if (time != null && time.isFinite && time >= 0)
        rows.add({
          'title': title.isEmpty ? 'Chapter ${i + 1}' : title,
          'seconds': time,
        });
    }
    if (identical(track, expected) && identical(player, p) && !_closed) {
      chapters = rows;
      _notify();
    }
  }

  int? _nextOrdinal() {
    if (repeatOne) return _ordinal;
    final next = _ordinal + 1;
    return next < _ids.length
        ? next
        : repeatAll
        ? 0
        : null;
  }

  Future<void> _prepare() async {
    if (_closed || _deck == null) return;
    if (crossfade == 0)
      await _deck!.player.setPlaylistMode(
        repeatOne ? PlaylistMode.single : PlaylistMode.none,
      );
    var next = _nextOrdinal();
    if (next == null && _radioConfig != null && _ids.length < 10000) {
      final config = _radioConfig!;
      final more = await repository.radio(
        MusicRules.fromJson(config['rules'] as Map),
        count: 20,
        variety: config['variety'] != false,
        avoidHours: config['avoidHours'] as int? ?? 24,
        exclude: _ids.skip(math.max(0, _ids.length - 100)).toSet(),
      );
      for (final item in more.take(10000 - _ids.length)) {
        await queue.enqueue(item.id);
        _ids.add(item.id);
      }
      if (more.isNotEmpty) {
        final state = await queue.load();
        _entryIds = [for (final entry in state.queue) entry.id];
      }
      next = _nextOrdinal();
    }
    if (next == null) return;
    final active = _deck!;
    if (crossfade > 0) {
      if (_nextDeck != null) return;
      final track = await _resolve(next);
      _nextDeck = await _make([track]);
      await _nextDeck!.player.setVolume(0);
    } else {
      if (next == _ordinal) {
        await active.player.setPlaylistMode(PlaylistMode.single);
        return;
      }
      if (active.slots
          .skip(active.player.state.playlist.index + 1)
          .any((t) => t.ordinal == next))
        return;
      final future = await _resolve(next);
      if (active.slots.length >= 4) {
        _trimming = true;
        try {
          active.slots.removeAt(0);
          await active.player.remove(0);
        } finally {
          _trimming = false;
        }
      }
      active.slots.add(future);
      await active.player.add(future.media);
    }
  }

  Future<void> _open(int ordinal, {Duration position = Duration.zero}) async {
    _transition = true;
    final generation = ++_generation;
    try {
      await _cancelStandby();
      final previous = _deck;
      if (previous != null) {
        await previous.subscription?.cancel();
        await previous.errors?.cancel();
        await previous.player.dispose();
        _deck = null;
      }
      final next = await _resolve(ordinal), deck = await _make([next]);
      if (_closed || generation != _generation) {
        await deck.player.dispose();
        return;
      }
      _deck = deck;
      await deck.player.setVolume(volume);
      await _adopt(next);
      _bind(deck);
      if (position > Duration.zero) await deck.player.seek(position);
      try {
        await _prepare();
      } catch (e) {
        _report(e);
      }
      await deck.player.play();
    } finally {
      _transition = false;
    }
  }

  Future<void> _cancelStandby() async {
    final next = _nextDeck;
    if (_nextListen != null) {
      await _saveListen(_nextListen!, completed: false, skipped: true);
      _nextListen = null;
    }
    _nextDeck = null;
    _fadeElapsed = Duration.zero;
    if (next != null) {
      await next.errors?.cancel();
      await next.player.dispose();
    }
    await player?.setVolume(volume);
  }

  Future<void> _finish({required bool completed, bool skipped = false}) async {
    final listen = _listen;
    if (listen == null) return;
    _listen = null;
    await _saveListen(listen, completed: completed, skipped: skipped);
  }

  Future<void> _saveListen(
    _Listening listen, {
    required bool completed,
    bool skipped = false,
  }) async {
    listen.writer.seed(
      position: listen.position,
      duration: listen.duration,
      speed: 1,
    );
    try {
      await listen.writer.flush(forceComplete: completed);
    } catch (e) {
      _report(e);
    } finally {
      try {
        await listen.writer.dispose();
      } catch (e) {
        _report(e);
      }
    }
    try {
      await repository.checkpointListen(
        sessionId: listen.id,
        item: listen.track.item,
        title: listen.track.title,
        artist: listen.track.artist,
        listened: listen.seconds,
        completed: completed,
        startedAt: listen.started,
        skipped: skipped,
      );
    } catch (e) {
      _report(e);
    }
  }

  Future<void> _tick() async {
    if (_closed || _tickBusy || _transition || _deck == null) return;
    _tickBusy = true;
    try {
      final p = player!, listen = _listen;
      final now = _clock.elapsedMilliseconds,
          delta = ((now - _lastTick) / 1000).clamp(0.0, .25);
      _lastTick = now;
      if (repeatOne &&
          listen != null &&
          p.state.playing &&
          listen.duration > Duration.zero &&
          listen.position.inMilliseconds >
              listen.duration.inMilliseconds - 1500 &&
          p.state.position.inMilliseconds < 500 &&
          listen.position.inMilliseconds - p.state.position.inMilliseconds >
              1000) {
        await _ordered(() async {
          final current = track;
          if (current == null) return;
          await _finish(completed: true);
          await _adopt(current);
        });
        return;
      }
      if (listen != null) {
        if (p.state.playing && !p.state.buffering) listen.seconds += delta;
        // A native automatic transition can emit position before playlist.
        final current = p.state.playlist.index;
        if (current >= 0 &&
            current < _deck!.slots.length &&
            _deck!.slots[current].ordinal == _ordinal) {
          listen.position = p.state.position;
          listen.duration = p.state.duration;
        }
        listen.writer.schedule(
          position: listen.position,
          duration: listen.duration,
          speed: p.state.rate,
        );
        if (now - _lastPersist >= 10000) {
          _lastPersist = now;
          await repository.checkpointListen(
            sessionId: listen.id,
            item: listen.track.item,
            title: listen.track.title,
            artist: listen.track.artist,
            listened: listen.seconds,
            completed: p.state.completed,
            startedAt: listen.started,
            skipped: false,
          );
        }
      }
      final standby = _nextDeck;
      final remaining =
          (p.state.duration - p.state.position).inMilliseconds / 1000;
      if (p.state.completed && standby != null) {
        await _ordered(() => _promote(standby));
        return;
      }
      final fadeWindow = standby == null
          ? 0.0
          : math.min(
              crossfade,
              math.min(
                p.state.duration.inMilliseconds / 2000,
                standby.player.state.duration > Duration.zero
                    ? standby.player.state.duration.inMilliseconds / 2000
                    : crossfade,
              ),
            );
      if (crossfade > 0 &&
          standby != null &&
          p.state.playing &&
          !p.state.buffering &&
          p.state.duration > Duration.zero &&
          remaining <= fadeWindow &&
          remaining >= 0) {
        if (_nextListen == null) {
          _nextListen = _Listening(
            standby.slots.first,
            MediaProgressWriter(
              database: db,
              item: standby.slots.first.item,
              onError: _report,
              resumeRewindSeconds: 0,
            ),
          );
          await standby.player.play();
        }
        if (standby.player.state.buffering) return;
        if (standby.player.state.playing && _nextListen != null) {
          _nextListen!.seconds += delta;
          _nextListen!.position = standby.player.state.position;
          _nextListen!.duration = standby.player.state.duration;
          _nextListen!.writer.schedule(
            position: _nextListen!.position,
            duration: _nextListen!.duration,
            speed: standby.player.state.rate,
          );
        }
        _fadeElapsed += Duration(microseconds: (delta * 1000000).round());
        final length = fadeWindow;
        final t = (_fadeElapsed.inMicroseconds / 1000000 / math.max(.1, length))
            .clamp(0.0, 1.0);
        await p.setVolume(volume * math.cos(t * math.pi / 2));
        await standby.player.setVolume(volume * math.sin(t * math.pi / 2));
        if (t >= 1 || p.state.completed)
          await _ordered(() => _promote(standby));
      } else if (p.state.completed &&
          _nextOrdinal() == null &&
          _listen != null) {
        // Retain the last title's UI, but qualify completion once only.
        if (!(_listen!.track.extras['_finished'] == true)) {
          _listen!.track.extras['_finished'] = true;
          await _listen!.writer.flush(forceComplete: true);
          await repository.checkpointListen(
            sessionId: _listen!.id,
            item: _listen!.track.item,
            title: _listen!.track.title,
            artist: _listen!.track.artist,
            listened: _listen!.seconds,
            completed: true,
            startedAt: _listen!.started,
            skipped: false,
          );
        }
      }
      if (!_meterBusy) unawaited(_meter());
      if (!_closed) _notify();
    } finally {
      _tickBusy = false;
    }
  }

  Future<void> _promote(_Deck standby) async {
    if (!identical(_nextDeck, standby)) return;
    _transition = true;
    try {
      final old = _deck!;
      await standby.player.setVolume(volume);
      if (!standby.player.state.playing) await standby.player.play();
      await old.subscription?.cancel();
      await old.errors?.cancel();
      await _finish(completed: true);
      _deck = standby;
      _nextDeck = null;
      _fadeElapsed = Duration.zero;
      await old.player.dispose();
      final retained = _nextListen;
      _nextListen = null;
      await _adopt(standby.slots.first, retained: retained);
      _listen!.position = standby.player.state.position;
      _bind(standby);
      try {
        await _prepare();
      } catch (e) {
        _report(e);
      }
    } finally {
      _transition = false;
    }
  }

  Future<void> _meter() async {
    if (_closed || player == null) return;
    _meterBusy = true;
    try {
      final p = player!, native = p.platform;
      if (native is! NativePlayer) return;
      if (!p.state.playing ||
          p.state.buffering ||
          volume == 0 ||
          visualStyle == 'off') {
        energy *= .85;
        beat *= .8;
        return;
      }
      final values = await Future.wait(
        [
          'Overall.RMS_level',
          'Overall.Peak_level',
          '1.Zero_crossings_rate',
        ].map(
          (key) => native.getProperty(
            'af-metadata/tangerine-energy/lavfi.astats.$key',
          ),
        ),
      );
      final rms = double.tryParse(values[0]),
          peak = double.tryParse(values[1]),
          zcr = double.tryParse(values[2]) ?? 0;
      if (rms == null || peak == null || !rms.isFinite || !peak.isFinite) {
        energy *= .9;
        beat *= .85;
        meterMessage = 'Audio response is waiting for level data.';
        return;
      }
      final level = math.pow(10, rms / 35).toDouble().clamp(0.0, 1.0);
      final elapsed = _clock.elapsedMilliseconds;
      final onset =
          level > _average * 1.3 && level > .05 && elapsed - _lastBeat > 180;
      _average = _average * .94 + level * .06;
      if (onset) {
        beat = 1;
        _lastBeat = elapsed;
      } else {
        beat *= .82;
      }
      energy += (level - energy) * (level > energy ? .5 : .09);
      final rough = ((peak - rms < 9 ? .55 : .15) + zcr * 3 + energy * .35)
          .clamp(0.0, 1.0);
      grit += (rough - grit) * .04;
      envelope.add(level);
      if (envelope.length > 96) envelope.removeAt(0);
      meterMessage = null;
    } catch (_) {
      energy *= .9;
      beat *= .8;
      meterMessage = 'Audio response is unavailable; artwork remains ambient.';
    } finally {
      _meterBusy = false;
    }
  }

  Future<void> pause() => _ordered(() async {
    await player?.pause();
    if (_nextListen != null) await _nextDeck?.player.pause();
    await _listen?.writer.flush();
    _notify();
  });
  Future<void> play() => _ordered(() async {
    final current = track;
    if (current != null && current.extras['_finished'] == true) {
      await _finish(completed: true);
      current.extras.remove('_finished');
      await _adopt(current);
      _listen!.writer.markPositionIntent();
      await player?.seek(Duration.zero);
    }
    await player?.play();
    if (_nextListen != null) await _nextDeck?.player.play();
    _notify();
  });
  Future<void> seek(Duration value) => _ordered(() async {
    await _cancelStandby();
    final p = player;
    if (p == null) return;
    final bounded = value < Duration.zero
        ? Duration.zero
        : value > p.state.duration
        ? p.state.duration
        : value;
    _listen?.writer.markPositionIntent();
    await p.seek(bounded);
    _listen?.writer.seed(
      position: bounded,
      duration: p.state.duration,
      speed: p.state.rate,
    );
    await _listen?.writer.flush();
    await _prepare();
  });
  Future<void> refreshQueue() => _ordered(() async {
    if (_entryIds == null || track == null || _deck == null) return;
    final state = await queue.load(),
        signature = jsonEncode([
          state.playOrder,
          state.repeat.name,
          state.shuffle,
        ]);
    if (signature == _queueSignature) return;
    _queueSignature = signature;
    final currentEntry = _ordinal < _entryIds!.length
        ? _entryIds![_ordinal]
        : null;
    final entries = {for (final e in state.queue) e.id: e};
    final order = state.playOrder.where(entries.containsKey).toList();
    final index = currentEntry == null ? -1 : order.indexOf(currentEntry);
    await _cancelStandby();
    final deck = _deck!;
    _trimming = true;
    try {
      final at = deck.player.state.playlist.index;
      if (at < 0) return;
      while (deck.slots.length > at + 1) {
        final last = deck.slots.length - 1;
        deck.slots.removeLast();
        await deck.player.remove(last);
      }
      if (index < 0) {
        while (deck.slots.length > 1) {
          deck.slots.removeAt(0);
          await deck.player.remove(0);
        }
        _ids
          ..clear()
          ..add(track!.item.id);
        _entryIds = null;
        _ordinal = 0;
        track!.ordinal = 0;
        repeatOne = false;
        repeatAll = false;
      } else {
        _ids
          ..clear()
          ..addAll(order.map((id) => entries[id]!.itemId));
        _entryIds = order;
        _ordinal = index;
        track!.ordinal = index;
        shuffled = state.shuffle;
        repeatOne = state.repeat == QueueRepeat.one;
        repeatAll = state.repeat == QueueRepeat.all;
      }
    } finally {
      _trimming = false;
    }
    await _prepare();
    _notify();
  });
  Future<void> skip(int delta) => _ordered(() async {
    var next = _ordinal + delta;
    if (next >= _ids.length && _radioConfig != null) {
      await _prepare();
    }
    if (repeatAll && _ids.isNotEmpty) next = (next + _ids.length) % _ids.length;
    if (next < 0 || next >= _ids.length) return;
    await _finish(completed: false, skipped: true);
    await _open(next);
  });
  Future<void> setVolume(double value) async {
    volume = value.clamp(0, 100);
    if (_fadeElapsed == Duration.zero) await player?.setVolume(volume);
    _notify();
  }

  Future<void> setProfile(AudioOutputProfile next) => _ordered(() async {
    final previous = profile;
    profile = next;
    try {
      if (player != null) await _configure(player!);
      if (_nextDeck != null) await _configure(_nextDeck!.player);
      await setVolume(next.volume);
      await db.setSetting('music.activeOutput', next.id);
    } catch (_) {
      profile = previous;
      if (player != null) await _configure(player!);
      rethrow;
    }
  });
  Future<void> preferences({
    bool? seamless,
    double? fade,
    double? intensity,
    String? style,
  }) => _ordered(() async {
    final rebuild = fade != null || seamless != null;
    if (seamless != null) gapless = seamless;
    if (fade != null) crossfade = fade.clamp(0, 12);
    if (intensity != null) visualIntensity = intensity.clamp(0, 1);
    if (style != null && {'auto', 'calm', 'punchy', 'off'}.contains(style))
      visualStyle = style;
    await db.setSetting(
      'music.preferences',
      jsonEncode({
        'gapless': gapless,
        'crossfade': crossfade,
        'visualIntensity': visualIntensity,
        'visualStyle': visualStyle,
      }),
    );
    if (rebuild && player != null) {
      final position = player!.state.position;
      await _finish(completed: false);
      await _open(_ordinal, position: position);
    }
    _notify();
  });
  Future<void> refreshExtras() async {
    final current = track;
    if (current == null) return;
    final data = await repository.extras(current.item);
    current.extras
      ..clear()
      ..addAll(data);
    lyrics = LyricLine.parse(data['lrc'] as String? ?? '');
    cues = data['cue'] is String ? CueTrack.decode(data['cue'] as String) : [];
    _notify();
  }

  Future<void> checkpoint() => _ordered(() async {
    final listen = _listen, p = player;
    if (listen == null || p == null) return;
    listen.position = p.state.position;
    listen.duration = p.state.duration;
    listen.writer.seed(
      position: listen.position,
      duration: listen.duration,
      speed: p.state.rate,
    );
    await listen.writer.flush();
    await repository.checkpointListen(
      sessionId: listen.id,
      item: listen.track.item,
      title: listen.track.title,
      artist: listen.track.artist,
      listened: listen.seconds,
      completed: p.state.completed,
      startedAt: listen.started,
      skipped: false,
    );
  });
  Future<void> close() => _disposal ??= _ordered(() async {
    _timer?.cancel();
    await _queueSubscription?.cancel();
    _closed = true;
    ++_generation;
    await _deck?.subscription?.cancel();
    await _deck?.errors?.cancel();
    await _nextDeck?.errors?.cancel();
    try {
      await _finish(completed: player?.state.completed == true);
    } finally {
      if (_nextListen != null) {
        await _saveListen(_nextListen!, completed: false, skipped: false);
        _nextListen = null;
      }
      await _nextDeck?.player.dispose();
      await _deck?.player.dispose();
      _deck = null;
      _nextDeck = null;
    }
  });
  @override
  void dispose() {
    _notifierDisposed = true;
    unawaited(close().catchError((Object _) {}));
    super.dispose();
  }
}
