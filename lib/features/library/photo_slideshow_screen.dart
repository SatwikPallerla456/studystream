import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:math' as math;
import '../../domain/catalog/category_browse_repository.dart';
import '../../domain/catalog/collection_browse_repository.dart';
import '../../domain/catalog/media_catalog_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/db/app_database.dart';
import '../../data/providers/app_providers.dart';
import '../../shared/widgets/app_top_bar.dart';

class PhotoSlideshowScreen extends ConsumerStatefulWidget {
  const PhotoSlideshowScreen({
    super.key,
    this.libraryId,
    this.scope,
    this.initialItemId,
    this.collectionId,
    this.albumTitle,
  });
  final CategoryScope? scope;
  final String? initialItemId, collectionId, albumTitle;
  final String? libraryId;
  @override
  ConsumerState<PhotoSlideshowScreen> createState() => _PhotoSlideshowState();
}

class _PhotoSlideshowState extends ConsumerState<PhotoSlideshowScreen> {
  VoidCallback? _releaseProcessing;
  Item? _item;
  late String? _libraryId = widget.libraryId;
  ui.Image? _image;
  String? _error;
  bool _playing = false, _busy = false;
  Timer? _timer;
  HttpClient? _http;
  int _generation = 0;
  final _transform = TransformationController();
  Offset _tap = Offset.zero;
  Size _viewport = Size.zero;
  double get _zoom => _transform.value.getMaxScaleOnAxis();
  void _resetZoom() {
    _transform.value = Matrix4.identity();
    if (mounted) setState(() {});
  }

  void _zoomBy(double factor) {
    _pause();
    final scale = (_zoom * factor).clamp(1.0, 8.0), current = _zoom;
    final center = _viewport.center(Offset.zero);
    final matrix = Matrix4.diagonal3Values(scale, scale, 1);
    matrix.setEntry(
      0,
      3,
      (center.dx - (center.dx - _transform.value.entry(0, 3)) * scale / current)
          .clamp(_viewport.width * (1 - scale), 0.0),
    );
    matrix.setEntry(
      1,
      3,
      (center.dy - (center.dy - _transform.value.entry(1, 3)) * scale / current)
          .clamp(_viewport.height * (1 - scale), 0.0),
    );
    _transform.value = matrix;
    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _releaseProcessing = ref.read(libraryProcessingProvider).hold();
    _transform.addListener(_transformChanged);
    _next(true, first: true);
  }

  void _transformChanged() {
    if (_playing && _zoom > 1.05) _pause();
  }

