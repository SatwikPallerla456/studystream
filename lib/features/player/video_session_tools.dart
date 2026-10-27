import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../../data/db/app_database.dart';
import '../../data/playback/playback_engine.dart';
import 'video_subtitles.dart';

class VideoSessionTools extends ChangeNotifier {
  VideoSessionTools(this.database, this.itemId);
  final AppDatabase database;
  final String itemId;
  final subtitles = VideoSubtitlePresentation();
  int? loopA, loopB;
  bool loopEnabled = false, _seeking = false, _closed = false, _loaded = false;
  String? error;
  StreamSubscription<Duration>? _positions;
  Future<void>? _loopTask;
  int _duration = 0;
  Future<void> detach() async {
    await _positions?.cancel();
    _positions = null;
    await _loopTask;
  }

  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    final raw =
        jsonDecode(
              await database.getSetting('player.video.session.$itemId') ?? '{}',
            )
            as Map;
    loopA = raw['a'] as int?;
    loopB = raw['b'] as int?;
    // Reopening a title does not silently trap playback inside a previous loop.
    subtitles.size = (raw['size'] as num? ?? 24).toDouble().clamp(12, 60);
    subtitles.secondarySize = (raw['secondarySize'] as num? ?? 22)
        .toDouble()
        .clamp(12, 60);
    subtitles.color = raw['color'] as int? ?? 0xffffffff;
    subtitles.enabled = raw['enabled'] != false;
    subtitles.delay = (raw['delay'] as int? ?? 0).clamp(-60000, 60000);
    subtitles.secondaryDelay = (raw['secondaryDelay'] as int? ?? 0).clamp(
      -60000,
      60000,
    );
    subtitles.background = (raw['background'] as num? ?? .65).toDouble().clamp(
      0,
      1,
    );
    for (final secondary in [false, true]) {
      final path = raw[secondary ? 'secondaryFile' : 'primaryFile'];
      if (path is String) {
        try {
          final document = await VideoSubtitleDocument.open(path);
          if (secondary) {
            subtitles.secondary = document;
          } else {
            subtitles.primary = document;
          }
        } catch (_) {
          /* A removed sidecar must not block the video. */
        }
      }
    }
  }

  Future<void> save({
    String? primaryFile,
    String? secondaryFile,
    bool clearPrimary = false,
    bool clearSecondary = false,
  }) async {
    final old =
        jsonDecode(
              await database.getSetting('player.video.session.$itemId') ?? '{}',
            )
            as Map;
    await database.setSetting(
      'player.video.session.$itemId',
      jsonEncode({
        'a': loopA,
        'b': loopB,
        'size': subtitles.size,
        'secondarySize': subtitles.secondarySize,
        'color': subtitles.color,
        'enabled': subtitles.enabled,
        'delay': subtitles.delay,
        'secondaryDelay': subtitles.secondaryDelay,
        'background': subtitles.background,
        if (!clearPrimary) 'primaryFile': primaryFile ?? old['primaryFile'],
        if (!clearSecondary)
          'secondaryFile': secondaryFile ?? old['secondaryFile'],
      }),
    );
    if (!_closed) {
      subtitles.changed();
      notifyListeners();
    }
  }

  Future<void> attach(
    PlaybackEngine player,
    Future<void> Function(Duration) seek,
  ) async {
    await detach();
    _duration = player.state.duration.inMilliseconds;
    _positions = player.stream.position.listen((position) {
      if (_closed ||
          _seeking ||
          !loopEnabled ||
          loopA == null ||
          loopB == null ||
          (!player.state.playing && !player.state.completed))
        return;
      if (position.inMilliseconds >= loopB!) {
        _seeking = true;
        _loopTask = () async {
          try {
            await seek(Duration(milliseconds: loopA!));
            await player.play();
          } catch (_) {
            loopEnabled = false;
            error =
                'This source could not seek the loop. Choose a seekable file.';
            if (!_closed) notifyListeners();
          } finally {
            _seeking = false;
          }
        }();
      }
    });
  }

  Future<void> setLoop(int? start, int? end, {required bool enabled}) async {
    if (enabled &&
        (start == null ||
            end == null ||
            start < 0 ||
            end - start < 500 ||
            (_duration > 0 && end > _duration))) {
      throw const FormatException(
        'Set A and B inside this video, with B at least half a second after A.',
      );
    }
    loopA = start;
    loopB = end;
    loopEnabled = enabled;
    error = null;
    await save();
  }

  @override
  void dispose() {
    _closed = true;
    _positions?.cancel();
    subtitles.dispose();
    super.dispose();
  }
}

/// A single surface moves into the app overlay; the owning engine keeps playing.
class FloatingVideoOverlay extends StatefulWidget {
  const FloatingVideoOverlay({
    super.key,
    required this.surface,
    required this.player,
    required this.onClose,
    this.onBrowse,
  });
  final Widget surface;
  final PlaybackEngine player;
  final VoidCallback onClose;
  final VoidCallback? onBrowse;
  @override
  State<FloatingVideoOverlay> createState() => _FloatingVideoState();
}

class _FloatingVideoState extends State<FloatingVideoOverlay> {
  Offset? _position;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final width = (box.maxWidth * .65)
          .clamp(180.0, 420.0)
          .clamp(0.0, box.maxWidth);
      final height = (width * 9 / 16 + 48).clamp(0.0, box.maxHeight);
      final p =
          _position ??
          Offset(box.maxWidth - width - 16, box.maxHeight - height - 24);
      return Stack(
        children: [
          Positioned(
            left: p.dx.clamp(
              0,
              (box.maxWidth - width).clamp(0, double.infinity),
            ),
            top: p.dy.clamp(
              0,
              (box.maxHeight - height).clamp(0, double.infinity),
            ),
            width: width,
            height: height,
            child: Material(
              elevation: 16,
              color: Colors.black,
              borderRadius: BorderRadius.circular(12),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  Expanded(child: widget.surface),
                  GestureDetector(
                    onPanUpdate: (event) =>
                        setState(() => _position = p + event.delta),
                    child: SizedBox(
                      height: 48,
                      child: Row(
                        children: [
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8),
                            child: Icon(
                              Icons.drag_indicator,
                              color: Colors.white,
                            ),
                          ),
                          StreamBuilder<bool>(
                            stream: widget.player.stream.playing,
                            initialData: widget.player.state.playing,
                            builder: (_, snapshot) => IconButton(
                              color: Colors.white,
                              tooltip: snapshot.data == true ? 'Pause' : 'Play',
                              onPressed: widget.player.playOrPause,
                              icon: Icon(
                                snapshot.data == true
                                    ? Icons.pause
                                    : Icons.play_arrow,
                              ),
                            ),
                          ),
                          const Spacer(),
                          if (widget.onBrowse != null)
                            IconButton(
                              color: Colors.white,
                              tooltip: 'Browse library while playing',
                              onPressed: widget.onBrowse,
                              icon: const Icon(Icons.video_library_outlined),
                            ),
                          IconButton(
                            color: Colors.white,
                            tooltip: 'Return to full player',
                            onPressed: widget.onClose,
                            icon: const Icon(Icons.open_in_full),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    },
  );
}
