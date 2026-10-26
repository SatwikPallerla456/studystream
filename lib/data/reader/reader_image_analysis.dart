import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';
import '../../domain/reader/reader_jobs.dart';

class RecognizedReaderLine {
  const RecognizedReaderLine(this.text, this.bounds, this.confidence);
  final String text;

  /// Normalized top-left coordinates of the upright analysis raster.
  /// These are not PDF media-box coordinates or native text character offsets.
  final ui.Rect bounds;
  final double confidence;
}

abstract final class ReaderImageAnalysis {
  static const _channel = MethodChannel('tangerine/reader_analysis');
  static bool get available =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.macOS;

  static String get supportDescription => available
      ? 'On-device image text recognition uses Apple Vision on macOS. No page images are uploaded.'
      : 'Raster OCR is currently available on macOS through Apple Vision. iOS, Android, Windows, Linux and browser OCR engines are not integrated. EPUB text search and PDF native text selection/search work independently of OCR; scanned images have no searchable text until OCR is added.';

  static Future<Uint8List> raster(
    Uint8List encoded,
    ReaderCancellation token,
  ) async {
    if (encoded.length > 32 * 1024 * 1024)
      throw const FormatException('Page exceeds the analysis input limit.');
    final buffer = await ui.ImmutableBuffer.fromUint8List(encoded);
    ui.ImageDescriptor? descriptor;
    try {
      descriptor = await ui.ImageDescriptor.encoded(buffer);
      token.check();
      final scale = math.min(
        1.0,
        math.min(
          2048 / math.max(descriptor.width, descriptor.height),
          math.sqrt(4 * 1024 * 1024 / (descriptor.width * descriptor.height)),
        ),
      );
      final codec = await descriptor.instantiateCodec(
        targetWidth: math.max(1, (descriptor.width * scale).round()),
        targetHeight: math.max(1, (descriptor.height * scale).round()),
      );
      try {
        final image = (await codec.getNextFrame()).image;
        try {
          token.check();
          return await opaquePng(image, token);
        } finally {
          image.dispose();
        }
      } finally {
        codec.dispose();
      }
    } finally {
      descriptor?.dispose();
      buffer.dispose();
    }
  }

  static Future<Uint8List> opaquePng(
    ui.Image image,
    ReaderCancellation token,
  ) async {
    if (image.width * image.height > 4 * 1024 * 1024)
      throw const FormatException('Analysis raster exceeds 4 MiPixels.');
    token.check();
    final recorder = ui.PictureRecorder();
    // The white matte matches raster background sampling, independently of the
    // user's black/immersive reader surface.
    final painter = ui.Canvas(recorder);
    painter.drawColor(const ui.Color(0xffffffff), ui.BlendMode.src);
    painter.drawImage(image, ui.Offset.zero, ui.Paint());
    final picture = recorder.endRecording();
    try {
      final opaque = await picture.toImage(image.width, image.height);
      try {
        final data = await opaque.toByteData(format: ui.ImageByteFormat.png);
        token.check();
        if (data == null || data.lengthInBytes > 20 * 1024 * 1024)
          throw const FormatException('Analysis raster could not be encoded.');
        return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
      } finally {
        opaque.dispose();
      }
    } finally {
      picture.dispose();
    }
  }

  static Future<List<RecognizedReaderLine>> recognize(
    Uint8List png,
    ReaderCancellation token,
  ) async {
    if (!available)
      throw UnsupportedError('Image text recognition is available on macOS.');
    token.check();
    final id = const Uuid().v4();
    void cancel() {
      unawaited(
        _channel
            .invokeMethod<void>('cancel', {'id': id})
            .catchError((Object _) {}),
      );
    }

    token.onCancel(cancel);
    final result = await _channel
        .invokeMethod<List>('recognize', {'id': id, 'png': png})
        .timeout(
          const Duration(seconds: 45),
          onTimeout: () {
            cancel();
            throw TimeoutException('Text recognition timed out.');
          },
        );
    token.check();
    if (result == null || result.length > 500)
      throw const FormatException('Invalid recognition response.');
    var length = 0;
    return [
      for (final row in result)
        _line(row, (size) {
          length += size;
          if (length > 16000)
            throw const FormatException(
              'Recognition text exceeds the output limit.',
            );
        }),
    ];
  }

  static RecognizedReaderLine _line(Object? value, void Function(int) count) {
    if (value is! Map ||
        value['text'] is! String ||
        (value['text'] as String).length > 2000)
      throw const FormatException('Invalid recognized line.');
    double n(String key) {
      final number = value[key];
      if (number is! num || !number.isFinite || number < 0 || number > 1)
        throw const FormatException('Invalid recognition coordinates.');
      return number.toDouble();
    }

    final text = value['text'] as String;
    count(text.length);
    final rect = ui.Rect.fromLTWH(n('x'), n('y'), n('width'), n('height'));
    if (rect.right > 1.0001 || rect.bottom > 1.0001)
      throw const FormatException('Invalid recognition bounds.');
    return RecognizedReaderLine(text, rect, n('confidence'));
  }
}