  Future<void> _next(bool forward, {bool first = false}) async {
    if (_busy) return;
    setState(() => _busy = true);
    final generation = ++_generation;
    try {
      final db = ref.read(appDatabaseProvider), current = _item;
      final exact =
          first &&
              widget.initialItemId != null &&
              widget.scope == null &&
              widget.collectionId == null
          ? await db.getItemById(widget.initialItemId!)
          : null;
      _libraryId ??= exact?.libraryId;
      if (_libraryId == null) throw StateError('Photo library is unavailable');
      var item = widget.collectionId == null
          ? await CategoryBrowseRepository(db).photo(
              widget.scope ??
                  CategoryScope(
                    kind: LibraryKind.photos,
                    libraryId: _libraryId,
                  ),
              current: first ? null : current,
              forward: forward,
              initialId: first ? widget.initialItemId : null,
            )
          : await CollectionBrowseRepository(db).photo(
              widget.collectionId!,
              current: first ? null : current,
              forward: forward,
              initialId: first ? widget.initialItemId : null,
            );
      // Exact-file opening also works for images kept in a non-photo library;
      // subsequent navigation never invents a membership in the photo scope.
      if (item == null &&
          exact != null &&
          exact.itemType == 'image' &&
          !exact.unavailable &&
          exact.libraryId == _libraryId)
        item = exact;
      if (item == null) {
        _pause();
        if (current == null && mounted)
          setState(
            () => _error = widget.collectionId == null
                ? 'No available photos in this selection.'
                : 'No available photos in this album.',
          );
        else if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                forward
                    ? 'End of this photo selection.'
                    : 'Beginning of this photo selection.',
              ),
            ),
          );
        return;
      }
      Uint8List bytes;
      if (item.filePath.startsWith('remote:')) {
        final remote = await ref.read(lanSyncClientProvider).sourceFor(item);
        _http?.close(force: true);
        _http = HttpClient()..connectionTimeout = const Duration(seconds: 10);
        final request = await _http!.getUrl(remote.uri);
        request.followRedirects = false;
        remote.headers.forEach(request.headers.set);
        final response = await request.close().timeout(
          const Duration(seconds: 15),
        );
        if (response.statusCode != 200)
          throw StateError('The host could not supply this photo');
        final out = BytesBuilder(copy: false);
        await for (final chunk in response.timeout(
          const Duration(seconds: 15),
        )) {
          if (!mounted || generation != _generation)
            throw StateError('Photo request cancelled');
          if (out.length + chunk.length > 32 * 1024 * 1024)
            throw StateError('Photo exceeds 32 MiB');
          out.add(chunk);
        }
        bytes = out.takeBytes();
      } else {
        final file = File(item.filePath);
        if (await file.length() > 32 * 1024 * 1024)
          throw StateError('Photo exceeds 32 MiB');
        bytes = await file.readAsBytes();
      }
      final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
      ui.ImageDescriptor? descriptor;
      late ui.Image image;
      try {
        descriptor = await ui.ImageDescriptor.encoded(buffer);
        if (descriptor.width < 1 ||
            descriptor.height < 1 ||
            descriptor.width * descriptor.height > 80000000)
          throw const FormatException('Photo geometry exceeds limits');
        final scale = math.min(
          1.0,
          math.min(
            1920 / descriptor.width,
            math.sqrt(4 * 1024 * 1024 / (descriptor.width * descriptor.height)),
          ),
        );
        final codec = await descriptor.instantiateCodec(
          targetWidth: math.max(1, (descriptor.width * scale).round()),
          targetHeight: math.max(1, (descriptor.height * scale).round()),
        );
        try {
          image = (await codec.getNextFrame()).image;
        } finally {
          codec.dispose();
        }
      } finally {
        descriptor?.dispose();
        buffer.dispose();
      }
      if (mounted && generation == _generation) {
        final old = _image;
        setState(() {
          _item = item;
          _image = image;
          _error = null;
          _transform.value = Matrix4.identity();
        });
        old?.dispose();
      } else {
        image.dispose();
      }
    } catch (error) {
      _pause();
      if (mounted)
        setState(
          () => _error =
              'This photo could not be opened. Check its file and source availability.',
        );
    } finally {
      if (mounted)
        setState(() => _busy = false);
      else
        _busy = false;
    }
  }

  void _pause() {
    _timer?.cancel();
    if (mounted) setState(() => _playing = false);
  }

  void _toggle() {
    if (_item == null || _busy) return;
    if (_playing) {
      _pause();
      return;
    }
    _resetZoom();
    setState(() => _playing = true);
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _next(true));
  }

  @override
  void dispose() {
    _generation++;
    _releaseProcessing?.call();
    _timer?.cancel();
    _http?.close(force: true);
    _image?.dispose();
    _transform.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CallbackShortcuts(
    bindings: {
      const SingleActivator(LogicalKeyboardKey.arrowLeft): () => _next(false),
      const SingleActivator(LogicalKeyboardKey.arrowRight): () => _next(true),
      const SingleActivator(LogicalKeyboardKey.space): _toggle,
      const SingleActivator(LogicalKeyboardKey.equal): () => _zoomBy(1.5),
      const SingleActivator(LogicalKeyboardKey.equal, shift: true): () =>
          _zoomBy(1.5),
      const SingleActivator(LogicalKeyboardKey.minus): () => _zoomBy(1 / 1.5),
      const SingleActivator(LogicalKeyboardKey.digit0): _resetZoom,
    },
    child: Focus(
      autofocus: true,
      child: Scaffold(
        appBar: AppTopBar(
          title:
              widget.albumTitle ?? _item?.userTitle ?? _item?.title ?? 'Photos',
          showBack: true,
        ),
        backgroundColor: Colors.black,
        body: Column(
          children: [
            if (widget.albumTitle != null && _item != null)
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text(
                  _item!.userTitle ?? _item!.title,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            if (_busy) const LinearProgressIndicator(),
            Expanded(
              child: Center(
                child: _error != null
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _error!,
                            style: const TextStyle(color: Colors.white),
                          ),
                          TextButton(
                            onPressed: _busy
                                ? null
                                : () => _next(true, first: _item == null),
                            child: const Text('Retry photo'),
                          ),
                        ],
                      )
                    : _image == null
                    ? const CircularProgressIndicator()
                    : LayoutBuilder(
                        builder: (context, box) {
                          _viewport = box.biggest;
                          return GestureDetector(
                            onDoubleTapDown: (details) =>
                                _tap = details.localPosition,
                            onDoubleTap: () {
                              _pause();
                              final scale = _zoom > 1.05 ? 1.0 : 2.5;
                              final matrix = Matrix4.diagonal3Values(
                                scale,
                                scale,
                                1,
                              );
                              matrix.setEntry(0, 3, -_tap.dx * (scale - 1));
                              matrix.setEntry(1, 3, -_tap.dy * (scale - 1));
                              _transform.value = matrix;
                              setState(() {});
                            },
                            child: InteractiveViewer(
                              transformationController: _transform,
                              minScale: 1,
                              maxScale: 8,
                              onInteractionStart: (_) => _pause(),
                              onInteractionEnd: (_) => setState(() {}),
                              child: SizedBox.expand(
                                child: RawImage(
                                  image: _image,
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
        bottomNavigationBar: SafeArea(
          child: Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              IconButton(
                tooltip: 'Previous photo',
                onPressed: _busy ? null : () => _next(false),
                icon: const Icon(Icons.skip_previous),
              ),
              IconButton(
                tooltip: _playing
                    ? 'Pause slideshow'
                    : 'Start slideshow · 5 seconds',
                onPressed: _busy || _item == null ? null : _toggle,
                icon: Icon(_playing ? Icons.pause : Icons.play_arrow),
              ),
              IconButton(
                tooltip: 'Zoom out',
                onPressed: _image == null ? null : () => _zoomBy(1 / 1.5),
                icon: const Icon(Icons.zoom_out),
              ),
              TextButton(
                onPressed: _image == null ? null : _resetZoom,
                child: Text('${(_zoom * 100).round()}% · Reset'),
              ),
              IconButton(
                tooltip: 'Zoom in',
                onPressed: _image == null ? null : () => _zoomBy(1.5),
                icon: const Icon(Icons.zoom_in),
              ),
              IconButton(
                tooltip: 'Next photo',
                onPressed: _busy ? null : () => _next(true),
                icon: const Icon(Icons.skip_next),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
