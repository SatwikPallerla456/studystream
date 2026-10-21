import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

import '../../data/reader/book_page_source.dart';
import '../../domain/reader/reader_background.dart';
import '../../domain/reader/reader_jobs.dart';
import '../../domain/reader/reader_contract.dart';

class DecodedReaderPage {
  DecodedReaderPage(this.image, this.colors);
  final ui.Image image;
  final ReaderEdgeColors colors;
}

/// Owns a clone of the render result; framework ImageCache is bypassed so page
/// allocations have an explicit lifetime. At most 4 MiPixels per visible page.
class ReaderImagePage extends StatefulWidget {
  const ReaderImagePage({
    super.key,
    required this.source,
    required this.page,
    required this.revision,
    required this.jobs,
    required this.fit,
    required this.targetWidth,
    this.vertical = false,
    required this.onColors,
    this.onSettled,
    this.initialZoom = 1,
    this.initialPoint = Offset.zero,
    this.initialViewState,
    required this.layoutKey,
  });
  final BookPageSource source;
  final int page, targetWidth;
  final String revision, fit, layoutKey;
  final ReaderJobScheduler jobs;
  final bool vertical;
  final double initialZoom;
  final Offset initialPoint;
  final ReaderViewportState? initialViewState;
  final ValueChanged<ReaderEdgeColors> onColors;
  final void Function(double zoom, Offset point, ReaderViewportState state)?
  onSettled;
  @override
  State<ReaderImagePage> createState() => _ReaderImagePageState();
}

