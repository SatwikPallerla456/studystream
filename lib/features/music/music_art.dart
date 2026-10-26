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
    with SingleTickerProviderStateMixin {
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
                for (var i = colors.length; i < 3; i++) colors.first,
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
                rough,
                session.envelope,
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: .18),
                    Colors.black.withValues(alpha: .65),
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
    this.samples,
  );
  final List<Color> colors;
  final List<double> samples;
  final double energy, beat, grit;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xff11151c),
    );
    final push = energy * .08 + beat * .04 * (.4 + grit);
    final positions = [
      Offset(size.width * (.23 - push), size.height * .22),
      Offset(size.width * (.8 + push), size.height * .47),
      Offset(size.width * .4, size.height * (.92 - push)),
    ];
    for (var i = 0; i < 3; i++) {
      final radius = size.longestSide * (.6 + energy * .05);
      canvas.drawCircle(
        positions[i],
        radius,
        Paint()
          ..shader = RadialGradient(
            colors: [
              colors[i].withValues(alpha: .28 + energy * .10 + beat * .07),
              colors[i].withValues(alpha: 0),
            ],
            stops: const [0, 1],
          ).createShader(Rect.fromCircle(center: positions[i], radius: radius)),
      );
    }
    if (grit > .5 && beat > 0.01) {
      final path = Path();
      final center = Offset(size.width * .5, size.height * .42),
          radius = size.shortestSide * (.3 + beat * .08);
      for (var i = 0; i < 20; i++) {
        final a = i * math.pi / 10;
        final r = radius * (i.isEven ? 1 : 1 - grit * .07);
        final point = center + Offset(math.cos(a) * r, math.sin(a) * r);
        if (i == 0)
          path.moveTo(point.dx, point.dy);
        else
          path.lineTo(point.dx, point.dy);
      }
      path.close();
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1 + beat * 2
          ..color = colors[1].withValues(alpha: beat * .18),
      );
    }
    if (samples.length > 1 && energy > 0) {
      final path = Path();
      for (var i = 0; i < samples.length; i++) {
        final x = size.width * i / (samples.length - 1),
            y = size.height - 16 - samples[i] * 32 * (.3 + grit);
        if (i == 0)
          path.moveTo(x, y);
        else
          path.lineTo(x, y);
      }
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = colors[0].withValues(alpha: .25),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _AtmospherePainter old) => true;
}
