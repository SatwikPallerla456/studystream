import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:media_kit/media_kit.dart';

/// Measurements from decoded samples, independent of output volume/visual style.
class AudioLevel {
  const AudioLevel(this.rmsDb, this.peakDb, this.zeroCrossingRate);
  final double rmsDb, peakDb, zeroCrossingRate;

  static List<AudioLevel> decodePcm(Uint8List pcm) {
    final bytes = ByteData.sublistView(pcm);
    final result = <AudioLevel>[];
    const samplesPerFrame = PcmAudioAnalyzer.sampleRate ~/ 25;
    for (var start = 0; start + 1 < pcm.length; start += samplesPerFrame * 2) {
      final end = math.min(start + samplesPerFrame * 2, pcm.length & ~1);
      var squares = 0.0, peak = 0.0;
      var crossings = 0, previous = 0.0;
      for (var offset = start; offset < end; offset += 2) {
        final value = bytes.getInt16(offset, Endian.little) / 32768;
        squares += value * value;
        peak = math.max(peak, value.abs());
        if (offset > start && (value >= 0) != (previous >= 0)) crossings++;
        previous = value;
      }
      final count = (end - start) ~/ 2;
      double db(double linear) =>
          20 * math.log(math.max(1e-6, linear)) / math.ln10;
      result.add(
        AudioLevel(
          db(math.sqrt(squares / count)),
          db(peak),
          count < 2 ? 0 : crossings / (count - 1),
        ),
      );
    }
    return result;
  }
}

class _AudioWindow {
  _AudioWindow(this.start, this.levels);
  final Duration start;
  final List<AudioLevel> levels;
  Duration get end => start + Duration(milliseconds: levels.length * 40);
  AudioLevel? at(Duration position) {
    final index = (position - start).inMilliseconds ~/ 40;
    if (position < start || index >= levels.length) return null;
    return levels[index];
  }
}

/// A silent, separate decoder measures at most 12 seconds ahead. Two small
/// windows are retained; no microphone, full-track extraction or audio filters.
/// Sampling uses the audible player's position, including pause/seek/rate.
class PcmAudioAnalyzer {
  static const sampleRate = 16000;
  static const windowDuration = Duration(seconds: 12);
  static const maxPcmBytes = sampleRate * 2 * 12 + 8192;
  final _windows = <_AudioWindow>[];
  String? _source;
  int _generation = 0, _failures = 0;
  bool _closed = false;
  Future<void>? _pending;
  final _cancel = Completer<void>();
  String? message;

  AudioLevel? sample(Media media, Duration position) {
    if (_closed) return null;
    final key = '${media.uri}\n${media.httpHeaders}';
    if (_source != key) {
      _source = key;
      _windows.clear();
      _generation++;
      _failures = 0;
      message = null;
    }
    _AudioWindow? current;
    for (final window in _windows) {
      if (window.at(position) != null) {
        current = window;
        break;
      }
    }
    final nextStart =
        current?.end ?? Duration(seconds: math.max(0, position.inSeconds));
    final needsNext =
        current == null || current.end - position < const Duration(seconds: 2);
    if (_pending == null &&
        _failures < 3 &&
        needsNext &&
        !_windows.any((w) => w.start == nextStart)) {
      final generation = _generation;
      _pending = _decode(media, nextStart)
          .then((window) {
            if (_closed || generation != _generation) return;
            _failures = 0;
            _windows.add(window);
            if (_windows.length > 2) _windows.removeAt(0);
            message = null;
          })
          .catchError((Object _) {
            if (!_closed && generation == _generation) {
              _failures++;
              message = 'Audio response could not decode this recording.';
            }
          })
          .whenComplete(() => _pending = null);
    }
    return current?.at(position);
  }

  Future<_AudioWindow> _decode(Media media, Duration start) async {
    final directory = await Directory.systemTemp.createTemp('tangerine-meter-');
    final output = File('${directory.path}/level.pcm');
    Player? player;
    StreamSubscription<bool>? completion;
    StreamSubscription<String>? errors;
    try {
      player = Player(
        configuration: const PlayerConfiguration(bufferSize: 1024 * 1024),
      );
      final native = player.platform;
      if (native is! NativePlayer) {
        throw UnsupportedError(
          'Decoded audio analysis requires native playback',
        );
      }
      final finished = Completer<void>();
      String? decodeError;
      completion = player.stream.completed.listen((value) {
        if (value && !finished.isCompleted) finished.complete();
      });
      errors = player.stream.error.listen((message) {
        decodeError = message;
        if (!finished.isCompleted) finished.complete();
      });
      // Attach an error handler before loading, including errors emitted during
      // configuration. This also makes disposal interrupt a waiting decoder.
      final done = Future.any([finished.future, _cancel.future]);
      await native.setProperty('vid', 'no');
      await native.setProperty('ao', 'pcm');
      await native.setProperty('ao-pcm-file', output.path);
      await native.setProperty('ao-pcm-waveheader', 'no');
      await native.setProperty('audio-format', 's16');
      await native.setProperty('audio-channels', 'mono');
      await native.setProperty('audio-samplerate', '$sampleRate');
      await native.setProperty('af', '');
      // Disable cache/download readahead; this worker owns only a bounded slice.
      await native.setProperty('cache', 'no');
      await player
          .open(
            Media(
              media.uri,
              httpHeaders: media.httpHeaders,
              start: start,
              end: start + windowDuration,
            ),
          )
          .timeout(const Duration(seconds: 8));
      await done.timeout(const Duration(seconds: 8));
      if (decodeError != null) throw StateError(decodeError!);
      await player.stop();
      if (_closed) return _AudioWindow(start, []);
      final length = await output.length();
      if (length > maxPcmBytes) {
        throw StateError('Audio analysis exceeded its bounded window');
      }
      final levels = AudioLevel.decodePcm(await output.readAsBytes());
      if (levels.isEmpty) {
        throw StateError('Audio analysis returned no samples');
      }
      return _AudioWindow(start, levels);
    } finally {
      await completion?.cancel();
      await errors?.cancel();
      try {
        await player?.dispose();
      } finally {
        if (await directory.exists()) await directory.delete(recursive: true);
      }
    }
  }

  Future<void> close() async {
    _closed = true;
    _generation++;
    _windows.clear();
    if (!_cancel.isCompleted) _cancel.complete();
    await _pending;
  }
}
