import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:flutter_inappwebview_forge/flutter_inappwebview_forge.dart';
import 'package:uuid/uuid.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../data/reader/book_page_source.dart';
import '../../data/reader/reader_thumbnail_store.dart';
import '../../domain/reader/reader_jobs.dart';
import 'publication_view.dart';

Future<int?> showReaderPages({
  required BuildContext context,
  required BookPageSource source,
  required String revision,
  required ReaderJobScheduler jobs,
  required ReaderThumbnailStore store,
  required int currentPage,
  required bool rtl,
}) => showModalBottomSheet<int>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (context) => SizedBox(
    height: MediaQuery.sizeOf(context).height * .85,
    child: Column(
      children: [
        ListTile(
          title: Text(source.reflowable ? 'Section previews' : 'Pages'),
          subtitle: const Text(
            'Select a preview to jump. Numbers always follow the original reading order.',
          ),
          trailing: IconButton(
            tooltip: 'Close',
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close),
          ),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final columns = (constraints.maxWidth / 160).floor().clamp(2, 6);
              final row = (currentPage - 1) ~/ columns;
              final extent =
                  (constraints.maxWidth - 16 - (columns - 1) * 8) /
                      columns /
                      .63 +
                  8;
              return _ReaderPageGrid(
                source: source,
                revision: revision,
                jobs: jobs,
                store: store,
                currentPage: currentPage,
                rtl: rtl,
                columns: columns,
                initialOffset: row * extent,
              );
            },
          ),
        ),
      ],
    ),
  ),
);

class _ReaderPageGrid extends StatefulWidget {
  const _ReaderPageGrid({
    required this.source,
    required this.revision,
    required this.jobs,
    required this.store,
    required this.currentPage,
    required this.rtl,
    required this.columns,
    required this.initialOffset,
  });
  final BookPageSource source;
  final String revision;
  final ReaderJobScheduler jobs;
  final ReaderThumbnailStore store;
  final int currentPage, columns;
  final bool rtl;
  final double initialOffset;
  @override
  State<_ReaderPageGrid> createState() => _ReaderPageGridState();
}

