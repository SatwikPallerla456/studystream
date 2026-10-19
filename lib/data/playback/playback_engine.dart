import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import 'authenticated_media_relay.dart';

/// The native playback boundary. macOS uses the original MyVLC/libVLC engine;
/// other targets explicitly retain the interim media_kit implementation.
abstract class PlaybackEngine {
  static Future<PlaybackEngine> create({
    Map<String, String> nativePreferences = const {},
    Map<String, String> globalShortcuts = const {},
  }) async {
    if (Platform.isMacOS &&
        !const bool.fromEnvironment('TANGERINE_INTERIM_PLAYER')) {
      return NativeVlcEngine.create(
        initialPreferences: nativePreferences,
        globalShortcuts: globalShortcuts,
      );
    }
    return InterimMediaKitEngine();
  }

  PlayerState get state;
  PlaybackStreams get stream;
  String get backendName;
  Widget videoSurface();
  Future<void> open(Media media, {bool play = true});
  Future<void> play();
  Future<void> pause();
  Future<void> seek(Duration position);
  Future<void> setRate(double rate);
  Future<void> setVolume(double volume);
  Future<void> setAudioTrack(AudioTrack track);
  Future<void> setSubtitleTrack(SubtitleTrack track);
  Future<void> dispose();
  Future<void> playOrPause() => state.playing ? pause() : play();
}

class PlaybackStreams {
  const PlaybackStreams({
    required this.position,
    required this.duration,
    required this.playing,
    required this.completed,
    required this.buffering,
    required this.volume,
    required this.tracks,
    required this.track,
    required this.error,
  });
  final Stream<Duration> position;
  final Stream<Duration> duration;
  final Stream<bool> playing;
  final Stream<bool> completed;
  final Stream<bool> buffering;
  final Stream<double> volume;
  final Stream<Tracks> tracks;
  final Stream<Track> track;
  final Stream<String> error;
}

class InterimMediaKitEngine extends PlaybackEngine {
  final Player _player = Player();
  late final VideoController _video = VideoController(_player);
  @override
  String get backendName => 'media_kit (interim)';
  @override
  PlayerState get state => _player.state;
  @override
  late final stream = PlaybackStreams(
    position: _player.stream.position,
    duration: _player.stream.duration,
    playing: _player.stream.playing,
    completed: _player.stream.completed,
    buffering: _player.stream.buffering,
    volume: _player.stream.volume,
    tracks: _player.stream.tracks,
    track: _player.stream.track,
    error: _player.stream.error,
  );
  @override
  Widget videoSurface() =>
      Video(controller: _video, controls: AdaptiveVideoControls);
  @override
  Future<void> open(Media media, {bool play = true}) async {
    _video; // Attach the rendering controller before opening video.
    await _player.open(media, play: play);
  }

  @override
  Future<void> play() => _player.play();
  @override
  Future<void> pause() => _player.pause();
  @override
  Future<void> seek(Duration position) => _player.seek(position);
  @override
  Future<void> setRate(double rate) => _player.setRate(rate);
  @override
  Future<void> setVolume(double volume) => _player.setVolume(volume);
  @override
  Future<void> setAudioTrack(AudioTrack track) => _player.setAudioTrack(track);
  @override
  Future<void> setSubtitleTrack(SubtitleTrack track) =>
      _player.setSubtitleTrack(track);
  @override
  Future<void> dispose() => _player.dispose();
}

class NativeVlcEngine extends PlaybackEngine {
  NativeVlcEngine._(this.id, this._channel);
  final int id;
  final MethodChannel _channel;
  final _states = StreamController<PlayerState>.broadcast();
  final _errors = StreamController<String>.broadcast();
  final _actions = StreamController<String>.broadcast();
  Stream<String> get actions => _actions.stream;
  static final _instances = <int, NativeVlcEngine>{};
  PlayerState _state = const PlayerState();
  Timer? _timer;
  bool _disposed = false;
  bool _polling = false;
  AuthenticatedMediaRelay? _relay;
  Map<String, dynamic> diagnostics = const {};

