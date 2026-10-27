import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import 'authenticated_media_relay.dart';

/// The native playback boundary. macOS uses the original MyVLC/libVLC engine;
/// Android/iOS/Windows/Linux use the local VideoLAN plugin. The interim engine
/// is available only with an explicit development flag.
abstract class PlaybackEngine {
  static Future<PlaybackEngine> create({
    Map<String, String> nativePreferences = const {},
    Map<String, String> globalShortcuts = const {},
    Future<int> Function()? nextSnapshotSequence,
  }) async {
    if (!const bool.fromEnvironment('TANGERINE_INTERIM_PLAYER')) {
      return NativeVlcEngine.create(
        initialPreferences: nativePreferences,
        globalShortcuts: globalShortcuts,
        nextSnapshotSequence: nextSnapshotSequence,
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
  Stream<bool> get fullscreenChanges =>
      _states.stream.map((_) => diagnostics['fullscreen'] == true).distinct();
  static final _instances = <int, NativeVlcEngine>{};
  PlayerState _state = const PlayerState();
  Timer? _timer;
  bool _disposed = false;
  bool _polling = false;
  AuthenticatedMediaRelay? _relay;
  Map<String, dynamic> diagnostics = const {};
  int? _textureId;
  Set<String> _capabilities = {};
  double? _aspectRatio, _cropRatio;
  double _zoom = 0;
  bool _mobileFullscreen = false;
  Map<String, String> _preferences = {};
  Future<int> Function()? _nextSnapshotSequence;
  bool supports(String feature) => _capabilities.contains(feature);
  Set<String> get capabilities => Set.unmodifiable(_capabilities);
  static Set<String> _features(Object? raw) {
    final value = raw is String ? jsonDecode(raw) : raw;
    return value is List ? value.whereType<String>().toSet() : {};
  }

  static Future<NativeVlcEngine> create({
    MethodChannel channel = const MethodChannel('tangerine/playback'),
    Map<String, String> initialPreferences = const {},
    Map<String, String> globalShortcuts = const {},
    Future<int> Function()? nextSnapshotSequence,
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
    final options = Map<String, String>.from(initialPreferences);
    for (final key in ['fileCache', 'networkCache']) {
      final n = double.tryParse(options[key] ?? '');
      if (n != null && n.isFinite)
        options[key] =
            '${n.round().clamp(0, key == 'fileCache' ? 10000 : 20000)}';
    }
    final created = await channel.invokeMethod<dynamic>('create', {
      'preferences': options,
      'globalShortcuts': globalShortcuts,
    });
    final id = created is num
        ? created.toInt()
        : (created as Map?)?['id'] as int?;
    if (id == null) throw StateError('libVLC could not create a player.');
    final engine = NativeVlcEngine._(id, channel);
    engine._preferences = Map.unmodifiable(initialPreferences);
    engine._nextSnapshotSequence = nextSnapshotSequence;
    if (created is Map) {
      engine._textureId = (created['textureId'] as num?)?.toInt();
      engine._capabilities = _features(created['capabilities']);
    } else if (Platform.isMacOS) {
      engine._capabilities = {
        'transport',
        'tracks',
        'chapters',
        'frame',
        'equalizer',
        'aspect',
        'crop',
        'zoom',
        'deinterlace',
        'brightness',
        'contrast',
        'saturation',
        'gamma',
        'hue',
        'audioDelay',
        'subtitleDelay',
        'devices',
        'diagnostics',
        'mini',
        'fullscreen',
        'snapshot',
        'outputs',
        'clipExport',
        'cast',
        'windowPreferences',
        'escape',
      };
    }
    if (Platform.isAndroid || Platform.isIOS)
      engine._capabilities.addAll({'fullscreen', 'escape'});
    if (engine._textureId != null) engine._capabilities.add('crop');
    _instances[id] = engine;
    return engine;
  }

  @override
  String get backendName =>
      Platform.isMacOS ? 'MyVLC · libVLC' : 'VideoLAN libVLC';
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
      final raw = await _call<dynamic>('state');
      if (raw == null || _disposed) return;
      final values = raw is String ? jsonDecode(raw) as Map : raw as Map;
      if (values['capabilities'] != null)
        _capabilities = _features(values['capabilities']);
      if (Platform.isAndroid || Platform.isIOS)
        _capabilities.addAll({'fullscreen', 'escape'});
      if (_textureId != null) _capabilities.add('crop');
      diagnostics = Map<String, dynamic>.from(values);
      if (Platform.isAndroid || Platform.isIOS)
        diagnostics['fullscreen'] = _mobileFullscreen;
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

  Future<void> openInput(String kind, {String? path}) async {
    if (!Platform.isMacOS)
      throw UnsupportedError(
        'Capture and disc inputs currently require macOS.',
      );
    _timer?.cancel();
    await _call<void>('input.open', {'kind': kind, 'path': path});
    _state = const PlayerState();
    diagnostics = const {};
    final deadline = DateTime.now().add(const Duration(seconds: 15));
    while (DateTime.now().isBefore(deadline)) {
      await refresh();
      if (diagnostics['error'] == true)
        throw StateError('The capture or disc input could not open.');
      if (state.playing || state.duration > Duration.zero) break;
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    if (!state.playing && state.duration == Duration.zero)
      throw TimeoutException(
        'The input did not become ready. Check the disc/device or capture permission.',
      );
    _timer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      unawaited(
        refresh().catchError((Object _) {
          if (!_disposed) _errors.add('The live input could not update.');
        }),
      );
    });
    await refresh();
  }

  Future<void> discNavigate(String action) =>
      _call<void>('disc.navigate', {'action': action});
  Future<void> discTitle(int title) =>
      _call<void>('disc.title', {'value': title});
  Future<void> runAddon(String source, {String? title}) async {
    if (!Platform.isMacOS)
      throw UnsupportedError(
        'MyVLC JavaScript add-ons currently require macOS.',
      );
    await _call<void>('addon.run', {
      'source': source,
      'title': title,
    }).timeout(const Duration(seconds: 5));
  }

  @override
  Widget videoSurface() {
    if (_textureId case final int texture) {
      return StreamBuilder<PlayerState>(
        stream: _states.stream,
        initialData: _state,
        builder: (context, snapshot) {
          final state = snapshot.data ?? _state;
          final width = state.width ?? 0, height = state.height ?? 0;
          final ratio =
              _aspectRatio ??
              (width > 0 && height > 0 ? width / height : 16 / 9);
          final crop = _cropRatio ?? ratio;
          return LayoutBuilder(
            builder: (context, constraints) {
              final width = math.min(
                constraints.maxWidth,
                constraints.maxHeight * crop,
              );
              final height = width / crop;
              return Center(
                child: SizedBox(
                  width: width,
                  height: height,
                  child: ClipRect(
                    child: Transform.scale(
                      scale: _zoom > 0 ? _zoom : 1,
                      child: FittedBox(
                        fit: BoxFit.cover,
                        child: SizedBox(
                          width: 1000 * ratio,
                          height: 1000,
                          child: Texture(textureId: texture),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      );
    }
    if (Platform.isIOS)
      return UiKitView(
        viewType: 'tangerine/vlc-video',
        creationParams: {'id': id},
        creationParamsCodec: const StandardMessageCodec(),
      );
    return AppKitView(
      viewType: 'tangerine/vlc-video',
      creationParams: {'id': id},
      creationParamsCodec: const StandardMessageCodec(),
    );
  }

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
    if (Platform.isIOS || Platform.isAndroid) {
      _mobileFullscreen = !_mobileFullscreen;
      await SystemChrome.setEnabledSystemUIMode(
        _mobileFullscreen
            ? SystemUiMode.immersiveSticky
            : SystemUiMode.edgeToEdge,
      );
    } else {
      await _call<void>('fullscreen');
    }
    await refresh();
  }

  Future<void> exitPresentation() async {
    if (Platform.isIOS || Platform.isAndroid) {
      _mobileFullscreen = false;
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    } else {
      await _call<void>('escape');
    }
    await refresh();
  }

  Future<void> toggleRecording() async {
    await _call<void>('record.toggle');
    await refresh();
  }

  Future<String?> snapshot() async {
    if (!supports('snapshot')) throw UnsupportedError('Snapshot');
    final format = _preferences['snapshotFormat'] == 'jpg' ? 'jpg' : 'png';
    var prefix = _preferences['snapshotPrefix'] ?? 'Tangerine-';
    if (prefix.length > 80 || prefix.contains(RegExp(r'[\\/:*?"<>|]')))
      prefix = 'Tangerine-';
    final stamp =
        _preferences['snapshotSequential'] != 'false' &&
            _nextSnapshotSequence != null
        ? '${await _nextSnapshotSequence!()}'.padLeft(6, '0')
        : DateTime.now().millisecondsSinceEpoch.toString();
    final filename = '$prefix$stamp.$format';
    final width = (int.tryParse(_preferences['snapshotWidth'] ?? '0') ?? 0)
        .clamp(0, 1920);
    var directory = _preferences['snapshotFolder'] ?? '';
    if (Platform.isMacOS)
      return _call<String>('snapshot', {
        'format': format,
        'filename': filename,
        'directory': directory,
        'width': width,
      });
    if (directory.isNotEmpty && !await Directory(directory).exists())
      directory = '';
    var destination = await FilePicker.platform.saveFile(
      dialogTitle: 'Save video snapshot',
      fileName: filename,
      initialDirectory: directory.isEmpty ? null : directory,
      type: FileType.custom,
      allowedExtensions: [format],
    );
    if (destination == null) return null;
    if (!destination.toLowerCase().endsWith('.$format'))
      destination = '$destination.$format';
    await _call<void>('snapshot', {'destination': destination, 'width': width});
    return destination;
  }

  Future<String?> exportClip(Duration start, Duration end) async {
    if (!supports('clipExport'))
      throw UnsupportedError(
        'Video-range export is unavailable in this backend.',
      );
    if (start < Duration.zero || end <= start || end > state.duration) {
      throw const FormatException(
        'Choose a clip range inside this video timeline.',
      );
    }
    return startOutput(mode: 'convert', start: start, end: end);
  }

  Future<String?> startOutput({
    required String mode,
    String format = 'mp4',
    String? destination,
    String host = '127.0.0.1',
    int port = 8090,
    bool audio = true,
    bool video = true,
    bool subtitles = false,
    Duration? start,
    Duration? end,
  }) => _call<String>('output.start', {
    'mode': mode,
    'format': format,
    'destination': ?destination,
    'host': host,
    'port': port,
    'audio': audio,
    'video': video,
    'subtitles': subtitles,
    if (start != null) 'startMs': start.inMilliseconds,
    if (end != null) 'endMs': end.inMilliseconds,
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
    final count = (diagnostics['chapters'] as num?)?.toInt() ?? 0;
    if (count <= 0) return;
    await _call<void>('chapter', {'value': chapter.clamp(0, count - 1)});
    await refresh();
  }

  Future<void> setEqualizer({
    required bool enabled,
    required double preamp,
    required List<double> bands,
  }) async {
    if (!supports('equalizer')) return;
    await _call<void>('equalizer', {
      'enabled': enabled,
      'preamp': preamp.clamp(-20, 20),
      'bands': bands.map((v) => v.clamp(-20, 20)).toList(),
    });
  }

  Future<void> setPicture(Map<String, Object?> values) async {
    final safe = <String, Object?>{
      for (final entry in values.entries)
        if (supports(
          entry.key == 'deinterlaceMode' ? 'deinterlace' : entry.key,
        ))
          entry.key: entry.value,
    };
    double? ratio(Object? raw) {
      if (raw == '') return null;
      if (raw is! String) throw const FormatException('Invalid framing ratio');
      final fields = raw.split(':');
      if (fields.length != 2)
        throw const FormatException('Invalid framing ratio');
      final w = double.tryParse(fields.first), h = double.tryParse(fields.last);
      if (w == null ||
          h == null ||
          !w.isFinite ||
          !h.isFinite ||
          w <= 0 ||
          h <= 0 ||
          w > 1000 ||
          h > 1000)
        throw const FormatException('Invalid framing ratio');
      return w / h;
    }

    final aspect = safe.containsKey('aspect')
        ? ratio(safe['aspect'])
        : _aspectRatio;
    final crop = safe.containsKey('crop') ? ratio(safe['crop']) : _cropRatio;
    final zoom = (safe['zoom'] as num?)?.toDouble() ?? _zoom;
    if (!zoom.isFinite || zoom < 0 || zoom > 5)
      throw const FormatException('Invalid video scale');
    // Texture outputs use Flutter geometry. Native scale/crop belongs to an OS
    // drawable; applying it as well would double-transform the decoded frames.
    final native = {
      for (final entry in safe.entries)
        if (_textureId == null ||
            !{'aspect', 'crop', 'zoom'}.contains(entry.key))
          entry.key: entry.value,
    };
    if (native.isNotEmpty) await _call<void>('picture', native);
    _aspectRatio = aspect;
    _cropRatio = crop;
    _zoom = zoom;
    if (!_disposed) _states.add(_state);
  }

  Future<void> setOutputDevice(String value) async {
    if (!supports('devices'))
      throw UnsupportedError('Output routing is managed by this platform.');
    await _call<void>('device', {'value': value});
    await refresh();
  }

  Future<void> prepareExit() async {
    if (Platform.isMacOS) await _call<void>('prepareExit');
  }

  Future<void> finishWindow(String action) async {
    await _call<void>('window.finish', {'action': action});
  }

  Future<void> closeWindow() async {
    await _call<void>('window.close');
  }

  Future<void> windowPreferences(Map<String, String> values) async {
    if (supports('windowPreferences'))
      await _call<void>('window.preferences', {'values': values});
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _timer?.cancel();
    if (_mobileFullscreen)
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
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
