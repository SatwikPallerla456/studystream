import 'dart:async';
import 'dart:io';
import 'dart:ui' show AppExitResponse, Offset, Size;

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/db/app_database.dart';
import '../../data/providers/app_providers.dart';
import '../../data/reader/book_page_source.dart';
import '../../data/reader/publication_content.dart';
import '../../data/reader/publication_server.dart';
import '../../data/reader/reader_thumbnail_store.dart';
import '../../data/reader/reader_image_analysis.dart';
import '../../domain/reader/reader_background.dart';
import '../../domain/reader/reader_contract.dart';
import '../../domain/reader/reader_study_destination.dart';
import '../../domain/catalog/catalog_identity_store.dart';
import '../../domain/reader/reader_jobs.dart';
import '../../domain/reader/reader_session_store.dart';
import '../../domain/services/progress_writer.dart';
import '../../shared/widgets/app_top_bar.dart';
import '../../shared/widgets/lesson_tools_sheet.dart';
import 'reader_image_page.dart';
import 'reader_text_analysis_sheet.dart';
import 'reader_background_surface.dart';
import 'publication_view.dart';
import 'publication_search_sheet.dart';
import 'reader_page_navigation.dart';
import 'reader_preferences_sheet.dart';

class BookReaderScreen extends ConsumerStatefulWidget {
  const BookReaderScreen({
    super.key,
    required this.itemId,
    this.initialPage,
    this.initialStudyAnchor,
  });
  final String itemId;
  final int? initialPage;
  final String? initialStudyAnchor;
  @override
  ConsumerState<BookReaderScreen> createState() => _BookReaderState();
}