  static Future<NativeVlcEngine> create({
    MethodChannel channel = const MethodChannel('tangerine/playback'),
    Map<String, String> initialPreferences = const {},
    Map<String, String> globalShortcuts = const {},
  }) async {
    channel.setMethodCallHandler((call) async {
      if (call.method == 'shortcut') {
        final args = call.arguments as Map;
        final engine = _instances[args['id']];
        if (engine != null && !engine._disposed) {
          engine._actions.add(args['action'] as String);
        }
      }
    });
    final id = await channel.invokeMethod<int>('create', {
      'preferences': initialPreferences,
      'globalShortcuts': globalShortcuts,
    });
    if (id == null) throw StateError('libVLC could not create a player.');
    final engine = NativeVlcEngine._(id, channel);
    _instances[id] = engine;
    return engine;
  }

  @override
  String get backendName => 'MyVLC · libVLC';
  @override
  PlayerState get state => _state;
  @override
  late final stream = PlaybackStreams(
    position: _states.stream.map((s) => s.position).distinct(),
    duration: _states.stream.map((s) => s.duration).distinct(),
    playing: _states.stream.map((s) => s.playing).distinct(),
    completed: _states.stream.map((s) => s.completed).distinct(),
    buffering: _states.stream.map((s) => s.buffering).distinct(),
    volume: _states.stream.map((s) => s.volume).distinct(),
    tracks: _states.stream.map((s) => s.tracks).distinct(),
    track: _states.stream.map((s) => s.track).distinct(),
    error: _errors.stream,
  );

  Future<T?> _call<T>(String method, [Map<String, Object?> args = const {}]) {
    if (_disposed) throw StateError('The native player has closed.');
    return _channel.invokeMethod<T>(method, {'id': id, ...args});
  }

  Future<void> refresh() async {
    if (_disposed || _polling) return;
    _polling = true;
    try {
      final values = await _call<Map>('state');
      if (values == null || _disposed) return;
      diagnostics = Map<String, dynamic>.from(values);
      List<Map> rows(String key) =>
          (values[key] as List? ?? const []).cast<Map>();
      final next = PlayerState(
        position: Duration(milliseconds: (values['position'] as num).toInt()),
        duration: Duration(milliseconds: (values['duration'] as num).toInt()),
        playing: values['playing'] == true,
        completed: values['completed'] == true,
        buffering: values['buffering'] == true,
        volume: (values['volume'] as num).toDouble(),
        rate: (values['rate'] as num).toDouble(),
        width: (values['width'] as num?)?.toInt(),
        height: (values['height'] as num?)?.toInt(),
        tracks: Tracks(
          audio: rows('audio')
              .map((r) => AudioTrack('${r['id']}', r['title'] as String?, null))
              .toList(),
          subtitle: rows('subtitles')
              .map(
                (r) => SubtitleTrack('${r['id']}', r['title'] as String?, null),
              )
              .toList(),
        ),
        track: Track(
          audio: AudioTrack('${values['audioTrack']}', null, null),
          subtitle: SubtitleTrack('${values['subtitleTrack']}', null, null),
        ),
      );
      _state = next;
      _states.add(next);
      if (values['error'] == true) {
        _errors.add('libVLC could not play this media.');
      }
    } finally {
      _polling = false;
    }
  }

