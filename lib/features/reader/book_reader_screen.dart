import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:flutter/services.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/db/app_database.dart';
import '../../data/providers/app_providers.dart';
import '../../data/reader/book_page_source.dart';
import '../../domain/catalog/media_catalog_repository.dart';
import '../../domain/services/progress_writer.dart';
import '../../shared/widgets/app_top_bar.dart';
import '../../shared/widgets/lesson_tools_sheet.dart';

class _RenderedPage {
  const _RenderedPage(this.page, this.left, this.right, this.wide);
  final BookPage page;
  final Color left, right;
  final bool wide;
}

class BookReaderScreen extends ConsumerStatefulWidget {
  const BookReaderScreen({super.key, required this.itemId, this.initialPage});
  final String itemId;
  final int? initialPage;
  @override
  ConsumerState<BookReaderScreen> createState() => _BookReaderState();
}

class _BookReaderState extends ConsumerState<BookReaderScreen>
    with WidgetsBindingObserver {
  late final AppDatabase _db;
  late final MediaCatalogRepository _catalog;
  Item? _item;
  BookPageSource? _source;
  ReadingProgressWriter? _writer;
  Directory? _temporary;
  HttpClient? _http;
  String? _error;
  int _page = 1, _generation = 0;
  bool _rtl = false;
  String _mode = 'horizontal', _background = 'black', _fit = 'contain';
  double _fontSize = 20, _lineHeight = 1.6, _restoredScroll = 0;
  final _scroll = ScrollController();
  final _visited = <int>{};
  final _cache = <int, Future<_RenderedPage>>{};
  Timer? _saveTimer;
  bool _closing = false;
  @override
  void initState() {
    super.initState();
    _db = ref.read(appDatabaseProvider);
    _catalog = MediaCatalogRepository(_db);
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  Future<void> _load() async {
    try {
      final item = await _db.getItemById(widget.itemId);
      if (item == null || item.unavailable) {
        throw StateError('The book is missing. Relink it in the library.');
      }
      _item = item;
      var path = item.filePath;
      if (path.startsWith('remote:')) {
        final remote = await ref.read(lanSyncClientProvider).sourceFor(item);
        _temporary = await Directory.systemTemp.createTemp('tangerine-reader-');
        final file = File('${_temporary!.path}/book');
        _http = HttpClient()..connectionTimeout = const Duration(seconds: 20);
        final request = await _http!.getUrl(remote.uri);
        request.followRedirects = false;
        remote.headers.forEach(request.headers.set);
        final response = await request.close().timeout(
          const Duration(seconds: 30),
        );
        if (response.statusCode != 200 ||
            response.contentLength > 512 * 1024 * 1024) {
          throw StateError(
            'The server could not supply this book (maximum 512 MiB).',
          );
        }
        final sink = file.openWrite();
        var bytes = 0;
        try {
          await for (final chunk in response.timeout(
            const Duration(seconds: 30),
          )) {
            bytes += chunk.length;
            if (bytes > 512 * 1024 * 1024 || _closing) {
              throw StateError('Book download stopped');
            }
            sink.add(chunk);
          }
        } finally {
          await sink.close();
        }
        path = file.path;
      }
      final source = await ArchiveBookSource.open(
        path,
        epub: item.itemType == 'epub',
      );
      if (_closing) {
        await source.dispose();
        return;
      }
      _source = source;
      final saved = await _db.getReadingByItemId(item.id);
      final defaults =
          (await _catalog.record('library:${item.libraryId}'))?.data ?? {};
      final options =
          (await _catalog.record('reader:${item.id}'))?.data ?? defaults;
      _rtl = options['rtl'] == true;
      _mode = options['mode'] as String? ?? 'horizontal';
      _background = options['background'] as String? ?? 'black';
      _fit = options['fit'] as String? ?? 'contain';
      _fontSize = (options['fontSize'] as num?)?.toDouble().clamp(12, 36) ?? 20;
      _lineHeight =
          (options['lineHeight'] as num?)?.toDouble().clamp(1.2, 2.4) ?? 1.6;
      _page = (widget.initialPage ?? saved?.resumePage ?? 1).clamp(
        1,
        source.pageCount,
      );
      // Spine resource is a stable chapter locator even when font sizing changes.
      if (widget.initialPage == null && options['locator'] is String) {
        for (var i = 1; i <= source.pageCount; i++) {
          if (source.locator(i) == options['locator']) _page = i;
        }
      }
      _restoredScroll = widget.initialPage == null
          ? saved?.resumeScrollOffset ?? 0
          : 0;
      _visited.add(_page);
      _writer = ReadingProgressWriter(database: _db, item: item)
        ..currentPage = _page
        ..totalPages = source.pageCount
        ..pagesVisited = _visited.length
        ..zoom = saved?.zoom ?? 1
        ..readingMode = _mode;
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Future<_RenderedPage> _render(int page) {
    final existing = _cache[page];
    if (existing != null) return existing;
    // Four compressed/rendered page resources maximum, independent of book length.
    while (_cache.length >= 4) {
      _cache.remove(_cache.keys.first);
    }
    return _cache[page] = _readPage(page);
  }

  Future<_RenderedPage> _readPage(int page) async {
    final data = await _source!.load(page);
    if (data.image == null) {
      return _RenderedPage(
        data,
        const Color(0xffe8dfd0),
        const Color(0xffd4c7ae),
        false,
      );
    }
    final buffer = await ui.ImmutableBuffer.fromUint8List(data.image!);
    ui.ImageDescriptor? descriptor;
    try {
      descriptor = await ui.ImageDescriptor.encoded(buffer);
      if (descriptor.width <= 0 ||
          descriptor.height <= 0 ||
          descriptor.width * descriptor.height > 80000000 ||
          descriptor.width > 24000 ||
          descriptor.height > 24000) {
        throw const FormatException('Page exceeds the image size limit');
      }
      final codec = await descriptor.instantiateCodec(
        targetWidth: 32,
        targetHeight: 32,
      );
      final frame = await codec.getNextFrame();
      codec.dispose();
      try {
        final pixels = await frame.image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        );
        Color color(bool left) {
          if (pixels == null) return const Color(0xff222222);
          var r = 0, g = 0, b = 0, n = 0;
          for (var y = 0; y < 32; y++)
            for (var x = left ? 0 : 24; x < (left ? 8 : 32); x++) {
              final i = (y * 32 + x) * 4;
              if (pixels.getUint8(i + 3) < 128) continue;
              r += pixels.getUint8(i);
              g += pixels.getUint8(i + 1);
              b += pixels.getUint8(i + 2);
              n++;
            }
          return n == 0
              ? const Color(0xff222222)
              : Color.fromARGB(255, r ~/ n, g ~/ n, b ~/ n);
        }

        return _RenderedPage(
          data,
          color(true),
          color(false),
          descriptor.width > descriptor.height * 1.25,
        );
      } finally {
        frame.image.dispose();
      }
    } finally {
      descriptor?.dispose();
      buffer.dispose();
    }
  }

  Map<String, dynamic> _options() => {
    'rtl': _rtl,
    'mode': _mode,
    'background': _background,
    'fit': _fit,
    'fontSize': _fontSize,
    'lineHeight': _lineHeight,
    'locator': _source?.locator(_page),
  };
  Future<void> _save() async {
    final item = _item, source = _source;
    if (item == null || source == null) return;
    _writer
      ?..currentPage = _page
      ..totalPages = source.pageCount
      ..pagesVisited = _visited.length
      ..readingMode = _mode;
    if (_scroll.hasClients) _writer?.scrollOffset = _scroll.offset;
    await _writer?.save();
    await _catalog.save(
      'reader:${item.id}',
      'reader',
      item.libraryId,
      _options(),
      itemId: item.id,
    );
  }

  Future<void> _go(int value) async {
    if (_source == null) return;
    final next = value.clamp(1, _source!.pageCount);
    if (next == _page) return;
    await _save();
    if (!mounted) return;
    setState(() {
      _page = next;
      _generation++;
      _visited.add(next);
      _restoredScroll = 0;
    });
    if (_scroll.hasClients) _scroll.jumpTo(0);
    unawaited(_save());
  }

  void _advance(bool forward) => unawaited(_go(_page + (forward ? 1 : -1)));
  void _change(VoidCallback mutate) {
    setState(mutate);
    unawaited(_save());
  }

  Future<void> _settings() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModal) => SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Reading preferences'),
                  SwitchListTile(
                    title: const Text('Right to left'),
                    subtitle: const Text(
                      'Left advances in horizontal mode. Canonical page numbers stay the same.',
                    ),
                    value: _rtl,
                    onChanged: (v) {
                      _change(() => _rtl = v);
                      setModal(() {});
                    },
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: _mode,
                    decoration: const InputDecoration(
                      labelText: 'Reading mode',
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'horizontal',
                        child: Text('Single page / chapter'),
                      ),
                      DropdownMenuItem(
                        value: 'spread',
                        child: Text('Two page spreads'),
                      ),
                      DropdownMenuItem(
                        value: 'vertical',
                        child: Text('Continuous vertical'),
                      ),
                    ],
                    onChanged: (v) {
                      _change(() => _mode = v!);
                      setModal(() {});
                    },
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: _background,
                    decoration: const InputDecoration(labelText: 'Background'),
                    items: ['black', 'white', 'color', 'immersive']
                        .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                        .toList(),
                    onChanged: (v) {
                      _change(() => _background = v!);
                      setModal(() {});
                    },
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: _fit,
                    decoration: const InputDecoration(labelText: 'Page fit'),
                    items: const [
                      DropdownMenuItem(
                        value: 'contain',
                        child: Text('Fit page'),
                      ),
                      DropdownMenuItem(
                        value: 'fitWidth',
                        child: Text('Fit width'),
                      ),
                    ],
                    onChanged: (v) {
                      _change(() => _fit = v!);
                      setModal(() {});
                    },
                  ),
                  if (_source?.reflowable == true) ...[
                    Text('Text size: ${_fontSize.round()}'),
                    Slider(
                      value: _fontSize,
                      min: 12,
                      max: 36,
                      onChanged: (v) {
                        _change(() => _fontSize = v);
                        setModal(() {});
                      },
                    ),
                    Text('Line spacing: ${_lineHeight.toStringAsFixed(1)}'),
                    Slider(
                      value: _lineHeight,
                      min: 1.2,
                      max: 2.4,
                      onChanged: (v) {
                        _change(() => _lineHeight = v);
                        setModal(() {});
                      },
                    ),
                  ],
                  TextButton(
                    onPressed: () async {
                      final item = _item!;
                      final old =
                          (await _catalog.record(
                            'library:${item.libraryId}',
                          ))?.data ??
                          {};
                      await _catalog.save(
                        'library:${item.libraryId}',
                        'library',
                        item.libraryId,
                        {...old, ..._options()..remove('locator')},
                      );
                      if (context.mounted) Navigator.pop(context);
                    },
                    child: const Text('Use these defaults for this library'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Done'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _contents() async {
    final source = _source!;
    await showModalBottomSheet<void>(
      context: context,
      builder: (context) => Directionality(
        textDirection: _rtl ? TextDirection.rtl : TextDirection.ltr,
        child: ListView.builder(
          itemCount: source.pageCount,
          itemBuilder: (context, index) => ListTile(
            title: Text(source.titles[index]),
            leading: Text('${index + 1}'),
            selected: _page == index + 1,
            onTap: () {
              Navigator.pop(context);
              _go(index + 1);
            },
          ),
        ),
      ),
    );
  }

  Widget _pageView(int page, {bool vertical = false}) =>
      FutureBuilder<_RenderedPage>(
        future: _render(page),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Page $page could not open: ${snapshot.error}'),
              ),
            );
          }
          final rendered = snapshot.data;
          if (rendered == null) {
            return const Center(child: CircularProgressIndicator());
          }
          final image = rendered.page.image;
          if (image == null) {
            return SingleChildScrollView(
              key: ValueKey('text:$page:$_generation'),
              controller: vertical ? null : _scroll,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Html(
                  data: rendered.page.html,
                  style: {
                    'body': Style(
                      fontSize: FontSize(_fontSize),
                      lineHeight: LineHeight(_lineHeight),
                      color: _background == 'black'
                          ? Colors.white
                          : Colors.black,
                    ),
                  },
                ),
              ),
            );
          }
          return InteractiveViewer(
            minScale: 1,
            maxScale: 5,
            child: Image.memory(
              image,
              cacheWidth: 1600,
              fit: _fit == 'fitWidth' ? BoxFit.fitWidth : BoxFit.contain,
              gaplessPlayback: true,
              errorBuilder: (_, e, st) => Text('Unsupported page image: $e'),
            ),
          );
        },
      );
  Widget _readingBody() => FutureBuilder<_RenderedPage>(
    future: _render(_page),
    builder: (context, snapshot) {
      final current = snapshot.data;
      final left = switch (_background) {
        'white' => Colors.white,
        'color' => current?.left ?? Colors.black,
        'immersive' => current?.left ?? Colors.black,
        _ => Colors.black,
      };
      final right = _background == 'immersive'
          ? (current?.right ?? left)
          : left;
      final child = _mode == 'vertical' && !(_source?.reflowable ?? false)
          ? LayoutBuilder(
              builder: (context, box) =>
                  NotificationListener<ScrollNotification>(
                    onNotification: (n) {
                      if (n is ScrollUpdateNotification) {
                        final page =
                            (n.metrics.pixels / box.maxHeight).floor() + 1;
                        if (page != _page) {
                          setState(
                            () => _page = page.clamp(1, _source!.pageCount),
                          );
                          _visited.add(_page);
                        }
                        _saveTimer?.cancel();
                        _saveTimer = Timer(
                          const Duration(milliseconds: 700),
                          () => unawaited(_save()),
                        );
                      }
                      return false;
                    },
                    child: ListView.builder(
                      controller: _scroll,
                      itemExtent: box.maxHeight,
                      scrollCacheExtent: const ScrollCacheExtent.pixels(0),
                      itemCount: _source!.pageCount,
                      itemBuilder: (_, i) => _pageView(i + 1, vertical: true),
                    ),
                  ),
            )
          : LayoutBuilder(
              builder: (context, box) {
                final spread =
                    _mode == 'spread' &&
                    !_source!.reflowable &&
                    box.maxWidth > 700 &&
                    _page > 1 &&
                    _page < _source!.pageCount &&
                    current?.wide == false;
                final pages = [
                  Expanded(child: _pageView(_page)),
                  if (spread) Expanded(child: _pageView(_page + 1)),
                ];
                return GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onHorizontalDragEnd: (d) {
                    if ((d.primaryVelocity ?? 0).abs() > 100) {
                      _advance(
                        _rtl
                            ? (d.primaryVelocity! > 0)
                            : (d.primaryVelocity! < 0),
                      );
                    }
                  },
                  onTapUp: (d) {
                    if (d.localPosition.dx < box.maxWidth * .18) {
                      _advance(_rtl);
                    } else if (d.localPosition.dx > box.maxWidth * .82)
                      _advance(!_rtl);
                  },
                  child: Row(
                    textDirection: _rtl ? TextDirection.rtl : TextDirection.ltr,
                    children: pages,
                  ),
                );
              },
            );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (_restoredScroll > 0 && _scroll.hasClients) {
          final offset = _mode == 'vertical' && !_source!.reflowable
              ? (_page - 1) * MediaQuery.sizeOf(context).height
              : _restoredScroll;
          _scroll.jumpTo(offset.clamp(0, _scroll.position.maxScrollExtent));
          _restoredScroll = 0;
        }
      });
      return AnimatedContainer(
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [left, right]),
        ),
        child: child,
      );
    },
  );
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) unawaited(_save());
  }

  @override
  void dispose() {
    _closing = true;
    WidgetsBinding.instance.removeObserver(this);
    _saveTimer?.cancel();
    _http?.close(force: true);
    unawaited(
      _save().whenComplete(() async {
        await _writer?.dispose();
        await _source?.dispose();
        await _temporary?.delete(recursive: true);
      }),
    );
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CallbackShortcuts(
    bindings: {
      const SingleActivator(LogicalKeyboardKey.arrowLeft): () => _advance(_rtl),
      const SingleActivator(LogicalKeyboardKey.arrowRight): () =>
          _advance(!_rtl),
      const SingleActivator(LogicalKeyboardKey.pageDown): () => _advance(true),
      const SingleActivator(LogicalKeyboardKey.pageUp): () => _advance(false),
    },
    child: Focus(
      autofocus: true,
      child: Scaffold(
        appBar: AppTopBar(
          title: _item?.userTitle ?? _item?.title ?? 'Reader',
          showBack: true,
          actions: [
            if (_source != null) ...[
              IconButton(
                tooltip: 'Contents / pages',
                onPressed: _contents,
                icon: const Icon(Icons.view_list),
              ),
              IconButton(
                tooltip: 'Reading preferences',
                onPressed: _settings,
                icon: const Icon(Icons.tune),
              ),
              IconButton(
                tooltip: 'Notes and bookmarks',
                onPressed: () => showLessonToolsSheet(
                  context: context,
                  database: _db,
                  item: _item!,
                  currentPage: _page,
                ),
                icon: const Icon(Icons.bookmark_outline),
              ),
            ],
          ],
        ),
        body: _error != null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(_error!),
                ),
              )
            : _source == null
            ? const Center(child: CircularProgressIndicator())
            : _readingBody(),
        bottomNavigationBar: _source == null
            ? null
            : SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Row(
                    children: [
                      IconButton(
                        tooltip: _rtl
                            ? 'Next canonical page'
                            : 'Previous canonical page',
                        onPressed: () => _advance(_rtl),
                        icon: const Icon(Icons.chevron_left),
                      ),
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${_source!.reflowable ? 'Chapter' : 'Page'} $_page / ${_source!.pageCount} · ${_rtl ? 'Right to left' : 'Left to right'}',
                            ),
                            Slider(
                              value: _page.toDouble(),
                              min: 1,
                              max: _source!.pageCount > 1
                                  ? _source!.pageCount.toDouble()
                                  : 2,
                              secondaryTrackValue: null,
                              onChanged: _source!.pageCount < 2
                                  ? null
                                  : (v) => _go(v.round()),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: _rtl
                            ? 'Previous canonical page'
                            : 'Next canonical page',
                        onPressed: () => _advance(!_rtl),
                        icon: const Icon(Icons.chevron_right),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    ),
  );
}