class _ReaderPageGridState extends State<_ReaderPageGrid> {
  late final ScrollController _scroll = ScrollController(
    initialScrollOffset: widget.initialOffset,
  );
  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: widget.rtl ? TextDirection.rtl : TextDirection.ltr,
    child: GridView.builder(
      controller: _scroll,
      scrollCacheExtent: const ScrollCacheExtent.pixels(0),
      padding: const EdgeInsets.all(8),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: widget.columns,
        childAspectRatio: .63,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
      ),
      itemCount: widget.source.pageCount,
      itemBuilder: (context, index) => Card(
        color: index + 1 == widget.currentPage
            ? Theme.of(context).colorScheme.secondaryContainer
            : null,
        child: InkWell(
          onTap: () => Navigator.pop(context, index + 1),
          child: Column(
            children: [
              Expanded(
                child: _PageThumbnail(
                  key: ValueKey(index),
                  source: widget.source,
                  page: index + 1,
                  revision: widget.revision,
                  jobs: widget.jobs,
                  store: widget.store,
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(6),
                child: Text(
                  '${index + 1} · ${widget.source.titles[index]}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _PageThumbnail extends StatefulWidget {
  const _PageThumbnail({
    super.key,
    required this.source,
    required this.page,
    required this.revision,
    required this.jobs,
    required this.store,
  });
  final BookPageSource source;
  final int page;
  final String revision;
  final ReaderJobScheduler jobs;
  final ReaderThumbnailStore store;
  @override
  State<_PageThumbnail> createState() => _PageThumbnailState();
}

class _PageThumbnailState extends State<_PageThumbnail> {
  ReaderLease<Uint8List>? _lease;
  ui.Image? _image;
  String? _error;
  int _attempts = 0;
  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    _attempts++;
    _error = null;
    final key = widget.store.key(
      widget.source.locator(widget.page),
      'html-or-raster-320x480-v2',
    );
    final lease = widget.jobs.request<Uint8List>(
      key: 'thumbnail:$key',
      priority: ReaderPriority.thumbnail,
      estimatedBytes: 48 * 1024 * 1024,
      run: (token) async {
        final cached = await widget.store.read(key);
        token.check();
        if (cached != null) return cached;
        final bytes = widget.source.publicationPage(widget.page)
            ? await _publicationThumbnail(
                widget.source as ArchiveBookSource,
                widget.page,
                widget.revision,
                token,
              )
            : await _rasterThumbnail(widget.source, widget.page, token);
        token.check();
        await widget.store.write(key, bytes);
        return bytes;
      },
    );
    _lease = lease;
    try {
      final bytes = await lease.future;
      if (!mounted) return;
      final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
      ui.ImageDescriptor? descriptor;
      try {
        descriptor = await ui.ImageDescriptor.encoded(buffer);
        if (descriptor.width * descriptor.height > 4000000)
          throw const FormatException('Preview is too large');
        final codec = await descriptor.instantiateCodec(
          targetWidth: math.min(320, descriptor.width),
        );
        try {
          final image = (await codec.getNextFrame()).image;
          if (!mounted) {
            image.dispose();
            return;
          }
          _image = image;
        } finally {
          codec.dispose();
        }
      } finally {
        descriptor?.dispose();
        buffer.dispose();
      }
      if (mounted) setState(() {});
    } on ReaderCancelled {
      if (mounted) setState(() => _error = 'Preview paused');
    } catch (_) {
      if (mounted) setState(() => _error = 'Preview unavailable');
    } finally {
      lease.release();
      if (identical(_lease, lease)) _lease = null;
    }
  }

  @override
  void dispose() {
    _lease?.release();
    _image?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_image != null) return RawImage(image: _image, fit: BoxFit.contain);
    if (_error != null)
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.menu_book),
          Text(_error!),
          if (_attempts < 2)
            TextButton(
              onPressed: () {
                setState(() {});
                unawaited(_load());
              },
              child: const Text('Retry preview'),
            ),
        ],
      );
    return const Center(
      child: SizedBox.square(
        dimension: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    );
  }
}

Future<Uint8List> _rasterThumbnail(
  BookPageSource source,
  int page,
  ReaderCancellation token,
) async {
  final content = await source.load(page, cancellation: token);
  final bytes = content.image;
  if (bytes == null) throw const FormatException('No raster page');
  final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
  ui.ImageDescriptor? descriptor;
  try {
    descriptor = await ui.ImageDescriptor.encoded(buffer);
    if (descriptor.width * descriptor.height > 80000000)
      throw const FormatException('Page exceeds limits');
    final scale = math.min(
      1.0,
      math.min(320 / descriptor.width, 480 / descriptor.height),
    );
    final codec = await descriptor.instantiateCodec(
      targetWidth: math.max(1, (descriptor.width * scale).round()),
      targetHeight: math.max(1, (descriptor.height * scale).round()),
    );
    try {
      final image = (await codec.getNextFrame()).image;
      try {
        token.check();
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        if (data == null) throw StateError('Preview could not be encoded');
        return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
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

Future<Uint8List> _publicationThumbnail(
  ArchiveBookSource source,
  int page,
  String revision,
  ReaderCancellation token,
) async {
  final server = await source.publicationServer();
  token.check();
  final request = const Uuid().v4(), key = source.locator(page);
  final geometry = await source.geometry(page, cancellation: token);
  final uri = server.page(
    key,
    requestId: request,
    revision: revision,
    reflowable: source.reflowable,
    fontSize: 20,
    lineHeight: 1.6,
    fit: 'contain',
    width: geometry.width,
    height: geometry.height,
  );
  final ready = Completer<InAppWebViewController>();
  void fail(Object error) {
    if (!ready.isCompleted) ready.completeError(error);
  }

  token.onCancel(() => fail(const ReaderCancelled()));
  // Attach the error listener before native creation/cancellation can resolve it.
  final readiness = ready.future.timeout(const Duration(seconds: 15));
  final headless = HeadlessInAppWebView(
    initialSize: const Size(320, 480),
    initialSettings: publicationWebSettings(),
    initialUrlRequest: URLRequest(url: WebUri.uri(uri)),
    onWebViewCreated: (controller) {
      controller.addJavaScriptHandler(
        handlerName: 'TangerineReader',
        callback: (List<dynamic> args) {
          if (args.isEmpty ||
              args.first is! String ||
              (args.first as String).length > 32000)
            return null;
          try {
            final data = jsonDecode(args.first);
            if (data is! Map ||
                data['request'] != request ||
                data['revision'] != revision ||
                data['pageKey'] != key)
              return null;
            if (data['kind'] == 'error')
              fail(StateError('Publication preview failed'));
            if (data['kind'] == 'metrics' &&
                data['ready'] == true &&
                !ready.isCompleted)
              ready.complete(controller);
          } catch (_) {
            fail(const FormatException('Invalid preview readiness'));
          }
          return null;
        },
      );
    },
    onLoadStop: (controller, url) async {
      await controller.evaluateJavascript(
        source: 'window.tangerineMeasure && window.tangerineMeasure();',
      );
    },
    shouldOverrideUrlLoading: (controller, action) async {
      final target = Uri.tryParse(action.request.url?.toString() ?? '');
      return target != null &&
              server.contains(target) &&
              target.path == uri.path &&
              target.query == uri.query
          ? NavigationActionPolicy.ALLOW
          : NavigationActionPolicy.CANCEL;
    },
    onReceivedError: (controller, resource, error) {
      if (resource.isForMainFrame == true) fail(StateError(error.description));
    },
    onPermissionRequest: (controller, request) async => PermissionResponse(
      resources: request.resources,
      action: PermissionResponseAction.DENY,
    ),
    onCreateWindow: (controller, action) async => false,
  );
  // A single awaited lifetime keeps native rendering inside the scheduler lease.
  try {
    await Future.wait([
      headless.run(),
      readiness,
    ]).timeout(const Duration(seconds: 17));
    token.check();
    final controller = await readiness;
    final bytes = await controller
        .takeScreenshot(
          screenshotConfiguration: ScreenshotConfiguration(
            snapshotWidth: 320,
            compressFormat: CompressFormat.PNG,
            afterScreenUpdates: true,
          ),
        )
        .timeout(const Duration(seconds: 5));
    token.check();
    if (bytes == null || bytes.length > 2 * 1024 * 1024)
      throw StateError('Publication preview is unavailable');
    return bytes;
  } finally {
    await headless.dispose();
  }
}

/// Adapter borrows the viewer's document. Thumbnail leases never close it.
class PdfThumbnailSource implements BookPageSource {
  PdfThumbnailSource(this.document);
  final PdfDocument document;
  @override
  Set<ReaderCapability> get capabilities => {
    ReaderCapability.rasterRender,
    ReaderCapability.intrinsicGeometry,
  };
  @override
  bool get reflowable => false;
  @override
  bool get publication => false;
  @override
  bool publicationPage(int canonicalPage) => false;
  @override
  int get pageCount => document.pages.length;
  @override
  List<String> get titles => _titles;
  late final _titles = List.generate(pageCount, (i) => 'Page ${i + 1}');
  @override
  String locator(int canonicalPage) => 'pdf:$canonicalPage';
  @override
  Future<Size> geometry(
    int canonicalPage, {
    ReaderCancellation? cancellation,
  }) async {
    cancellation?.check();
    final page = document.pages[canonicalPage - 1];
    return Size(page.width, page.height);
  }

  @override
  Future<BookPage> load(
    int canonicalPage, {
    ReaderCancellation? cancellation,
  }) async {
    cancellation?.check();
    final page = document.pages[canonicalPage - 1];
    final scale = math.min(1.0, math.min(320 / page.width, 480 / page.height));
    final width = math.max(1, (page.width * scale).round()),
        height = math.max(1, (page.height * scale).round());
    final nativeCancellation = page.createCancellationToken();
    cancellation?.onCancel(nativeCancellation.cancel);
    final bitmap = await page.render(
      width: width,
      height: height,
      fullWidth: width.toDouble(),
      fullHeight: height.toDouble(),
      cancellationToken: nativeCancellation,
    );
    if (bitmap == null) throw const ReaderCancelled();
    try {
      cancellation?.check();
      final image = await bitmap.createImage();
      try {
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        cancellation?.check();
        if (data == null) throw StateError('PDF preview could not be encoded');
        return BookPage(
          image: data.buffer.asUint8List(
            data.offsetInBytes,
            data.lengthInBytes,
          ),
        );
      } finally {
        image.dispose();
      }
    } finally {
      bitmap.dispose();
    }
  }

  @override
  Future<void> dispose() async {}
}