class _BookReaderState extends ConsumerState<BookReaderScreen>
    with WidgetsBindingObserver {
  late final AppDatabase _db;
  Item? _item;
  BookPageSource? _source;
  BookPageSource? _pendingSource;
  ReaderSessionStore? _session;
  ReadingProgressWriter? _writer;
  final _jobs = ReaderJobScheduler();
  final _cancel = ReaderCancellation();
  final _publicationHandle = PublicationHandle();
  final _geometryKnown = <int>{}, _geometryPending = <int>{};
  final _pageCache = ReaderByteCache<DecodedReaderPage>(
    48 * 1024 * 1024,
    onEvict: (page) => page.image.dispose(),
    maxEntries: 8,
  );
  ReaderThumbnailStore? _thumbnails;
  final _scroll = ScrollController();
  final _pageSurface = GlobalKey();
  final _visited = <int>{};
  List<CanonicalPage> _pages = [];
  PresentationMap? _presentation;
  ContinuousPageLayout? _continuous;
  Map<String, dynamic> _options = resolveReaderSettings();
  final _colors = <int, ReaderEdgeColors>{};
  ReaderLocator? _restored;
  ReaderViewportState? _viewState;
  Directory? _temporary;
  HttpClient? _http;
  Timer? _settle;
  Future<void> _saveTail = Future.value();
  String? _error;
  String _revision = '';
  int _page = 1, _generation = 0;
  double _zoom = 1, _pointY = 0, _pointX = 0;
  String? _selectedText;
  int? _textOffset;
  String? _textQuote, _fragment;
  double _textBias = .2;
  ReaderTextAnchor? _selectedRange, _restoreSelection;
  bool _closing = false, _restoring = true, _chrome = true, _navigating = false;
  final _touches = <int>{};
  Offset? _swipeStart;
  int _swipeStartedAt = 0;
  bool _canSwipe = false;
  bool _allowPop = false, _leaving = false;
  bool _canTrackpad = false;
  Offset _trackpadPan = Offset.zero;
  double _wheelPan = 0;
  int _wheelLastAt = 0, _wheelTurnAt = 0;
  bool get _rtl => _options['rtl'] == true;
  bool get _reverse => _rtl && _mode != 'vertical';
  bool get _canTurnByGesture =>
      !_restoring &&
      !_navigating &&
      _zoom <= 1.05 &&
      _selectedRange == null &&
      _source != null &&
      !_source!.publicationPage(_page);
  String get _mode => _options['mode'] as String;
  String get _background => _options['background'] as String;
  void Function()? _releaseLibraryProcessing;
  @override
  void initState() {
    super.initState();
    _releaseLibraryProcessing = ref.read(libraryProcessingProvider).hold();
    _db = ref.read(appDatabaseProvider);
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  Future<void> _load() async {
    try {
      final item = await _db.getItemById(widget.itemId);
      if (item == null || item.unavailable)
        throw StateError(
          'The book is unavailable. Reconnect or relink its source.',
        );
      _item = item;
      _revision = await CatalogIdentityStore(_db).contentRevision(item);
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
            response.contentLength > 512 * 1024 * 1024)
          throw StateError(
            'The server could not supply this book (maximum 512 MiB).',
          );
        final sink = file.openWrite();
        var bytes = 0;
        try {
          await for (final chunk in response.timeout(
            const Duration(seconds: 30),
          )) {
            _cancel.check();
            bytes += chunk.length;
            if (bytes > 512 * 1024 * 1024)
              throw StateError('Book download exceeds 512 MiB');
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
      _pendingSource = source;
      if (_closing) {
        await source.dispose();
        return;
      }
      _session = ReaderSessionStore(_db, item);
      _options = await _session!.settings();
      final saved = await _db.getReadingByItemId(item.id);
      final locator = ReaderLocator.decode(_options['locator'] as String?);
      _restored = locator?.compatible(item.id, _revision) == true
          ? locator
          : null;
      _page = (widget.initialPage ?? _restored?.page ?? saved?.resumePage ?? 1)
          .clamp(1, source.pageCount);
      if (widget.initialPage == null && _restored != null) {
        for (var i = 1; i <= source.pageCount; i++) {
          if (source.locator(i) == _restored!.pageKey) _page = i;
        }
        _textOffset = _restored!.textOffset;
        _textQuote = _restored!.textQuote;
        _textBias = _restored!.textBias;
        _zoom = _restored!.zoom;
        _viewState = ReaderViewportState.decode(_restored!.viewState);
        _pointY = _restored!.point.dy;
        _pointX = _restored!.point.dx;
      }
      final study = await ReaderStudyDestination.load(
        _db,
        item,
        widget.initialStudyAnchor,
      );
      final passage = study?.passage, anchor = study?.locator;
      if (passage != null &&
          passage.compatible(item.id, _revision) &&
          passage.unit == 'domUtf16' &&
          passage.startPage == passage.endPage &&
          passage.startPage <= source.pageCount &&
          source.locator(passage.startPage) == passage.startKey &&
          source.publicationPage(passage.startPage)) {
        _page = passage.startPage;
        _restoreSelection = passage;
        _selectedRange = passage;
        _selectedText = passage.quote;
        _textOffset = passage.startOffset;
        _textQuote = passage.quote.substring(
          0,
          passage.quote.length.clamp(0, 120),
        );
        _pointX = 0;
        _pointY = 0;
        _zoom = 1;
        _viewState = null;
      } else if (anchor != null &&
          anchor.compatible(item.id, _revision) &&
          anchor.page <= source.pageCount &&
          source.locator(anchor.page) == anchor.pageKey) {
        _page = anchor.page;
        _textOffset = anchor.textOffset;
        _textQuote = anchor.textQuote;
        _textBias = anchor.textBias;
        _pointX = anchor.point.dx;
        _pointY = anchor.point.dy;
        _zoom = anchor.zoom;
        _viewState = ReaderViewportState.decode(anchor.viewState);
      } else if (study != null && mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted)
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'The saved passage belongs to an earlier revision. Its original reference is retained.',
                ),
              ),
            );
        });
      }
      // Canonical metadata is cheap; archive reads are restricted to the visible
      // neighborhood. Unknown pages retain explicit placeholder geometry.
      _pages = List.generate(
        source.pageCount,
        (i) =>
            CanonicalPage(i + 1, source.locator(i + 1), const Size(100, 200)),
      );
      for (final i in {
        _page,
        if (_page > 1) _page - 1,
        if (_page < source.pageCount) _page + 1,
      }) {
        _cancel.check();
        try {
          final size = await source.geometry(i, cancellation: _cancel);
          _pages[i - 1] = CanonicalPage(i, source.locator(i), size);
          _geometryKnown.add(i);
        } on ReaderCancelled {
          rethrow;
        } on Object {
          /* A corrupt neighbor must not block this book. */
        }
      }
      _cancel.check();
      _thumbnails = ReaderThumbnailStore('${item.id}:$_revision');
      _source = source;
      _pendingSource = null;
      _visited.add(_page);
      _writer = ReadingProgressWriter(database: _db, item: item)
        ..currentPage = _page
        ..totalPages = source.pageCount
        ..pagesVisited = 1
        ..zoom = _zoom
        ..readingMode = _mode;
      if (mounted) setState(() {});
    } catch (error) {
      if (mounted && error is! ReaderCancelled)
        setState(() => _error = error.toString());
    }
  }

  ReaderLocator _locator() => ReaderLocator(
    resourceId: _item!.id,
    revision: _revision,
    pageKey: _source!.locator(_page),
    page: _page,
    point: Offset(_pointX, _pointY),
    fit: _options['fit'] as String,
    zoom: _zoom,
    textOffset: _textOffset,
    textQuote: _textQuote,
    textBias: _textBias,
    viewState: _viewState?.toJson(),
  );
  Future<void> _save() async {
    await _publicationHandle.capture();
    if (_restoring || _item == null || _source == null) return _saveTail;
    final locator = _locator();
    final writer = _writer!
      ..currentPage = _page
      ..totalPages = _source!.pageCount
      ..pagesVisited = _visited.length
      ..zoom = _zoom
      ..readingMode = _mode;
    if (_scroll.hasClients) writer.scrollOffset = _scroll.offset;
    // Capture both before waiting; writes from rapid input cannot overtake.
    final progress = writer.save();
    final location = _session!.write(locator: locator);
    final write = Future.wait([progress, location]).then<void>((_) {});
    _saveTail = write.catchError((Object error) {
      if (mounted)
        setState(() => _error = 'Reading state could not be saved: $error');
    });
    return write;
  }

  void _schedule() {
    if (_restoring) return;
    _settle?.cancel();
    _settle = Timer(
      const Duration(milliseconds: 700),
      () => unawaited(_save()),
    );
  }

  Future<void> _go(int value) async {
    if (_source == null || _navigating) return;
    final next = value.clamp(1, _source!.pageCount);
    if (next == _page) return;
    _navigating = true;
    try {
      await _save();
      if (!mounted) return;
      setState(() {
        _page = next;
        _selectedText = null;
        _selectedRange = null;
        _restoreSelection = null;
        _textOffset = null;
        _textQuote = null;
        _textBias = .2;
        _fragment = null;
        _pointY = 0;
        _pointX = 0;
        _zoom = 1;
        _viewState = null;
        _visited.add(next);
        _generation++;
      });
      if (_mode == 'vertical' && _scroll.hasClients && _continuous != null) {
        _restoring = true;
        _scroll.jumpTo(
          _continuous!.offsets[next - 1].clamp(
            0,
            _scroll.position.maxScrollExtent,
          ),
        );
        _restoring = false;
      }
      await _save();
    } finally {
      _navigating = false;
    }
  }

  Future<void> _goToAnchor(ReaderLocator locator) async {
    if (!locator.compatible(_item!.id, _revision)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'This anchor belongs to an earlier content revision. Its original page reference has been preserved.',
          ),
        ),
      );
      return;
    }
    await _go(locator.page);
    if (!mounted) return;
    setState(() {
      _pointX = locator.point.dx;
      _pointY = locator.point.dy;
      _zoom = locator.zoom;
      _viewState = ReaderViewportState.decode(locator.viewState);
      _textOffset = locator.textOffset;
      _textQuote = locator.textQuote;
      _textBias = locator.textBias;
      _fragment = null;
      _restoreSelection = null;
      _selectedRange = null;
      _selectedText = null;
      _restoring = true;
      _generation++;
    });
  }

  Future<void> _goToTextAnchor(ReaderTextAnchor anchor) async {
    if (_source == null ||
        !anchor.compatible(_item!.id, _revision) ||
        anchor.unit != 'domUtf16' ||
        anchor.startPage != anchor.endPage ||
        anchor.startPage > _source!.pageCount ||
        anchor.startKey != _source!.locator(anchor.startPage) ||
        !_source!.publicationPage(anchor.startPage)) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'This passage cannot be restored in the current content revision. Its original reference is kept.',
            ),
          ),
        );
      return;
    }
    await _go(anchor.startPage);
    if (!mounted) return;
    setState(() {
      _restoreSelection = anchor;
      _selectedRange = anchor;
      _selectedText = anchor.quote;
      _textOffset = anchor.startOffset;
      _textQuote = anchor.quote.length <= 120
          ? anchor.quote
          : anchor.quote.substring(0, 120);
      _fragment = null;
      _generation++;
      _restoring = true;
    });
  }

  void _advance(bool forward) {
    if (!_canAdvance(forward)) return;
    unawaited(
      _go(_presentation?.advance(_page, forward) ?? _page + (forward ? 1 : -1)),
    );
  }

  Future<void> _setting(String key, Object value) async {
    await _save();
    if (!mounted) return;
    setState(() {
      _options = {..._options, key: value};
      _restoreSelection = null;
      _fragment = null;
      _generation++;
      _restoring = true;
    });
    await _session?.write(changes: {key: value});
  }

  Future<void> _pageTextTools() async {
    if (ReaderImageAnalysis.available) {
      await _recognizePage();
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Image text recognition'),
        content: Text(ReaderImageAnalysis.supportDescription),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  Future<void> _recognizePage() async {
    final source = _source, page = _page;
    if (source == null || source.publicationPage(page)) return;
    final text = await showReaderTextAnalysis(
      context: context,
      jobs: _jobs,
      pageKey: '$_revision:${source.locator(page)}',
      raster: (token) async {
        final content = await source.load(page, cancellation: token);
        token.check();
        if (content.image == null)
          throw const FormatException('This page has no raster image.');
        return ReaderImageAnalysis.raster(content.image!, token);
      },
    );
    if (!mounted || page != _page || text == null) return;
    _selectedText = text;
    // OCR supplies a page quote, not a stable DOM/native-text offset range.
    _selectedRange = null;
    _study();
  }

  Future<void> _study() async {
    await _save();
    if (!mounted) return;
    await showLessonToolsSheet(
      context: context,
      database: _db,
      item: _item!,
      currentPage: _page,
      anchor: _locator(),
      onJumpToAnchor: _goToAnchor,
      selectedText: _selectedText,
      textAnchor: _selectedRange,
      onJumpToTextAnchor: _goToTextAnchor,
      onJumpToPage: _go,
    );
  }

  void _tapAction(Offset point, Size viewport) {
    if (_restoring || _navigating || _zoom > 1.05 || _selectedRange != null)
      return;
    switch (ReaderTapPolicy.action(point, viewport, _options)) {
      case 'previous':
        _advance(false);
      case 'next':
        _advance(true);
      case 'toggleChrome':
        setState(() => _chrome = !_chrome);
      case 'study':
        _study();
    }
  }

  void _imageTap(TapUpDetails details) {
    final surface = _pageSurface.currentContext?.findRenderObject();
    if (surface is RenderBox)
      _tapAction(surface.globalToLocal(details.globalPosition), surface.size);
  }

  bool _canAdvance(bool forward) {
    if (_source == null) return false;
    final map = _presentation;
    if (map == null) return forward ? _page < _source!.pageCount : _page > 1;
    final cell = map.cellFor(_page);
    return forward ? cell < map.cells.length - 1 : cell > 0;
  }

  void _horizontalTurn(Offset delta, double width) {
    if (!_canTurnByGesture ||
        delta.dx.abs() < (width * .15).clamp(48, 180) ||
        delta.dy.abs() > delta.dx.abs() * .5)
      return;
    _advance(_reverse ? delta.dx > 0 : delta.dx < 0);
  }

  void _pointerScroll(PointerSignalEvent event) {
    if (event is! PointerScrollEvent ||
        !_canTurnByGesture ||
        HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isMetaPressed ||
        event.scrollDelta.dx.abs() <= event.scrollDelta.dy.abs() * 2)
      return;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _wheelTurnAt < 350) return;
    final delta = -event.scrollDelta.dx;
    if (now - _wheelLastAt > 250 || _wheelPan.sign != delta.sign) _wheelPan = 0;
    _wheelLastAt = now;
    _wheelPan += delta;
    if (_wheelPan.abs() < 48) return;
    _wheelTurnAt = now;
    _advance(_reverse ? _wheelPan > 0 : _wheelPan < 0);
    _wheelPan = 0;
  }

  Future<void> _settings() async {
    if (_session == null || _item == null) return;
    await _save();
    if (!mounted) return;
    await showReaderPreferences(
      context: context,
      database: _db,
      libraryId: _item!.libraryId,
      item: _item,
      currentPage: _page,
      typography: _source?.reflowable == true,
      onChanged: () async {
        await _save();
        final resolved = await _session!.settings();
        if (mounted)
          setState(() {
            _options = resolved;
            _restoreSelection = null;
            _fragment = null;
            _generation++;
            _restoring = true;
          });
      },
    );
  }

  Future<void> _contents() async {
    final source = _source;
    if (source is ArchiveBookSource && source.contents.isNotEmpty) {
      final destination = await showModalBottomSheet<PublicationDestination>(
        context: context,
        useSafeArea: true,
        builder: (context) => Column(
          children: [
            ListTile(
              title: const Text('Contents'),
              trailing: IconButton(
                tooltip: 'Close contents',
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: source.contents.length,
                itemBuilder: (context, index) {
                  final entry = source.contents[index];
                  return ListTile(
                    contentPadding: EdgeInsets.only(
                      left: 16 + entry.depth * 16.0,
                      right: 16,
                    ),
                    title: Text(entry.title),
                    trailing: Text('${entry.page}'),
                    selected: entry.page == _page,
                    onTap: () => Navigator.pop(context, entry),
                  );
                },
              ),
            ),
          ],
        ),
      );
      if (destination != null && mounted)
        await _destination(destination.page, destination.fragment);
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      builder: (context) => ListView.builder(
        itemCount: _source!.pageCount,
        itemBuilder: (context, index) => ListTile(
          leading: Text('${index + 1}'),
          title: Text(_source!.titles[index]),
          selected: index + 1 == _page,
          onTap: () {
            Navigator.pop(context);
            _go(index + 1);
          },
          trailing: PopupMenuButton<String>(
            tooltip: 'Pairing for this page',
            onSelected: (value) async {
              final key = value == 'single' ? 'singlePages' : 'pairingStarts';
              final pages = List<int>.from(_options[key] as List? ?? []);
              pages.contains(index + 1)
                  ? pages.remove(index + 1)
                  : pages.add(index + 1);
              await _setting(key, pages);
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'single', child: Text('Toggle single page')),
              PopupMenuItem(value: 'pair', child: Text('Toggle pairing start')),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _destination(int page, String fragment) async {
    await _save();
    await _go(page);
    if (!mounted) return;
    setState(() {
      _fragment = fragment;
      _restoreSelection = null;
      _selectedRange = null;
      _selectedText = null;
      _textOffset = null;
      _textQuote = null;
      _pointY = 0;
      _restoring = true;
      _generation++;
    });
  }

  Future<void> _publicationLink(int page, String href) async {
    final source = _source;
    if (source is! ArchiveBookSource) return;
    try {
      final uri = Uri.parse(href);
      if (uri.hasScheme || uri.hasAuthority)
        throw const FormatException('External link');
      final path = uri.path.isEmpty
          ? source.locator(page)
          : PublicationServer.resolve(source.locator(page), href);
      final index = source.paths.indexOf(path);
      if (index < 0)
        throw const FormatException(
          'Destination is outside this reading order',
        );
      await _destination(index + 1, uri.fragment);
    } on FormatException {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'This link has no readable destination in this book.',
            ),
          ),
        );
    }
  }

  Future<void> _searchBook() async {
    final source = _source;
    if (source is! ArchiveBookSource) return;
    await _save();
    if (!mounted) return;
    final hit = await showPublicationSearch(
      context: context,
      source: source,
      revision: _revision,
      jobs: _jobs,
    );
    if (hit == null || !mounted) return;
    await _goToTextAnchor(
      ReaderTextAnchor(
        resourceId: _item!.id,
        revision: _revision,
        startKey: source.locator(hit.page),
        endKey: source.locator(hit.page),
        startPage: hit.page,
        endPage: hit.page,
        startOffset: hit.start,
        endOffset: hit.end,
        unit: 'domUtf16',
        quote: hit.quote,
      ),
    );
  }

  Future<void> _pageBrowser() async {
    if (_source == null || _thumbnails == null) return;
    await _save();
    if (!mounted) return;
    final page = await showReaderPages(
      context: context,
      source: _source!,
      revision: _revision,
      jobs: _jobs,
      store: _thumbnails!,
      currentPage: _page,
      rtl: _reverse,
    );
    if (page != null && mounted) await _go(page);
  }

  void _ensureGeometry(int page) {
    if (_geometryKnown.contains(page) ||
        !_geometryPending.add(page) ||
        _closing)
      return;
    final source = _source!;
    final lease = _jobs.request<Size>(
      key: 'geometry:$_revision:${source.locator(page)}',
      priority: ReaderPriority.geometry,
      estimatedBytes: 16 * 1024 * 1024,
      run: (token) => source.geometry(page, cancellation: token),
    );
    unawaited(
      lease.future
          .then((size) => _receivedGeometry(page, size))
          .catchError((Object _) {
            // Keep fallback geometry for this session; malformed neighbors never block readiness.
            _geometryKnown.add(page);
          })
          .whenComplete(() {
            _geometryPending.remove(page);
            lease.release();
          }),
    );
  }

  void _receivedGeometry(int page, Size size) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          _closing ||
          size.isEmpty ||
          !size.width.isFinite ||
          !size.height.isFinite)
        return;
      _geometryKnown.add(page);
      if ((_pages[page - 1].size.width - size.width).abs() < .5 &&
          (_pages[page - 1].size.height - size.height).abs() < .5)
        return;
      setState(() {
        _pages[page - 1] = CanonicalPage(page, _source!.locator(page), size);
        // Recompute continuous offsets around the same canonical page/fraction.
        if (_mode == 'vertical' && !_source!.reflowable) _restoring = true;
      });
    });
  }

  void _receivedColors(int page, ReaderEdgeColors colors) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _colors[page] = colors;
          while (_colors.length > 8) {
            _colors.remove(_colors.keys.first);
          }
        });
      }
    });
  }

  Widget _pageWidget(int page, double width, {bool vertical = false}) {
    _ensureGeometry(page);
    if (_source!.publicationPage(page) && _source is ArchiveBookSource) {
      return PublicationView(
        key: ValueKey('publication:$page:$_generation'),
        source: _source! as ArchiveBookSource,
        jobs: _jobs,
        handle: page == _page ? _publicationHandle : null,
        initialTextOffset: page == _page ? _textOffset : null,
        initialTextQuote: page == _page ? _textQuote : null,
        initialTextBias: _textBias,
        fragment: page == _page ? _fragment : null,
        onChooseSection: _contents,
        onLink: (href) => unawaited(_publicationLink(page, href)),
        onGeometry: (size) => _receivedGeometry(page, size),
        onTextPosition: (offset, quote, bias) {
          if (page != _page) return;
          if (_textOffset == offset &&
              _textQuote == quote &&
              (_textBias - bias).abs() < .005)
            return;
          _textOffset = offset;
          _textQuote = quote;
          _textBias = bias;
          _fragment = null;
          _schedule();
        },
        page: page,
        revision: _revision,
        geometry: _pages[page - 1].size,
        fit: _options['fit'] as String,
        fontSize: (_options['fontSize'] as num).toDouble(),
        lineHeight: (_options['lineHeight'] as num).toDouble(),
        initialY: page == _page ? _pointY : 0,
        initialSelection: page == _page ? _restoreSelection : null,
        onTap: (point) => _tapAction(point, const Size(1, 1)),
        onPosition: (x, y) {
          if (page != _page || vertical) return;
          if ((_pointX - x).abs() < .0001 && (_pointY - y).abs() < .0001)
            return;
          _pointX = x;
          _pointY = y;
          _schedule();
        },
        onSelection: (text, offset, end) {
          if (text.isEmpty && page != _page) return;
          if (text.isNotEmpty && page != _page)
            setState(() {
              _page = page;
              _visited.add(page);
            });
          _restoreSelection = null;
          _selectedText = text.isEmpty ? null : text;
          _selectedRange = text.isEmpty
              ? null
              : ReaderTextAnchor(
                  resourceId: _item!.id,
                  revision: _revision,
                  startKey: _source!.locator(page),
                  startPage: page,
                  startOffset: offset,
                  endKey: _source!.locator(page),
                  endPage: page,
                  endOffset: end,
                  unit: 'domUtf16',
                  quote: text,
                );
        },
      );
    }
    return ReaderImagePage(
      key: ValueKey('$page:$_generation:${width.round()}:$vertical'),
      source: _source!,
      page: page,
      revision: _revision,
      jobs: _jobs,
      cache: _pageCache,
      onGeometry: (size) => _receivedGeometry(page, size),
      fit: _options['fit'] as String,
      targetWidth: (width * MediaQuery.devicePixelRatioOf(context)).ceil(),
      vertical: vertical,
      layoutKey:
          '$_mode:$_rtl:${_presentation?.pagesFor(page).join(',') ?? page}',
      onTapUp: _imageTap,
      initialViewState: page == _page ? _viewState : null,
      initialZoom: page == _page ? _zoom : 1,
      initialPoint: page == _page ? Offset(_pointX, _pointY) : Offset.zero,
      onColors: (colors) => _receivedColors(page, colors),
      onSettled: (zoom, point, state) {
        _viewState = state;
        _page = page;
        _zoom = zoom;
        _pointX = point.dx;
        _pointY = point.dy;
        _schedule();
      },
    );
  }

  Widget _body() => LayoutBuilder(
    builder: (context, box) {
      final continuous = _mode == 'vertical' && !_source!.reflowable;
      _presentation = PresentationMap(
        _pages,
        spreads:
            _mode == 'spread' && box.maxWidth > 700 && !_source!.reflowable,
        coverSingle: _options['coverSingle'] == true,
        singlePages: Set<int>.from(_options['singlePages'] as List? ?? []),
        pairingStarts: Set<int>.from(_options['pairingStarts'] as List? ?? []),
      );
      final cell = _presentation!.pagesFor(_page);
      final first = _colors[_rtl && !continuous ? cell.last : cell.first],
          last = _colors[_rtl && !continuous ? cell.first : cell.last];
      final a = switch (_background) {
        'white' => Colors.white,
        'color' => first?.combined ?? Colors.black,
        'immersive' => first?.first ?? Colors.black,
        _ => Colors.black,
      };
      final b = _background == 'immersive' ? (last?.second ?? a) : a;
      Widget content;
      if (continuous) {
        _continuous = ContinuousPageLayout(_pages, box.maxWidth);
        content = NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            if (notification is ScrollUpdateNotification && !_restoring) {
              final page = _continuous!.pageAt(notification.metrics.pixels);
              final start = _continuous!.offsets[page - 1],
                  height = _continuous!.offsets[page] - start;
              setState(() {
                _page = page;
                _viewState = null;
                _pointY = ((notification.metrics.pixels - start) / height)
                    .clamp(0, 1);
                _visited.add(page);
              });
              _schedule();
            }
            return false;
          },
          child: ListView.builder(
            controller: _scroll,
            itemCount: _pages.length,
            scrollCacheExtent: const ScrollCacheExtent.pixels(0),
            itemExtentBuilder: (index, dimensions) =>
                _continuous!.offsets[index + 1] - _continuous!.offsets[index],
            itemBuilder: (context, index) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _pageWidget(index + 1, box.maxWidth, vertical: true),
            ),
          ),
        );
      } else {
        content = GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTapUp: (details) => _tapAction(details.localPosition, box.biggest),
          child: Listener(
            key: _pageSurface,
            behavior: HitTestBehavior.opaque,
            onPointerSignal: _pointerScroll,
            onPointerPanZoomStart: (_) {
              _trackpadPan = Offset.zero;
              _canTrackpad = _canTurnByGesture;
            },
            onPointerPanZoomUpdate: (event) {
              _trackpadPan = event.pan;
              if ((event.scale - 1).abs() > .02 || event.rotation.abs() > .02)
                _canTrackpad = false;
            },
            onPointerPanZoomEnd: (_) {
              if (_canTrackpad) _horizontalTurn(_trackpadPan, box.maxWidth);
              _canTrackpad = false;
            },
            onPointerDown: (event) {
              _touches.add(event.pointer);
              if (_touches.length == 1) {
                _swipeStart = event.localPosition;
                _swipeStartedAt = DateTime.now().millisecondsSinceEpoch;
                _canSwipe = _canTurnByGesture;
              } else {
                _canSwipe = false;
              }
            },
            onPointerCancel: (event) {
              _touches.remove(event.pointer);
              _canSwipe = false;
            },
            onPointerUp: (event) {
              _touches.remove(event.pointer);
              final start = _swipeStart;
              if (_touches.isNotEmpty ||
                  !_canSwipe ||
                  start == null ||
                  _zoom > 1.05)
                return;
              _canSwipe = false;
              final delta = event.localPosition - start;
              if (DateTime.now().millisecondsSinceEpoch - _swipeStartedAt >
                  1000)
                return;
              _horizontalTurn(delta, box.maxWidth);
            },
            child: Row(
              textDirection: _rtl ? TextDirection.rtl : TextDirection.ltr,
              children: [
                for (final page in cell)
                  Expanded(
                    child: _pageWidget(page, box.maxWidth / cell.length),
                  ),
              ],
            ),
          ),
        );
      }
      if (_restoring)
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          if (continuous && _scroll.hasClients) {
            final layout = _continuous!;
            _scroll.jumpTo(
              (layout.offsets[_page - 1] +
                      _pointY *
                          (layout.offsets[_page] - layout.offsets[_page - 1]))
                  .clamp(0, _scroll.position.maxScrollExtent),
            );
          }
          _restoring = false;
        });
      return Stack(
        children: [
          Positioned.fill(
            child: ReaderBackgroundSurface(
              first: a,
              second: b,
              vertical: continuous,
            ),
          ),
          Positioned.fill(child: content),
        ],
      );
    },
  );
  Future<void> _leave({bool home = false}) async {
    if (_leaving) return;
    _leaving = true;
    try {
      await _save();
      await _session?.flushed;
      if (!mounted) return;
      if (home || !context.canPop()) {
        context.go('/?tab=home');
        return;
      }
      setState(() => _allowPop = true);
      await WidgetsBinding.instance.endOfFrame;
      if (mounted) context.pop();
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'The reading position could not be saved. Please try again.',
            ),
          ),
        );
    } finally {
      _leaving = false;
    }
  }

  @override
  Future<AppExitResponse> didRequestAppExit() async {
    await _save();
    await _session?.flushed;
    return AppExitResponse.exit;
  }

  @override
  void didHaveMemoryPressure() {
    _jobs.releaseSpeculative();
    _colors.clear();
    _pageCache.clear();
    _thumbnails?.clearMemory();
    if (_source case final ArchiveBookSource source)
      source.clearRegenerableCaches();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) unawaited(_save());
  }

  @override
  void dispose() {
    _releaseLibraryProcessing?.call();
    _closing = true;
    _cancel.cancel();
    _settle?.cancel();
    _http?.close(force: true);
    WidgetsBinding.instance.removeObserver(this);
    final save = _save();
    _jobs.dispose();
    _pageCache.clear();
    _thumbnails?.dispose();
    unawaited(
      save.catchError((Object _) {}).whenComplete(() async {
        await _writer?.dispose();
        await _session?.flushed;
        await _jobs.settled;
        await _source?.dispose();
        await _pendingSource?.dispose();
        await _temporary?.delete(recursive: true);
      }),
    );
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: _allowPop,
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop) unawaited(_leave());
    },
    child: CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.arrowLeft): () =>
            _advance(_reverse),
        const SingleActivator(LogicalKeyboardKey.arrowRight): () =>
            _advance(!_reverse),
        const SingleActivator(LogicalKeyboardKey.pageDown): () =>
            _advance(true),
        const SingleActivator(LogicalKeyboardKey.pageUp): () => _advance(false),
        const SingleActivator(LogicalKeyboardKey.home): () => _go(1),
        const SingleActivator(LogicalKeyboardKey.end): () =>
            _go(_source?.pageCount ?? 1),
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          appBar: _chrome
              ? AppTopBar(
                  title: _item?.userTitle ?? _item?.title ?? 'Reader',
                  showBack: true,
                  onBack: () => unawaited(_leave()),
                  onHome: () => unawaited(_leave(home: true)),
                  actions: [
                    if (_source != null) ...[
                      IconButton(
                        tooltip: 'Contents / pages',
                        onPressed: _contents,
                        icon: const Icon(Icons.view_list),
                      ),
                      if (MediaQuery.sizeOf(context).width >= 700) ...[
                        IconButton(
                          tooltip: 'Page thumbnails',
                          onPressed: _pageBrowser,
                          icon: const Icon(Icons.grid_view),
                        ),
                        if (_source!.capabilities.contains(
                          ReaderCapability.textSearch,
                        ))
                          IconButton(
                            tooltip: 'Search book text',
                            onPressed: _searchBook,
                            icon: const Icon(Icons.search),
                          ),
                        IconButton(
                          tooltip: 'Reading preferences',
                          onPressed: _settings,
                          icon: const Icon(Icons.tune),
                        ),
                        if (!_source!.publicationPage(_page))
                          IconButton(
                            tooltip: ReaderImageAnalysis.available
                                ? 'Recognize page text'
                                : 'OCR availability',
                            onPressed: _pageTextTools,
                            icon: const Icon(Icons.document_scanner_outlined),
                          ),
                      ],
                      IconButton(
                        tooltip: 'Notes and bookmarks',
                        onPressed: _study,
                        icon: const Icon(Icons.bookmark_outline),
                      ),
                      if (MediaQuery.sizeOf(context).width < 700)
                        PopupMenuButton<String>(
                          tooltip: 'Reader tools',
                          onSelected: (value) {
                            switch (value) {
                              case 'pages':
                                unawaited(_pageBrowser());
                              case 'search':
                                unawaited(_searchBook());
                              case 'settings':
                                unawaited(_settings());
                              case 'ocr':
                                unawaited(_pageTextTools());
                            }
                          },
                          itemBuilder: (_) => [
                            const PopupMenuItem(
                              value: 'pages',
                              child: Text('Page thumbnails'),
                            ),
                            if (_source!.capabilities.contains(
                              ReaderCapability.textSearch,
                            ))
                              const PopupMenuItem(
                                value: 'search',
                                child: Text('Search book text'),
                              ),
                            const PopupMenuItem(
                              value: 'settings',
                              child: Text('Reading preferences'),
                            ),
                            if (!_source!.publicationPage(_page))
                              PopupMenuItem(
                                value: 'ocr',
                                child: Text(
                                  ReaderImageAnalysis.available
                                      ? 'Image text recognition'
                                      : 'OCR availability',
                                ),
                              ),
                          ],
                        ),
                    ],
                  ],
                )
              : null,
          body: _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!),
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Back'),
                        ),
                      ],
                    ),
                  ),
                )
              : _source == null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(),
                      const Text('Opening your book…'),
                    ],
                  ),
                )
              : _body(),
          bottomNavigationBar: _source == null || !_chrome
              ? null
              : SafeArea(
                  child: Directionality(
                    textDirection: _reverse
                        ? TextDirection.rtl
                        : TextDirection.ltr,
                    child: Row(
                      children: [
                        IconButton(
                          tooltip: _source!.reflowable
                              ? 'Previous chapter'
                              : 'Previous page',
                          onPressed: _canAdvance(false)
                              ? () => _advance(false)
                              : null,
                          icon: Icon(
                            _reverse ? Icons.skip_next : Icons.skip_previous,
                          ),
                        ),
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${_source!.reflowable ? 'Chapter' : 'Page'} $_page / ${_source!.pageCount}',
                              ),
                              Slider(
                                value: _page.toDouble(),
                                min: 1,
                                max: _source!.pageCount > 1
                                    ? _source!.pageCount.toDouble()
                                    : 2,
                                onChanged: _source!.pageCount < 2
                                    ? null
                                    : (value) => _go(value.round()),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: _source!.reflowable
                              ? 'Next chapter'
                              : 'Next page',
                          onPressed: _canAdvance(true)
                              ? () => _advance(true)
                              : null,
                          icon: Icon(
                            _reverse ? Icons.skip_previous : Icons.skip_next,
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
