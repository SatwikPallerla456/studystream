import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:math' as math;
import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/db/app_database.dart';
import '../../data/providers/app_providers.dart';
import '../../shared/widgets/app_top_bar.dart';

class PhotoSlideshowScreen extends ConsumerStatefulWidget {
  const PhotoSlideshowScreen({super.key, required this.libraryId});
  final String libraryId;
  @override
  ConsumerState<PhotoSlideshowScreen> createState() => _PhotoSlideshowState();
}

class _PhotoSlideshowState extends ConsumerState<PhotoSlideshowScreen> {
  Item? _item;
  ui.Image? _image;
  String? _error;
  bool _playing = false, _busy = false;
  Timer? _timer;
  HttpClient? _http;
  int _generation = 0;
  @override
  void initState() {
    super.initState();
    _next(true, first: true);
  }

  Future<void> _next(bool forward, {bool first = false}) async {
    if (_busy) return;
    _busy = true;
    final generation = ++_generation;
    try {
      final db = ref.read(appDatabaseProvider), current = _item;
      final query = db.select(db.items)
        ..where(
          (i) =>
              i.libraryId.equals(widget.libraryId) &
              i.itemType.equals('image') &
              i.unavailable.not() &
              (first || current == null
                  ? const drift.Constant(true)
                  : forward
                  ? i.id.isBiggerThanValue(current.id)
                  : i.id.isSmallerThanValue(current.id)),
        )
        ..orderBy([
          (i) => forward
              ? drift.OrderingTerm.asc(i.id)
              : drift.OrderingTerm.desc(i.id),
        ])
        ..limit(1);
      final item = await query.getSingleOrNull();
      if (item == null) {
        _pause();
        if (current == null && mounted)
          setState(() => _error = 'No available photos in this library.');
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
      _busy = false;
    }
  }

  void _pause() {
    _timer?.cancel();
    if (mounted) setState(() => _playing = false);
  }

  void _toggle() {
    if (_playing) {
      _pause();
      return;
    }
    setState(() => _playing = true);
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _next(true));
  }

  @override
  void dispose() {
    _generation++;
    _timer?.cancel();
    _http?.close(force: true);
    _image?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CallbackShortcuts(
    bindings: {
      const SingleActivator(LogicalKeyboardKey.arrowLeft): () => _next(false),
      const SingleActivator(LogicalKeyboardKey.arrowRight): () => _next(true),
      const SingleActivator(LogicalKeyboardKey.space): _toggle,
    },
    child: Focus(
      autofocus: true,
      child: Scaffold(
        appBar: AppTopBar(
          title: _item?.userTitle ?? _item?.title ?? 'Slideshow',
          showBack: true,
        ),
        backgroundColor: Colors.black,
        body: Center(
          child: _error != null
              ? Text(_error!, style: const TextStyle(color: Colors.white))
              : _image == null
              ? const CircularProgressIndicator()
              : RawImage(image: _image, fit: BoxFit.contain),
        ),
        bottomNavigationBar: SafeArea(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                tooltip: 'Previous photo',
                onPressed: () => _next(false),
                icon: const Icon(Icons.skip_previous),
              ),
              IconButton(
                tooltip: _playing
                    ? 'Pause slideshow'
                    : 'Start slideshow · 5 seconds',
                onPressed: _toggle,
                icon: Icon(_playing ? Icons.pause : Icons.play_arrow),
              ),
              IconButton(
                tooltip: 'Next photo',
                onPressed: () => _next(true),
                icon: const Icon(Icons.skip_next),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
