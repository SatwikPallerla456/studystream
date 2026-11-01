import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;
import 'package:flutter/services.dart';
import '../../data/music/music_session.dart';
import '../../domain/music/music_models.dart';
import '../../shared/widgets/item_artwork.dart';
import 'music_art.dart';

String _time(Duration d) =>
    '${d.inMinutes}:${d.inSeconds.remainder(60).toString().padLeft(2, '0')}';

class ImmersiveMusicPlayer extends StatelessWidget {
  const ImmersiveMusicPlayer({
    super.key,
    required this.session,
    required this.onAction,
    required this.onBack,
    required this.run,
    required this.onShuffle,
    required this.onRepeat,
    required this.onPlay,
    this.error,
  });
  final MusicSession session;
  final void Function(String) onAction;
  final VoidCallback onBack, onShuffle, onRepeat;
  final Future<void> Function(Future<void> Function()) run;
  final String? error;
  final Future<void> Function() onPlay;
  @override
  Widget build(BuildContext context) {
    final track = session.track!, player = session.player!;
    final playing = player.state.playing;
    final position = player.state.position, duration = player.state.duration;
    final foreground = ThemeData.dark(useMaterial3: true).copyWith(
      scaffoldBackgroundColor: Colors.transparent,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xffd9bca7),
        brightness: Brightness.dark,
      ).copyWith(primary: Colors.white, onPrimary: Colors.black),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: Colors.white),
      ),
      sliderTheme: const SliderThemeData(
        trackHeight: 3,
        thumbShape: RoundSliderThumbShape(enabledThumbRadius: 5),
        overlayShape: RoundSliderOverlayShape(overlayRadius: 13),
        activeTrackColor: Color(0xccffffff),
        inactiveTrackColor: Color(0x35ffffff),
        thumbColor: Colors.white,
      ),
    );
    return Theme(
      data: foreground,
      child: MusicAtmosphere(
        session: session,
        child: CallbackShortcuts(
          bindings: {
            const SingleActivator(LogicalKeyboardKey.space): () =>
                run(playing ? session.pause : onPlay),
            const SingleActivator(LogicalKeyboardKey.arrowLeft): () =>
                run(() => session.seek(position - const Duration(seconds: 5))),
            const SingleActivator(LogicalKeyboardKey.arrowRight): () =>
                run(() => session.seek(position + const Duration(seconds: 5))),
          },
          child: Focus(
            autofocus: true,
            child: Scaffold(
              backgroundColor: Colors.transparent,
              body: SafeArea(
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: Row(
                        children: [
                          IconButton(
                            tooltip: 'Back to library',
                            onPressed: onBack,
                            icon: const Icon(Icons.arrow_back_rounded),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'NOW PLAYING',
                            style: TextStyle(
                              fontSize: 11,
                              letterSpacing: 2,
                              color: Colors.white60,
                            ),
                          ),
                          const Spacer(),
                          if (MediaQuery.sizeOf(context).width > 680)
                            SizedBox(
                              width: 170,
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.volume_down_rounded,
                                    size: 20,
                                    color: Colors.white70,
                                  ),
                                  Expanded(
                                    child: Slider(
                                      value: session.volume.clamp(0, 100),
                                      max: 100,
                                      onChanged: (v) =>
                                          run(() => session.setVolume(v)),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          IconButton(
                            tooltip: 'Listening and atmosphere',
                            onPressed: () => onAction('settings'),
                            icon: const Icon(Icons.tune_rounded),
                          ),
                          PopupMenuButton<String>(
                            tooltip: 'Lyrics and listening tools',
                            onSelected: onAction,
                            icon: const Icon(Icons.more_horiz_rounded),
                            itemBuilder: (_) => [
                              for (final row in const <String, String>{
                                'import': 'Import lyrics / CUE',
                                'edit': 'Edit lyrics',
                                'queue': 'Queue & playlists',
                                'outputs': 'Audio output profiles',
                                'library': 'Music library',
                                'details': 'Recording details view',
                                'native': 'Full native player controls',
                              }.entries)
                                PopupMenuItem(
                                  value: row.key,
                                  child: Text(row.value),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, box) {
                          final wide = box.maxWidth >= 820;
                          final lyrics = session.lyrics.isEmpty
                              ? _emptyLyrics(context)
                              : MusicLyricsViewport(
                                  key: ValueKey(track.item.id),
                                  lines: session.lyrics,
                                  position: position,
                                  playing: playing && !player.state.buffering,
                                  rate: player.state.rate,
                                  onSeek: (time) =>
                                      run(() => session.seek(time)),
                                );
                          if (!wide)
                            return Column(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    24,
                                    12,
                                    24,
                                    8,
                                  ),
                                  child: Row(
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(10),
                                        child: ItemArtwork(
                                          item: track.item,
                                          size: 64,
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              track.title,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontSize: 19,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                            Text(
                                              track.artist,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                color: Colors.white60,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Expanded(child: lyrics),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                  ),
                                  child: _transport(),
                                ),
                              ],
                            );
                          final coverWidth = (box.maxWidth * .29).clamp(
                            240.0,
                            400.0,
                          );
                          return Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: (box.maxWidth * .065).clamp(28, 110),
                            ),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: (box.maxWidth * .36).clamp(
                                    280.0,
                                    470.0,
                                  ),
                                  child: LayoutBuilder(
                                    builder: (context, column) {
                                      final artSize = math.min(
                                        coverWidth,
                                        (column.maxHeight - 210).clamp(
                                          120.0,
                                          440.0,
                                        ),
                                      );
                                      return SingleChildScrollView(
                                        child: ConstrainedBox(
                                          constraints: BoxConstraints(
                                            minHeight: column.maxHeight,
                                          ),
                                          child: Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              RepaintBoundary(
                                                child: Container(
                                                  decoration: BoxDecoration(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          14,
                                                        ),
                                                    boxShadow: const [
                                                      BoxShadow(
                                                        color: Color(
                                                          0x38000000,
                                                        ),
                                                        blurRadius: 50,
                                                        offset: Offset(0, 20),
                                                      ),
                                                    ],
                                                  ),
                                                  child: ClipRRect(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          14,
                                                        ),
                                                    child: ItemArtwork(
                                                      item: track.item,
                                                      size: artSize.toDouble(),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(height: 34),
                                              Align(
                                                alignment: Alignment.centerLeft,
                                                child: Text(
                                                  track.title,
                                                  maxLines: 2,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    fontSize: 23,
                                                    fontWeight: FontWeight.w700,
                                                    letterSpacing: -.4,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Align(
                                                alignment: Alignment.centerLeft,
                                                child: Text(
                                                  '${track.artist} — ${track.metadata['album'] ?? ''}',
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    fontSize: 17,
                                                    color: Colors.white60,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(height: 12),
                                              _transport(),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                SizedBox(
                                  width: (box.maxWidth * .075).clamp(28, 120),
                                ),
                                Expanded(child: lyrics),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    if (error != null || session.error != null)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                        child: Text(
                          error ?? session.error!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xffffdfb4),
                            fontSize: 12,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _emptyLyrics(BuildContext context) => SingleChildScrollView(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            session.track!.extras['lyrics'] as String? ??
                'Let the music fill the room.',
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w600,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 20),
          TextButton.icon(
            onPressed: () => onAction('import'),
            icon: const Icon(Icons.lyrics_outlined),
            label: const Text('Add synchronized lyrics'),
          ),
        ],
      ),
    ),
  );
  Widget _transport() {
    final player = session.player!, duration = session.player!.state.duration;
    final position = player.state.position;
    final max = duration.inMilliseconds.toDouble();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Slider(
          value: position.inMilliseconds.toDouble().clamp(0, max > 0 ? max : 1),
          max: max > 0 ? max : 1,
          onChanged: max == 0
              ? null
              : (value) => run(
                  () => session.seek(Duration(milliseconds: value.round())),
                ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _time(position),
                style: const TextStyle(color: Colors.white54, fontSize: 11),
              ),
              Text(
                '−${_time(duration > position ? duration - position : Duration.zero)}',
                style: const TextStyle(color: Colors.white54, fontSize: 11),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            if (session.queued)
              IconButton(
                tooltip: 'Shuffle queue',
                onPressed: onShuffle,
                icon: Icon(
                  Icons.shuffle_rounded,
                  color: session.shuffled ? Colors.white : Colors.white38,
                ),
              )
            else
              const SizedBox(width: 48),
            IconButton(
              tooltip: 'Previous recording',
              iconSize: 32,
              onPressed: () => run(() => session.skip(-1)),
              icon: const Icon(Icons.skip_previous_rounded),
            ),
            IconButton(
              tooltip: player.state.playing ? 'Pause' : 'Play',
              iconSize: 46,
              onPressed: () =>
                  run(player.state.playing ? session.pause : onPlay),
              icon: Icon(
                player.state.playing
                    ? Icons.pause_rounded
                    : Icons.play_arrow_rounded,
              ),
            ),
            IconButton(
              tooltip: 'Next recording',
              iconSize: 32,
              onPressed: () => run(() => session.skip(1)),
              icon: const Icon(Icons.skip_next_rounded),
            ),
            IconButton(
              tooltip: 'Repeat mode',
              onPressed: session.queued ? onRepeat : null,
              icon: Icon(
                session.repeatOne
                    ? Icons.repeat_one_rounded
                    : Icons.repeat_rounded,
                color: session.repeatOne || session.repeatAll
                    ? Colors.white
                    : Colors.white38,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
      ],
    );
  }
}

/// A virtual lyric surface with exact, bounded text geometry and user-owned scroll.
class MusicLyricsViewport extends StatefulWidget {
  const MusicLyricsViewport({
    super.key,
    required this.lines,
    required this.position,
    required this.playing,
    required this.rate,
    required this.onSeek,
  });
  final List<LyricLine> lines;
  final Duration position;
  final bool playing;
  final double rate;
  final Future<void> Function(Duration) onSeek;
  @override
  State<MusicLyricsViewport> createState() => _LyricsViewportState();
}

class _LyricsViewportState extends State<MusicLyricsViewport>
    with SingleTickerProviderStateMixin {
  final _scroll = ScrollController();
  late final _frames = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 20),
  );
  final _clock = Stopwatch()..start();
  int _anchor = 0, _sampleTime = 0, _active = -1;
  bool _follow = true, _queued = false, _disposed = false;
  double _width = -1, _font = 0;
  TextScaler? _scaler;
  List<LyricLine>? _measured;
  final _heights = <double>[], _offsets = <double>[];
  @override
  void initState() {
    super.initState();
    _sample();
  }

  void _sample() {
    _anchor = widget.position.inMilliseconds;
    _sampleTime = _clock.elapsedMilliseconds;
  }

  int _displayTime() =>
      _anchor +
      (widget.playing
          ? ((_clock.elapsedMilliseconds - _sampleTime).clamp(0, 160) *
                    widget.rate)
                .round()
          : 0);
  @override
  void didUpdateWidget(MusicLyricsViewport old) {
    super.didUpdateWidget(old);
    if (old.position != widget.position ||
        old.playing != widget.playing ||
        old.rate != widget.rate)
      _sample();
  }

  void _measure(BuildContext context, double width, double font) {
    final scaler = MediaQuery.textScalerOf(context);
    if (_width == width &&
        _font == font &&
        _scaler == scaler &&
        identical(_measured, widget.lines))
      return;
    _width = width;
    _font = font;
    _scaler = scaler;
    _measured = widget.lines;
    _heights.clear();
    _offsets.clear();
    var offset = 0.0;
    for (final line in widget.lines) {
      final painter = TextPainter(
        text: TextSpan(
          text: line.text.isEmpty ? '•••' : line.text,
          style: _style(font),
        ),
        textScaler: scaler,
        textDirection: Directionality.of(context),
      )..layout(maxWidth: width);
      _offsets.add(offset);
      final height = painter.height + 32;
      _heights.add(height);
      offset += height;
      painter.dispose();
    }
    _scheduleFollow();
  }

  TextStyle _style(double size) => TextStyle(
    fontSize: size,
    height: 1.23,
    fontWeight: FontWeight.w700,
    letterSpacing: -.7,
  );
  void _scheduleFollow() {
    if (_queued || !_follow) return;
    _queued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _queued = false;
      if (_disposed || !_follow || !_scroll.hasClients || _offsets.isEmpty)
        return;
      final target = _offsets[_active.clamp(0, _offsets.length - 1)].clamp(
        0.0,
        _scroll.position.maxScrollExtent,
      );
      if (MediaQuery.disableAnimationsOf(context)) {
        _scroll.jumpTo(target);
      } else {
        unawaited(
          _scroll.animateTo(
            target,
            duration: const Duration(milliseconds: 650),
            curve: Curves.easeOutCubic,
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _frames.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final reduced =
          MediaQuery.disableAnimationsOf(context) ||
          MediaQuery.accessibleNavigationOf(context);
      if (widget.playing && !reduced && !_frames.isAnimating) _frames.repeat();
      if ((!widget.playing || reduced) && _frames.isAnimating) _frames.stop();
      final font = box.maxWidth > 600
          ? 44.0
          : box.maxWidth > 380
          ? 37.0
          : 29.0;
      _measure(context, box.maxWidth - 24, font);
      var active = -1;
      for (var i = 0; i < widget.lines.length; i++) {
        if (widget.lines[i].milliseconds <= widget.position.inMilliseconds)
          active = i;
        else
          break;
      }
      if (active != _active) {
        _active = active;
        _scheduleFollow();
      }
      return Stack(
        children: [
          Positioned.fill(
            child: ShaderMask(
              blendMode: BlendMode.dstIn,
              shaderCallback: (rect) => const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black,
                  Colors.black,
                  Colors.transparent,
                ],
                stops: [0, .13, .85, 1],
              ).createShader(rect),
              child: NotificationListener<UserScrollNotification>(
                onNotification: (event) {
                  if (event.direction != ScrollDirection.idle && _follow)
                    setState(() => _follow = false);
                  return false;
                },
                child: ListView.builder(
                  controller: _scroll,
                  padding: EdgeInsets.symmetric(vertical: box.maxHeight * .38),
                  itemCount: widget.lines.length,
                  itemExtentBuilder: (index, _) => _heights[index],
                  itemBuilder: (context, i) {
                    final focus = i == _active, distance = (i - _active).abs();
                    final opacity = focus
                        ? 1.0
                        : distance <= 1
                        ? .52
                        : .30;
                    final blur = reduced || focus
                        ? 0.0
                        : math.min(3.2, distance * 1.05);
                    final line = widget.lines[i];
                    return RepaintBoundary(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(0, 16, 24, 16),
                        child: Semantics(
                          label: line.text,
                          button: true,
                          onTap: () => widget.onSeek(
                            Duration(milliseconds: line.milliseconds),
                          ),
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () {
                              setState(() => _follow = true);
                              _scheduleFollow();
                              unawaited(
                                widget.onSeek(
                                  Duration(milliseconds: line.milliseconds),
                                ),
                              );
                            },
                            child: AnimatedOpacity(
                              opacity: opacity,
                              duration: reduced
                                  ? Duration.zero
                                  : const Duration(milliseconds: 420),
                              child: TweenAnimationBuilder<double>(
                                tween: Tween(end: blur),
                                duration: reduced
                                    ? Duration.zero
                                    : const Duration(milliseconds: 420),
                                builder: (context, sigma, child) =>
                                    ImageFiltered(
                                      imageFilter: ui.ImageFilter.blur(
                                        sigmaX: sigma,
                                        sigmaY: sigma,
                                      ),
                                      child: child,
                                    ),
                                child: CustomPaint(
                                  size: Size(_width, _heights[i] - 32),
                                  painter: _LyricPainter(
                                    line: line,
                                    focus: focus,
                                    style: _style(font),
                                    scaler: _scaler!,
                                    direction: Directionality.of(context),
                                    time: _displayTime,
                                    frames: focus ? _frames : null,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
          if (!_follow)
            Positioned(
              right: 12,
              bottom: 8,
              child: TextButton.icon(
                style: TextButton.styleFrom(
                  backgroundColor: const Color(0x35000000),
                  foregroundColor: Colors.white,
                ),
                onPressed: () {
                  setState(() => _follow = true);
                  _scheduleFollow();
                },
                icon: const Icon(Icons.my_location_rounded, size: 16),
                label: const Text('Current lyric'),
              ),
            ),
        ],
      );
    },
  );
}

class _LyricPainter extends CustomPainter {
  _LyricPainter({
    required this.line,
    required this.focus,
    required this.style,
    required this.scaler,
    required this.direction,
    required this.time,
    Listenable? frames,
  }) : super(repaint: frames);
  final LyricLine line;
  final bool focus;
  final TextStyle style;
  final TextScaler scaler;
  final TextDirection direction;
  final int Function() time;
  @override
  void paint(Canvas canvas, Size size) {
    final text = line.text.isEmpty ? '•••' : line.text;
    final base = TextPainter(
      text: TextSpan(
        text: text,
        style: style.copyWith(
          color: focus && line.spans.isNotEmpty ? Colors.white38 : Colors.white,
        ),
      ),
      textDirection: direction,
      textScaler: scaler,
    )..layout(maxWidth: size.width);
    base.paint(canvas, Offset.zero);
    if (focus && line.spans.isNotEmpty) {
      final ink = TextPainter(
        text: TextSpan(
          text: text,
          style: style.copyWith(
            color: Colors.white,
            shadows: const [Shadow(color: Color(0x22ffffff), blurRadius: 8)],
          ),
        ),
        textDirection: direction,
        textScaler: scaler,
      )..layout(maxWidth: size.width);
      final now = time();
      for (final span in line.spans) {
        if (span.to > text.length ||
            span.from < 0 ||
            span.to <= span.from ||
            now < span.start)
          continue;
        final progress = span.end <= span.start
            ? 1.0
            : ((now - span.start) / (span.end - span.start)).clamp(0.0, 1.0);
        final boxes = ink.getBoxesForSelection(
          TextSelection(baseOffset: span.from, extentOffset: span.to),
        );
        final total = boxes.fold<double>(
          0,
          (sum, box) => sum + box.right - box.left,
        );
        var remaining = total * progress;
        for (final box in boxes) {
          final width = math
              .min(box.right - box.left, remaining)
              .clamp(0.0, double.infinity);
          remaining -= width;
          if (width <= 0) continue;
          final left = box.direction == TextDirection.rtl
              ? box.right - width
              : box.left;
          canvas.save();
          canvas.clipRect(
            Rect.fromLTWH(
              left - .5,
              box.top - 4,
              width + 1,
              box.bottom - box.top + 8,
            ),
          );
          ink.paint(canvas, Offset.zero);
          canvas.restore();
        }
      }
      ink.dispose();
    }
    base.dispose();
  }

  @override
  bool shouldRepaint(covariant _LyricPainter old) => true;
}