class _ReaderImagePageState extends State<ReaderImagePage> {
  ReaderLease<DecodedReaderPage>? _lease;
  ui.Image? _image;
  Object? _error;
  final _transform = TransformationController();
  Offset _tap = Offset.zero;
  Size _viewport = Size.zero;
  bool _positionRestored = false;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final width = widget.targetWidth.clamp(256, 2400);
    final key =
        '${widget.revision}:${widget.source.locator(widget.page)}:$width:${widget.vertical}:rgba-v1:white';
    _lease = widget.jobs.request<DecodedReaderPage>(
      key: key,
      priority: ReaderPriority.visible,
      estimatedBytes: 96 * 1024 * 1024,
      disposeResult: (result) => result.image.dispose(),
      run: (token) async {
        final page = await widget.source.load(widget.page, cancellation: token);
        token.check();
        final bytes = page.image;
        if (bytes == null || bytes.length > 32 * 1024 * 1024)
          throw const FormatException('Page image exceeds the resource budget');
        final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
        ui.ImageDescriptor? descriptor;
        try {
          descriptor = await ui.ImageDescriptor.encoded(buffer);
          final scale = math.min(
            1.0,
            math.min(
              width / descriptor.width,
              math.sqrt(
                4 * 1024 * 1024 / (descriptor.width * descriptor.height),
              ),
            ),
          );
          final codec = await descriptor.instantiateCodec(
            targetWidth: math.max(1, (descriptor.width * scale).round()),
            targetHeight: math.max(1, (descriptor.height * scale).round()),
          );
          late ui.Image result;
          try {
            result = (await codec.getNextFrame()).image;
          } finally {
            codec.dispose();
          }
          try {
            token.check();
            final sampler = await descriptor.instantiateCodec(
              targetWidth: 128,
              targetHeight: 128,
            );
            late ui.Image sample;
            try {
              sample = (await sampler.getNextFrame()).image;
            } finally {
              sampler.dispose();
            }
            late ReaderEdgeColors colors;
            try {
              final data = await sample.toByteData(
                format: ui.ImageByteFormat.rawRgba,
              );
              colors = data == null
                  ? const ReaderEdgeColors(
                      Colors.black,
                      Colors.black,
                      Colors.black,
                    )
                  : ReaderEdgeColors.sample(
                      data,
                      sample.width,
                      sample.height,
                      vertical: widget.vertical,
                      sourceWidth: descriptor.width,
                      sourceHeight: descriptor.height,
                    );
            } finally {
              sample.dispose();
            }
            return DecodedReaderPage(result, colors);
          } catch (_) {
            result.dispose();
            rethrow;
          }
        } finally {
          descriptor?.dispose();
          buffer.dispose();
        }
      },
    );
    try {
      final result = await _lease!.future;
      if (!mounted) return;
      _image = result.image.clone();
      widget.onColors(result.colors);
      setState(() {});
    } catch (error) {
      if (mounted && error is! ReaderCancelled) setState(() => _error = error);
    }
  }

  @override
  void dispose() {
    _lease?.release();
    _image?.dispose();
    _transform.dispose();
    super.dispose();
  }

  PageTransform get _geometry => PageTransform(
    crop:
        Offset.zero & Size(_image!.width.toDouble(), _image!.height.toDouble()),
    viewport: _viewport,
    fit: widget.fit,
  );
  ReaderViewportState _snapshot() {
    final inverse = Matrix4.inverted(_transform.value);
    return ReaderViewportState(
      renderer: 'archive-image-v1',
      layout: widget.layoutKey,
      fit: widget.fit,
      viewport: _viewport,
      pageSize: _geometry.crop.size,
      scale: _transform.value.getMaxScaleOnAxis(),
      offset: Offset(
        _transform.value.entry(0, 3),
        _transform.value.entry(1, 3),
      ),
      focalPoint: _geometry.toPage(
        MatrixUtils.transformPoint(inverse, _viewport.center(Offset.zero)),
      ),
    );
  }

  void _install(double scale, Offset pan) {
    final zoom = scale.clamp(1.0, 5.0);
    final matrix = Matrix4.diagonal3Values(zoom, zoom, 1);
    matrix.setEntry(0, 3, pan.dx.clamp(_viewport.width * (1 - zoom), 0.0));
    matrix.setEntry(1, 3, pan.dy.clamp(_viewport.height * (1 - zoom), 0.0));
    _transform.value = matrix;
  }

  void _restore(ReaderViewportState? saved) {
    if (saved != null &&
        saved.compatible(
          renderer: 'archive-image-v1',
          layout: widget.layoutKey,
          fit: widget.fit,
          viewport: _viewport,
          pageSize: _geometry.crop.size,
        )) {
      _install(saved.scale, saved.offset);
    } else if (saved != null) {
      final point = _geometry.toViewport(saved.focalPoint);
      _install(
        saved.scale,
        _viewport.center(Offset.zero) - point * saved.scale,
      );
    } else {
      // Older locators use the top-left visible point, not a center anchor.
      final point = _geometry.toViewport(widget.initialPoint);
      _install(widget.initialZoom, -point * widget.initialZoom);
    }
  }

  void _settled() {
    if (_viewport.isEmpty) return;
    final origin = MatrixUtils.transformPoint(
      Matrix4.inverted(_transform.value),
      Offset.zero,
    );
    widget.onSettled?.call(
      _transform.value.getMaxScaleOnAxis(),
      _geometry.toPage(origin),
      _snapshot(),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null)
      return Center(child: Text('Page ${widget.page} could not open: $_error'));
    if (_image == null) return const Center(child: CircularProgressIndicator());
    final image = RawImage(
      image: _image,
      fit: widget.fit == 'fill'
          ? BoxFit.cover
          : widget.fit == 'fitWidth'
          ? BoxFit.fitWidth
          : BoxFit.contain,
    );
    if (widget.vertical) return image;
    return LayoutBuilder(
      builder: (context, box) {
        if (!_positionRestored || _viewport != box.biggest) {
          final saved = _positionRestored
              ? _snapshot()
              : widget.initialViewState;
          _viewport = box.biggest;
          _positionRestored = true;
          _restore(saved);
        }
        return GestureDetector(
          onDoubleTapDown: (details) => _tap = details.localPosition,
          onDoubleTap: () {
            final zoom = _transform.value.getMaxScaleOnAxis() > 1.05
                ? 1.0
                : 2.5;
            final matrix = Matrix4.identity();
            matrix.setEntry(0, 0, zoom);
            matrix.setEntry(1, 1, zoom);
            matrix.setEntry(0, 3, -_tap.dx * (zoom - 1));
            matrix.setEntry(1, 3, -_tap.dy * (zoom - 1));
            _transform.value = matrix;
            _settled();
          },
          child: InteractiveViewer(
            transformationController: _transform,
            minScale: 1,
            maxScale: 5,
            onInteractionEnd: (_) => _settled(),
            child: image,
          ),
        );
      },
    );
  }
}
