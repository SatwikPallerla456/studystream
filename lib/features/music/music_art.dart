import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'dart:typed_data';
import '../../shared/widgets/remote_item_artwork.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/music/music_session.dart';
import '../../shared/widgets/item_artwork.dart';

/// Bounded artwork palette and a measured amplitude/onset envelope. No timed
/// fake beats, rapid full-screen brightness flashes or genre-name guessing.
class MusicAtmosphere extends ConsumerStatefulWidget {
  const MusicAtmosphere({
    super.key,
    required this.session,
    required this.child,
  });
  final MusicSession session;
  final Widget child;
  @override
  ConsumerState<MusicAtmosphere> createState() => _MusicAtmosphereState();
}

class _MusicAtmosphereState extends ConsumerState<MusicAtmosphere>
    with TickerProviderStateMixin {
  List<Color> _palette = const [
    Color(0xffb15d3c),
    Color(0xff515d7d),
    Color(0xff413f5d),
  ];
  late List<Color> _fromPalette = _palette;
  late final _fade = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
    value: 1,
  );
  late final _flow = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 36),
  );
  List<Color> get _currentPalette => [
    for (var i = 0; i < 3; i++)
      Color.lerp(
        _fromPalette[i],
        _palette[i],
        Curves.easeInOut.transform(_fade.value),
      )!,
  ];
  @override
  void dispose() {
    _generation++;
    _flow.dispose();
    _fade.dispose();
    super.dispose();
  }

  String? _path;
  int _generation = 0;
  void _sample(String path, Future<Uint8List> Function() load) {
    if (_path == path) return;
    _path = path;
    final token = ++_generation;
    Future<void>(() async {
      final bytes = await load();
      if (bytes.length > 8 * 1024 * 1024) return;
      final codec = await ui.instantiateImageCodec(
        bytes,
        targetWidth: 32,
        targetHeight: 32,
      );
      try {
        final frame = await codec.getNextFrame();
        try {
          final data = await frame.image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          );
          if (data == null) return;
          final counts = <int, int>{};
          for (var i = 0; i < data.lengthInBytes; i += 4) {
            if (data.getUint8(i + 3) < 200) continue;
            final r = data.getUint8(i),
                g = data.getUint8(i + 1),
                b = data.getUint8(i + 2);
            final key = ((r ~/ 32) << 6) | ((g ~/ 32) << 3) | (b ~/ 32);
            counts[key] = (counts[key] ?? 0) + 1;
          }
          final ordered = counts.entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value));
          final colors = <Color>[];
          for (final entry in ordered) {
            final key = entry.key;
            final color = Color.fromARGB(
              255,
              ((key >> 6) & 7) * 32 + 16,
              ((key >> 3) & 7) * 32 + 16,
              (key & 7) * 32 + 16,
            );
            final hsl = HSLColor.fromColor(color);
            if (hsl.lightness < .08 || hsl.lightness > .92) continue;
            if (colors.any(
              (c) => (HSLColor.fromColor(c).hue - hsl.hue).abs() < 30,
            ))
              continue;
            colors.add(
              hsl
                  .withSaturation(hsl.saturation.clamp(.18, .75))
                  .withLightness(hsl.lightness.clamp(.32, .58))
                  .toColor(),
            );
            if (colors.length == 3) break;
          }
          if (colors.isNotEmpty && mounted && token == _generation) {
            setState(() {
              _fromPalette = _currentPalette;
              _palette = [
                ...colors,
                for (var i = colors.length; i < 3; i++)
                  HSLColor.fromColor(colors.first)
                      .withHue(
                        (HSLColor.fromColor(colors.first).hue +
                                (i == 1 ? 14 : 350)) %
                            360,
                      )
                      .withLightness(i == 1 ? .34 : .48)
                      .toColor(),
              ];
            });
            _fade.forward(from: 0);
          }
        } finally {
          frame.image.dispose();
        }
      } finally {
        codec.dispose();
      }
    }).catchError((Object _) {});
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session, item = session.track?.item;
    if (item != null) {
      if (item.filePath.startsWith('remote:')) {
        final bytes = ref.watch(remoteArtworkBytesProvider(item)).asData?.value;
        if (bytes != null)
          _sample(
            'remote:${item.id}:${identityHashCode(bytes)}',
            () => Future.value(bytes),
          );
      } else {
        final path =
            ref.watch(catalogArtworkPathProvider(item)).asData?.value ??
            ref.watch(itemArtworkPathProvider(item)).asData?.value;
        if (path != null)
          _sample(path, () async {
            final file = File(path);
            if (await file.length() > 8 * 1024 * 1024) return Uint8List(0);
            return file.readAsBytes();
          });
      }
    }
    final reduced =
        MediaQuery.disableAnimationsOf(context) ||
        MediaQuery.accessibleNavigationOf(context);
    return ListenableBuilder(
      listenable: Listenable.merge([session, _fade]),
      builder: (context, _) {
        final animated = !reduced && session.visualStyle != 'off';
        final strength = animated ? session.visualIntensity : 0.0;
        final flowing =
            animated &&
            session.visualIntensity > 0 &&
            session.player?.state.playing == true;
        if (flowing && !_flow.isAnimating) _flow.repeat();
        if (!flowing && _flow.isAnimating) _flow.stop();
        final rough = session.visualStyle == 'calm'
            ? 0.0
            : session.visualStyle == 'punchy'
            ? 1.0
            : session.grit;
        return Stack(
          fit: StackFit.expand,
          children: [
            CustomPaint(
              painter: _AtmospherePainter(
                reduced ? _palette : _currentPalette,
                session.energy * strength,
                session.beat * strength,
                rough * strength,
                () => animated ? _flow.value : 0,
                _flow,
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: .06),
                    Colors.black.withValues(alpha: .22),
                  ],
                ),
              ),
            ),
            widget.child,
          ],
        );
      },
    );
  }
}

class _AtmospherePainter extends CustomPainter {
  _AtmospherePainter(
    this.colors,
    this.energy,
    this.beat,
    this.grit,
    this.phase,
    Listenable motion,
  ) : super(repaint: motion);
  final List<Color> colors;
  final double energy, beat, grit;
  final double Function() phase;
  @override
  void paint(Canvas canvas, Size size) {
    final t = phase() * math.pi * 2;
    final base = HSLColor.fromColor(colors.first)
        .withSaturation(
          (HSLColor.fromColor(colors.first).saturation * .85).clamp(.25, .8),
        )
        .withLightness(.19 + energy * .025)
        .toColor();
    canvas.drawRect(Offset.zero & size, Paint()..color = base);
    final force = .04 + energy * .11 + beat * .025;
    for (var i = 0; i < 5; i++) {
      final angle = t + i * 2.1;
      final x = .5 + math.sin(angle * (i.isEven ? 1 : 2)) * (.34 + force);
      final y =
          .5 +
          math.cos(angle + i) * (.36 + force) +
          math.sin(angle * 3) * grit * .045;
      final center = Offset(size.width * x, size.height * y);
      final radius =
          size.longestSide * (.65 + .07 * math.sin(angle) + energy * .1);
      final source = HSLColor.fromColor(colors[i % 3]);
      final color = source
          .withLightness(
            (source.lightness * .83 + .03 * math.sin(angle)).clamp(.25, .48),
          )
          .toColor();
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..shader = RadialGradient(
            colors: [
              color.withValues(alpha: .65 + energy * .12),
              color.withValues(alpha: .22),
              color.withValues(alpha: 0),
            ],
            stops: const [0, .48, 1],
          ).createShader(Rect.fromCircle(center: center, radius: radius)),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _AtmospherePainter old) => true;
}
