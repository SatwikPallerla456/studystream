import 'dart:async';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import '../../data/db/app_database.dart';
import '../../data/playback/playback_engine.dart';
import '../../data/sync/lan_sync_client.dart';
import '../../domain/services/player_controls_repository.dart';

class VideoComparisonScreen extends StatefulWidget {
  const VideoComparisonScreen({
    super.key,
    required this.database,
    required this.client,
    required this.first,
    required this.second,
    this.position = Duration.zero,
    this.volume = 75,
    this.rate = 1,
  });
  final AppDatabase database;
  final LanSyncClient client;
  final Item first, second;
  final Duration position;
  final double volume, rate;
  @override
  State<VideoComparisonScreen> createState() => _VideoComparisonState();
}

class _VideoComparisonState extends State<VideoComparisonScreen> {
  PlaybackEngine? _a, _b;
  Timer? _clock;
  bool _busy = true, _playing = false, _syncing = false, _closed = false;
  bool _stacked = false, _audioB = false, _inRange = true;
  double _offset = 0, _speed = 1;
  int _lastCorrection = 0;
  String? _error;
  final _offsetInput = TextEditingController(text: '0');
  Future<void> _tail = Future.value();
  late final Future<void> _opening;
  Future<void>? _closing;
  bool _exitAllowed = false, _leaving = false;
  Future<void> _close() => _closing ??= () async {
    _closed = true;
    _clock?.cancel();
    await _opening.catchError((Object _) {});
    await _tail.catchError((Object _) {});
    try {
      await _a?.dispose();
    } finally {
      await _b?.dispose();
    }
    _a = null;
    _b = null;
  }();
  Future<void> _leave() async {
    if (_leaving) return;
    _leaving = true;
    try {
      await _close().catchError((Object _) {});
    } finally {
      if (mounted) {
        setState(() => _exitAllowed = true);
        Navigator.pop(context);
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _speed = widget.rate;
    _opening = _open();
  }

  Future<void> _open() async {
    PlaybackEngine? a, b;
    try {
      final preferences = await PlayerControlsRepository(
        widget.database,
      ).nativePreferences();
      a = await PlaybackEngine.create(
        nativePreferences: {
          ...preferences,
          'embeddedVideo': 'true',
          'startFullscreen': 'false',
        },
      );
      if (_closed) {
        await a.dispose();
        return;
      }
      _a = a;
      b = await PlaybackEngine.create(
        nativePreferences: {
          ...preferences,
          'embeddedVideo': 'true',
          'startFullscreen': 'false',
        },
      );
      if (_closed) {
        await b.dispose();
        return;
      }
      _b = b;
      for (final pair in [(a, widget.first), (b, widget.second)]) {
        final source = await widget.client.sourceFor(pair.$2);
        await pair.$1.open(
          Media(source.uri.toString(), httpHeaders: source.headers),
          play: false,
        );
        if (_closed) return;
      }
      await a.setVolume(widget.volume);
      await b.setVolume(0);
      await a.setRate(_speed);
      await b.setRate(_speed);
      await a.seek(_bound(widget.position, a));
      await b.seek(_bound(widget.position, b));
      if (mounted) setState(() => _busy = false);
      _clock = Timer.periodic(const Duration(milliseconds: 200), (_) {
        if (!_busy && !_syncing && !_closed) unawaited(_synchronize());
      });
    } catch (e) {
      if (mounted)
        setState(() {
          _error =
              'Comparison could not open. Check that both files and their codecs are available.';
          _busy = false;
        });
    }
  }

  Duration _bound(Duration position, PlaybackEngine engine) => Duration(
    milliseconds: position.inMilliseconds.clamp(
      0,
      engine.state.duration.inMilliseconds,
    ),
  );
  Future<void> _run(Future<void> Function() action) {
    final next = _tail.catchError((Object _) {}).then((_) async {
      if (_closed) return;
      _busy = true;
      try {
        await action();
        if (mounted) setState(() => _error = null);
      } catch (e) {
        if (mounted)
          setState(
            () => _error =
                'Comparison could not synchronize. Check source availability or reduce the offset.',
          );
      } finally {
        _busy = false;
        if (mounted) setState(() {});
      }
    });
    _tail = next;
    return next;
  }

  Future<void> _synchronize() async {
    if (_a == null || _b == null || _closed) return;
    _syncing = true;
    try {
      await _run(() async {
        final a = _a!, b = _b!;
        final target =
            a.state.position + Duration(milliseconds: (_offset * 1000).round());
        _inRange = target >= Duration.zero && target <= b.state.duration;
        if (!_playing || !_inRange || a.state.buffering || a.state.completed) {
          if (b.state.playing) await b.pause();
          if (a.state.completed) _playing = false;
        } else {
          final now = DateTime.now().millisecondsSinceEpoch;
          if ((b.state.position - target).inMilliseconds.abs() > 150 &&
              now - _lastCorrection > 900) {
            _lastCorrection = now;
            await b.seek(target);
          }
          if (!b.state.playing && !b.state.buffering) await b.play();
        }
      });
    } finally {
      _syncing = false;
    }
  }

  Future<void> _seek(Duration value) => _run(() async {
    await _a!.seek(_bound(value, _a!));
    await _b!.seek(
      _bound(value + Duration(milliseconds: (_offset * 1000).round()), _b!),
    );
  });
  @override
  void dispose() {
    _offsetInput.dispose();
    unawaited(_close().catchError((Object _) {}));
    super.dispose();
  }

  Widget _pane(PlaybackEngine engine, String name) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.all(8),
        child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      Expanded(
        child: ColoredBox(color: Colors.black, child: engine.videoSurface()),
      ),
    ],
  );
  @override
  Widget build(BuildContext context) {
    final a = _a, b = _b;
    return PopScope(
      canPop: _exitAllowed,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_leave());
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Synchronized comparison'),
          leading: BackButton(onPressed: _leave),
        ),
        body: a == null || b == null
            ? Center(child: Text(_error ?? 'Opening two comparison decoders…'))
            : Column(
                children: [
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text(_error!),
                    ),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (_, box) {
                        final panes = [
                          _pane(
                            a,
                            'A · ${widget.first.userTitle ?? widget.first.title}',
                          ),
                          _pane(
                            b,
                            'B · ${widget.second.userTitle ?? widget.second.title}',
                          ),
                        ];
                        return _stacked || box.maxWidth < 700
                            ? Column(
                                children: [
                                  for (final pane in panes)
                                    Expanded(child: pane),
                                ],
                              )
                            : Row(
                                children: [
                                  for (final pane in panes)
                                    Expanded(child: pane),
                                ],
                              );
                      },
                    ),
                  ),
                  StreamBuilder<Duration>(
                    stream: a.stream.position,
                    initialData: a.state.position,
                    builder: (_, snapshot) {
                      final max = a.state.duration.inMilliseconds.toDouble();
                      return Slider(
                        value: (snapshot.data?.inMilliseconds ?? 0)
                            .toDouble()
                            .clamp(0, max),
                        max: max > 0 ? max : 1,
                        onChanged: _busy || max == 0
                            ? null
                            : (v) => _seek(Duration(milliseconds: v.round())),
                      );
                    },
                  ),
                  SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          FilledButton.icon(
                            onPressed: _busy
                                ? null
                                : () => _run(() async {
                                    _playing = !_playing;
                                    if (_playing) {
                                      await a.play();
                                      if (_inRange) await b.play();
                                    } else {
                                      await a.pause();
                                      await b.pause();
                                    }
                                  }),
                            icon: Icon(
                              _playing ? Icons.pause : Icons.play_arrow,
                            ),
                            label: Text(_playing ? 'Pause both' : 'Play both'),
                          ),
                          OutlinedButton(
                            onPressed: _busy
                                ? null
                                : () => _seek(Duration.zero),
                            child: const Text('Start'),
                          ),
                          if (a is NativeVlcEngine &&
                              b is NativeVlcEngine &&
                              a.supports('frame') &&
                              b.supports('frame'))
                            OutlinedButton(
                              onPressed: _busy
                                  ? null
                                  : () => _run(() async {
                                      _playing = false;
                                      await a.pause();
                                      await b.pause();
                                      await a.nextFrame();
                                      await b.nextFrame();
                                    }),
                              child: const Text('Frame step both'),
                            ),
                          SizedBox(
                            width: 150,
                            child: TextField(
                              controller: _offsetInput,
                              enabled: !_busy,
                              decoration: const InputDecoration(
                                labelText: 'B offset, seconds',
                              ),
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    signed: true,
                                    decimal: true,
                                  ),
                              onSubmitted: (value) {
                                final n = double.tryParse(value);
                                if (n != null &&
                                    n.isFinite &&
                                    n.abs() <= 3600) {
                                  setState(() => _offset = n);
                                  _seek(a.state.position);
                                }
                              },
                            ),
                          ),
                          DropdownButton<double>(
                            value: _speed,
                            items: [
                              for (final s in <double>{
                                .5,
                                .75,
                                1.0,
                                1.25,
                                1.5,
                                2.0,
                                _speed,
                              })
                                DropdownMenuItem(value: s, child: Text('$s×')),
                            ],
                            onChanged: _busy
                                ? null
                                : (v) => _run(() async {
                                    _speed = v!;
                                    await a.setRate(v);
                                    await b.setRate(v);
                                  }),
                          ),
                          TextButton(
                            onPressed: _busy
                                ? null
                                : () => _run(() async {
                                    _audioB = !_audioB;
                                    await a.setVolume(
                                      _audioB ? 0 : widget.volume,
                                    );
                                    await b.setVolume(
                                      _audioB ? widget.volume : 0,
                                    );
                                  }),
                            child: Text('Audio: ${_audioB ? 'B' : 'A'}'),
                          ),
                          TextButton(
                            onPressed: () =>
                                setState(() => _stacked = !_stacked),
                            child: Text(_stacked ? 'Side by side' : 'Stacked'),
                          ),
                          Text(
                            _inRange
                                ? 'Target drift ≤150 ms; periodic correction, not frame lock.'
                                : 'B is outside its timeline; change the offset.',
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
