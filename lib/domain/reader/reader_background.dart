import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

/// Version 1 samples unrotated decoded RGBA with floor/ceil strip inclusion.
/// Transparent pixels are composited onto an opaque white matte, not discarded.
class ReaderEdgeColors {
  const ReaderEdgeColors(this.first, this.second, this.combined);
  static const algorithmVersion = 1;
  static const matte = Color(0xffffffff);
  final Color first, second, combined;
  static ReaderEdgeColors sample(
    ByteData pixels,
    int width,
    int height, {
    bool vertical = false,
    int? sourceWidth,
    int? sourceHeight,
  }) {
    if (width < 1 || height < 1 || pixels.lengthInBytes < width * height * 4) {
      return const ReaderEdgeColors(
        Color(0xff222222),
        Color(0xff222222),
        Color(0xff222222),
      );
    }
    final w = sourceWidth ?? width, h = sourceHeight ?? height;
    final thickness = math.max(1.0, math.sqrt(.009 * w * h) / 4);
    final t = math.max(
      1,
      (thickness * (vertical ? height / h : width / w)).ceil(),
    );
    ({int r, int g, int b, int n}) strip(bool first) {
      var r = 0, g = 0, b = 0, n = 0;
      for (var y = 0; y < height; y++) {
        for (var x = 0; x < width; x++) {
          final edge = vertical
              ? (first ? y < t : y >= height - t)
              : (first ? x < t : x >= width - t);
          if (!edge) continue;
          final i = (y * width + x) * 4, a = pixels.getUint8(i + 3);
          r += (pixels.getUint8(i) * a + 255 * (255 - a) + 127) ~/ 255;
          g += (pixels.getUint8(i + 1) * a + 255 * (255 - a) + 127) ~/ 255;
          b += (pixels.getUint8(i + 2) * a + 255 * (255 - a) + 127) ~/ 255;
          n++;
        }
      }
      return (r: r, g: g, b: b, n: n);
    }

    final a = strip(true), b = strip(false);
    Color color(({int r, int g, int b, int n}) c) =>
        Color.fromARGB(255, c.r ~/ c.n, c.g ~/ c.n, c.b ~/ c.n);
    // Equal normalized contribution from the two strips even for narrow images.
    final ca = color(a), cb = color(b);
    final combined = Color.fromARGB(
      255,
      ((ca.r + cb.r) * 127.5).round(),
      ((ca.g + cb.g) * 127.5).round(),
      ((ca.b + cb.b) * 127.5).round(),
    );
    return ReaderEdgeColors(ca, cb, combined);
  }
}