  @override
  Future<void> open(Media media, {bool play = true}) async {
    _timer?.cancel();
    final initialVolume = state.volume;
    _state = const PlayerState();
    diagnostics = const {};
    await _relay?.close();
    final parsed = Uri.parse(media.uri);
    final source = parsed.hasScheme ? parsed : Uri.file(media.uri);
    var uri = source;
    if (media.httpHeaders?.isNotEmpty == true) {
      _relay = await AuthenticatedMediaRelay.start(source, media.httpHeaders!);
      uri = _relay!.uri;
    }
    // Parsing starts libVLC briefly; keep a paused load silent.
    if (!play) await _call<void>('volume', {'value': 0});
    await _call<void>('open', {'uri': uri.toString()});
    // libVLC must parse/start the input before duration, seeking and pause work.
    final deadline = DateTime.now().add(const Duration(seconds: 15));
    while (DateTime.now().isBefore(deadline)) {
      await refresh();
      if (diagnostics['error'] == true) {
        throw StateError('libVLC could not open this media.');
      }
      if (state.duration > Duration.zero || state.playing) break;
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    if (state.duration == Duration.zero && !state.playing) {
      throw TimeoutException('libVLC could not start this media.');
    }
    if (!play) {
      await pause();
      await setVolume(initialVolume);
    }
    _timer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      unawaited(
        refresh().catchError((Object error) {
          if (!_disposed) {
            _errors.add('The native player could not update playback.');
          }
        }),
      );
    });
  }

  @override
  Widget videoSurface() => AppKitView(
    viewType: 'tangerine/vlc-video',
    creationParams: {'id': id},
    creationParamsCodec: const StandardMessageCodec(),
  );
  @override
  Future<void> play() async {
    await _call<void>('play');
    await refresh();
  }

  @override
  Future<void> pause() async {
    await _call<void>('pause');
    await refresh();
  }

  @override
  Future<void> seek(Duration position) async {
    final max = state.duration > Duration.zero
        ? state.duration.inMilliseconds
        : 0x7FFFFFFFFFFFFFFF;
    await _call<void>('seek', {'value': position.inMilliseconds.clamp(0, max)});
    await refresh();
  }

  @override
  Future<void> setRate(double rate) async {
    if (!rate.isFinite || rate < .25 || rate > 4) {
      throw ArgumentError.value(rate, 'rate');
    }
    await _call<void>('rate', {'value': rate});
    await refresh();
  }

  @override
  Future<void> setVolume(double volume) async {
    await _call<void>('volume', {'value': volume.clamp(0, 100).round()});
    await refresh();
  }

  @override
  Future<void> setAudioTrack(AudioTrack track) async {
    await _call<void>('audioTrack', {'value': int.parse(track.id)});
    await refresh();
  }

  @override
  Future<void> setSubtitleTrack(SubtitleTrack track) async {
    if (track.uri) {
      final uri = Uri.parse(track.id);
      await _call<void>('subtitle', {
        'value': uri.scheme == 'file' ? uri.toFilePath() : track.id,
      });
    } else {
      await _call<void>('subtitleTrack', {
        'value': track.id == 'no' ? -1 : int.parse(track.id),
      });
    }
    await refresh();
  }

  Future<void> toggleMini() async {
    await _call<void>('mini');
    await refresh();
  }

  Future<void> toggleFullscreen() async {
    await _call<void>('fullscreen');
  }

  Future<String?> snapshot() => _call<String>('snapshot');
  Future<String?> startOutput({
    required String mode,
    String format = 'mp4',
    String? destination,
    String host = '127.0.0.1',
    int port = 8090,
    bool audio = true,
    bool video = true,
    bool subtitles = false,
  }) => _call<String>('output.start', {
    'mode': mode,
    'format': format,
    'destination': ?destination,
    'host': host,
    'port': port,
    'audio': audio,
    'video': video,
    'subtitles': subtitles,
  });
  Future<void> finishOutput(String id, {bool cancel = false}) async {
    await _call<void>('output.finish', {'jobId': id, 'cancel': cancel});
    await refresh();
  }

  Future<void> scanCast() async {
    await _call<void>('cast.scan');
    await refresh();
  }

  Future<void> stopCastScan() async {
    await _call<void>('cast.stop');
    await refresh();
  }

  Future<void> selectCast(String? id) async {
    await _call<void>('cast.select', {'deviceId': id});
    await refresh();
  }

  Future<void> nextFrame() async {
    await pause();
    await _call<void>('frame');
    await refresh();
  }

  Future<void> setChapter(int chapter) async {
    await _call<void>('chapter', {'value': chapter});
    await refresh();
  }

  Future<void> setEqualizer({
    required bool enabled,
    required double preamp,
    required List<double> bands,
  }) async {
    await _call<void>('equalizer', {
      'enabled': enabled,
      'preamp': preamp.clamp(-20, 20),
      'bands': bands.map((v) => v.clamp(-20, 20)).toList(),
    });
  }

  Future<void> setPicture(Map<String, Object?> values) async {
    await _call<void>('picture', values);
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _timer?.cancel();
    try {
      await _call<void>('dispose');
    } finally {
      _disposed = true;
      _instances.remove(id);
      await _actions.close();
      await _relay?.close();
      await _states.close();
      await _errors.close();
    }
  }
}
