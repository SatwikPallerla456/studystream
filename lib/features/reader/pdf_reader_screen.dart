import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'dart:ui' show AppExitResponse;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/display_utils.dart';
import '../../data/db/app_database.dart';
import '../../data/reader/reader_image_analysis.dart';
import '../../data/reader/reader_thumbnail_store.dart';
import '../../data/providers/app_providers.dart';
import '../../data/sync/lan_sync_client.dart';
import '../../domain/services/progress_writer.dart';
import '../../domain/reader/reader_contract.dart';
import '../../domain/reader/reader_study_destination.dart';
import '../../domain/catalog/catalog_identity_store.dart';
import '../../domain/reader/reader_session_store.dart';
import '../../domain/reader/reader_background.dart';
import '../../domain/reader/reader_jobs.dart';
import '../../shared/widgets/app_top_bar.dart';
import '../../shared/widgets/content_state.dart';
import '../../shared/widgets/lesson_tools_sheet.dart';
import '../../shared/widgets/study_ui.dart';
import 'reader_preferences_sheet.dart';
import 'reader_text_analysis_sheet.dart';
import 'reader_background_surface.dart';
import 'reader_page_navigation.dart';

class PdfReaderScreen extends ConsumerStatefulWidget {
  const PdfReaderScreen({
    super.key,
    required this.itemId,
    this.initialPage,
    this.initialStudyAnchor,
  });

  final String itemId;
  final int? initialPage;
  final String? initialStudyAnchor;

  @override
  ConsumerState<PdfReaderScreen> createState() => _PdfReaderScreenState();
}

class _PdfReaderScreenState extends ConsumerState<PdfReaderScreen>
    with WidgetsBindingObserver {
  late final AppDatabase _database;
  final _controller = PdfViewerController();
  final _searchController = TextEditingController();
  final _visitedPages = <int>{};
  Item? _item;
  ReadingProgressWriter? _writer;
  ReaderSessionStore? _session;
  ReaderLocator? _locator;
  String _revision = '';
  String _fitMode = 'fitWidth';
  String _layoutMode = 'vertical', _background = 'black';
  bool _rtl = false;
  Map<String, dynamic> _readerOptions = {};
  PresentationMap? _presentation;
  Size _viewport = const Size(900, 700);
  ReaderEdgeColors? _edgeColors;
  final _sampleJobs = ReaderJobScheduler();
  ReaderLease<ReaderEdgeColors>? _sampleLease;
  ReaderThumbnailStore? _thumbnails;
  String? _selectedText;
  ReaderTextAnchor? _selectionRange;
  int _selectionGeneration = 0;
  PdfTextSearcher? _searcher;
  Timer? _saveTimer;
  String? _filePath;
  RemoteMediaSource? _remoteSource;
  bool _restoring = true;
  double _savedZoom = 1;
  double _savedOffset = 0;
  String? _error;
  int _currentPage = 1;
  int _totalPages = 0;
  bool _searchVisible = false;
  bool _ready = false;
  bool _focusMode = false;
  bool _interacting = false;

  void Function()? _releaseLibraryProcessing;
  @override
  void initState() {
    super.initState();
    _releaseLibraryProcessing = ref.read(libraryProcessingProvider).hold();
    WidgetsBinding.instance.addObserver(this);
    _database = ref.read(appDatabaseProvider);
    _controller.addListener(_viewChanged);
    _load();
  }

  Future<void> _load() async {
    try {
      final item = await _database.getItemById(widget.itemId);
      if (item == null) throw StateError('This document no longer exists.');
      _item = item;
      final remote = item.filePath.startsWith('remote:');
      if (item.unavailable ||
          (!remote && !await File(item.filePath).exists())) {
        throw StateError(
          'This PDF is missing. Rescan or relink it from the library.',
        );
      }
      if (remote) {
        _remoteSource = await ref.read(lanSyncClientProvider).sourceFor(item);
      }
      _revision = await CatalogIdentityStore(_database).contentRevision(item);
      _thumbnails = ReaderThumbnailStore('${item.id}:$_revision');
      _session = ReaderSessionStore(_database, item);
      final settings = await _session!.settings();
      _readerOptions = settings;
      _layoutMode = settings['mode'] as String? ?? 'vertical';
      _rtl = settings['rtl'] == true;
      _background = settings['background'] as String? ?? 'black';
      _fitMode = settings['fit'] as String? ?? 'fitWidth';
      final restored = ReaderLocator.decode(settings['locator'] as String?);
      _locator = restored?.compatible(item.id, _revision) == true
          ? restored
          : null;
      final saved = await _database.getReadingByItemId(item.id);
      final preferences = await ref
          .read(appPreferencesRepositoryProvider)
          .load();
      _currentPage =
          widget.initialPage ?? _locator?.page ?? saved?.resumePage ?? 1;
      _savedZoom = _locator?.zoom ?? saved?.zoom ?? 1;
      _savedOffset = widget.initialPage == null
          ? saved?.resumeScrollOffset ?? 0
          : 0;
      if (!mounted) return;
      _visitedPages.add(_currentPage);
      _filePath = item.filePath;
      _writer =
          ReadingProgressWriter(
              database: _database,
              item: item,
              completionThreshold: preferences.completionThreshold,
            )
            ..currentPage = _currentPage
            ..scrollOffset = saved?.resumeScrollOffset ?? 0
            ..pagesVisited = (saved?.percentRead ?? 0) > 0 ? 2 : 1
            ..zoom = saved?.zoom ?? 1
            ..readingMode = saved?.readingMode ?? 'fitWidth';
      if (mounted) setState(() {});
    } catch (error) {
      if (!mounted) return;
      final message = error.toString().toLowerCase();
      setState(
        () => _error =
            message.contains('missing') || message.contains('no longer exists')
            ? 'The PDF file is missing or has moved. Relink it from the library to keep your saved reading progress.'
            : 'Tangerine could not open this PDF. The file may be damaged, inaccessible, or unsupported.',
      );
    }
  }

  void _viewerReady(PdfDocument document, PdfViewerController controller) {
    _totalPages = document.pages.length;
    final writer = _writer;
    if (writer != null) {
      writer
        ..totalPages = _totalPages
        ..pagesVisited = _visitedPages.length;
    }
    _searcher ??= PdfTextSearcher(controller)..addListener(_searchChanged);
    _ready = true;
    Future.microtask(() async {
      if (!mounted) return;
      _currentPage = _currentPage.clamp(1, _totalPages);
      await controller.goToPage(
        pageNumber: _currentPage,
        duration: Duration.zero,
      );
      if (!mounted) return;
      final locator = widget.initialPage == null ? _locator : null;
      if (locator != null) {
        await _restoreLocator(locator);
      } else {
        await controller.goToPosition(
          documentOffset: Offset(
            controller.visibleRect.left,
            _savedOffset > 0 ? _savedOffset : controller.visibleRect.top,
          ),
          zoom: _savedZoom,
          duration: Duration.zero,
        );
      }
      if (mounted) {
        _restoring = false;
        if (widget.initialStudyAnchor != null && _item != null) {
          final study = await ReaderStudyDestination.load(
            _database,
            _item!,
            widget.initialStudyAnchor,
          );
          if (!mounted) return;
          if (study?.passage != null)
            await _goToTextAnchor(study!.passage!);
          else if (study?.locator != null)
            await _goToAnchor(study!.locator!);
        }
        if (!mounted) return;
        _sampleBackground();
        setState(() {});
      }
    });
  }

  void _viewChanged() {
    if (!_ready || _restoring || !_controller.isReady) return;
    _saveTimer?.cancel();
    _saveTimer = Timer(
      const Duration(milliseconds: 700),
      () => unawaited(_saveProgress()),
    );
  }

  Future<void> _fit(bool width) async {
    if (!_ready) return;
    _fitMode = width ? 'fitWidth' : 'contain';
    _readerOptions['fit'] = _fitMode;
    _writer?.readingMode = _fitMode;
    await _session?.write(changes: {'fit': _fitMode});
    await _controller.goToPage(
      pageNumber: _currentPage,
      anchor: width ? PdfPageAnchor.top : PdfPageAnchor.all,
      duration: AppMotion.resolve(context, AppMotion.standard),
    );
    await _saveProgress();
  }

  void _searchChanged() {
    if (mounted) setState(() {});
  }

  void _pageChanged(int? page) {
    if (!mounted || _restoring || page == null || page == _currentPage) return;
    if (_presentation != null &&
        _presentation!.cellFor(page) == _presentation!.cellFor(_currentPage))
      return;
    setState(() => _currentPage = page);
    _visitedPages.add(page);
    _sampleBackground();
    final writer = _writer;
    if (writer != null) {
      writer
        ..currentPage = page
        ..pagesVisited = _visitedPages.length
        ..zoom = _controller.currentZoom;
    }
    _saveTimer?.cancel();
    _saveTimer = Timer(
      const Duration(milliseconds: 700),
      () => unawaited(_saveProgress()),
    );
  }

  PageTransform _pageTransform(int number) {
    final page = _controller.document.pages[number - 1];
    final rotation = page.rotation.index * 90;
    final size = Size(page.width, page.height);
    final original = rotation == 90 || rotation == 270
        ? Size(size.height, size.width)
        : size;
    // pdfrx exposes already cropped page dimensions. This origin is the public
    // cropped page's origin; PDF media-box coordinates remain a distinct space.
    return PageTransform(
      crop: Offset.zero & original,
      viewport: _controller.layout.pageLayouts[number - 1].size,
      rotation: rotation,
    );
  }

  String get _viewportLayout =>
      '$_layoutMode:$_rtl:$_totalPages:${sha256.convert(utf8.encode(jsonEncode([_readerOptions['coverSingle'], _readerOptions['singlePages'], _readerOptions['pairingStarts']])))}';

  Future<void> _restoreLocator(ReaderLocator locator) async {
    final number = locator.page.clamp(1, _totalPages);
    final rect = _controller.layout.pageLayouts[number - 1];
    final saved = ReaderViewportState.decode(locator.viewState);
    if (saved != null &&
        saved.compatible(
          renderer: 'pdfrx-v1',
          layout: _viewportLayout,
          fit: _fitMode,
          viewport: _viewport,
          pageSize: rect.size,
        )) {
      await _controller.goToPosition(
        documentOffset: saved.offset,
        zoom: saved.scale,
        duration: Duration.zero,
      );
    } else {
      final point = _pageTransform(number).toViewport(locator.point);
      final base = _controller
          .calcMatrixForPage(pageNumber: number)
          .getMaxScaleOnAxis();
      await _controller.goToPosition(
        documentOffset: rect.topLeft + point,
        zoom: base * locator.zoom,
        duration: Duration.zero,
      );
    }
  }

  ReaderLocator? _captureLocator() {
    if (!_controller.isReady || _item == null || _totalPages == 0) return null;
    final rect = _controller.layout.pageLayouts[_currentPage - 1];
    final point = _pageTransform(
      _currentPage,
    ).toPage(_controller.visibleRect.topLeft - rect.topLeft);
    final base = _controller
        .calcMatrixForPage(pageNumber: _currentPage)
        .getMaxScaleOnAxis();
    return ReaderLocator(
      resourceId: _item!.id,
      revision: _revision,
      pageKey: 'pdf:$_currentPage',
      page: _currentPage,
      point: point,
      fit: _fitMode,
      zoom: (_controller.currentZoom / base).clamp(1, 5),
      viewState: ReaderViewportState(
        renderer: 'pdfrx-v1',
        layout: _viewportLayout,
        fit: _fitMode,
        viewport: _viewport,
        pageSize: rect.size,
        scale: _controller.currentZoom,
        offset: _controller.visibleRect.topLeft,
        focalPoint: _pageTransform(
          _currentPage,
        ).toPage(_controller.visibleRect.center - rect.topLeft),
      ).toJson(),
    );
  }

  Future<void> _saveProgress() async {
    final writer = _writer;
    if (writer == null || !_ready || _restoring || !_controller.isReady) return;
    writer
      ..zoom = _controller.currentZoom
      ..scrollOffset = _controller.visibleRect.top;
    final locator = _captureLocator();
    await writer.save();
    if (locator != null) await _session?.write(locator: locator);
  }

  Future<void> _jumpToPage([int? requested]) async {
    var page = requested;
    if (page == null) {
      final text = TextEditingController(text: '$_currentPage');
      final value = await showStudyAdaptiveModal<int>(
        context: context,
        disposeOnClose: [text],
        builder: (modalContext) => StudyModalFrame(
          title: 'Go to page',
          icon: Icons.find_in_page_outlined,
          primaryAction: FilledButton(
            onPressed: () =>
                Navigator.pop(modalContext, int.tryParse(text.text)),
            child: const Text('Go to page'),
          ),
          secondaryAction: TextButton(
            onPressed: () => Navigator.pop(modalContext),
            child: const Text('Cancel'),
          ),
          child: TextField(
            controller: text,
            autofocus: true,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Page number',
              suffixText: 'of $_totalPages',
            ),
            onSubmitted: (value) =>
                Navigator.pop(modalContext, int.tryParse(value)),
          ),
        ),
      );

      page = value;
    }
    if (page == null || !_ready) return;
    _currentPage = page.clamp(1, _totalPages);
    await _controller.goToPage(pageNumber: _currentPage);
    _sampleBackground();
  }

  void _advanceCell(bool forward) {
    final page =
        _presentation?.advance(_currentPage, forward) ??
        (_currentPage + (forward ? 1 : -1)).clamp(1, _totalPages);
    unawaited(_jumpToPage(page));
  }

  PdfPageLayout _layoutPdf(List<PdfPage> pages, PdfViewerParams params) {
    final canonical = [
      for (final page in pages)
        CanonicalPage(
          page.pageNumber,
          'pdf:${page.pageNumber}',
          Size(page.width, page.height),
        ),
    ];
    _presentation = PresentationMap(
      canonical,
      spreads: _layoutMode == 'spread' && _viewport.width > 700,
      coverSingle: _readerOptions['coverSingle'] != false,
      singlePages: Set<int>.from(_readerOptions['singlePages'] as List? ?? []),
      pairingStarts: Set<int>.from(
        _readerOptions['pairingStarts'] as List? ?? [],
      ),
    );
    final rects = List<Rect>.filled(pages.length, Rect.zero),
        margin = params.margin;
    if (_layoutMode == 'vertical') {
      final width =
          pages.fold<double>(0, (width, page) => math.max(width, page.width)) +
          margin * 2;
      var y = margin;
      for (final page in pages) {
        rects[page.pageNumber - 1] = Rect.fromLTWH(
          (width - page.width) / 2,
          y,
          page.width,
          page.height,
        );
        y += page.height + margin;
      }
      return PdfPageLayout(pageLayouts: rects, documentSize: Size(width, y));
    }
    final cellWidth = _viewport.width, cellHeight = _viewport.height;
    for (var index = 0; index < _presentation!.cells.length; index++) {
      final cell = _presentation!.cells[index],
          slotWidth = (cellWidth - margin * 2) / cell.length;
      for (var slot = 0; slot < cell.length; slot++) {
        final page = pages[cell[slot] - 1];
        final scale = math.min(
          (slotWidth - margin) / page.width,
          (cellHeight - margin * 2) / page.height,
        );
        final width = page.width * scale, height = page.height * scale;
        final visual = _rtl ? cell.length - 1 - slot : slot;
        final cellIndex = _rtl
            ? _presentation!.cells.length - 1 - index
            : index;
        rects[page.pageNumber - 1] = Rect.fromLTWH(
          cellIndex * cellWidth +
              margin +
              visual * slotWidth +
              (slotWidth - width) / 2,
          (cellHeight - height) / 2,
          width,
          height,
        );
      }
    }
    return PdfPageLayout(
      pageLayouts: rects,
      documentSize: Size(cellWidth * _presentation!.cells.length, cellHeight),
    );
  }

  bool _readerTap(
    BuildContext context,
    PdfViewerController controller,
    PdfViewerGeneralTapHandlerDetails details,
  ) {
    // Native text and link handling run first; selection never turns a page.
    if (!_ready ||
        _restoring ||
        _interacting ||
        details.tapOn != PdfViewerPart.background ||
        controller.textSelectionDelegate.hasSelectedText)
      return false;
    final base = controller
        .calcMatrixForPage(pageNumber: _currentPage)
        .getMaxScaleOnAxis();
    final relative = controller.currentZoom / base;
    if (details.type == PdfViewerGeneralTapType.doubleTap) {
      unawaited(
        controller.zoomOnLocalPosition(
          localPosition: details.localPosition,
          newZoom: base * (relative > 1.05 ? 1 : 2.5),
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 200),
        ),
      );
      return true;
    }
    if (details.type != PdfViewerGeneralTapType.tap || relative > 1.05)
      return false;
    switch (ReaderTapPolicy.action(
      details.localPosition,
      _viewport,
      _readerOptions,
    )) {
      case 'previous':
        _advanceCell(false);
      case 'next':
        _advanceCell(true);
      case 'toggleChrome':
        setState(() => _focusMode = !_focusMode);
      case 'study':
        _showTools();
      default:
        return false;
    }
    return true;
  }

  void _interactionEnded() {
    _interacting = false;
    if (!_ready || _restoring) return;
    final base = _controller
        .calcMatrixForPage(pageNumber: _currentPage)
        .getMaxScaleOnAxis();
    final relative = _controller.currentZoom / base;
    if (relative < 1 || relative > 5)
      unawaited(
        _controller.zoomOnLocalPosition(
          localPosition: _viewport.center(Offset.zero),
          newZoom: base * relative.clamp(1, 5),
        ),
      );
  }

  Future<void> _applyReaderPreferences() async {
    final anchor = _captureLocator();
    await _saveProgress();
    final options = await _session!.settings();
    if (!mounted) return;
    _restoring = true;
    setState(() {
      _readerOptions = options;
      _layoutMode = options['mode'] as String? ?? 'vertical';
      _rtl = options['rtl'] == true;
      _background = options['background'] as String? ?? 'black';
      _fitMode = options['fit'] as String? ?? 'contain';
    });
    _controller.invalidate();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      try {
        if (anchor != null) await _goToAnchor(anchor);
      } finally {
        _restoring = false;
        if (mounted) _sampleBackground();
      }
    });
  }

  Future<void> _readerSettings() async {
    if (_session == null || _item == null) return;
    await _saveProgress();
    if (!mounted) return;
    await showReaderPreferences(
      context: context,
      database: _database,
      libraryId: _item!.libraryId,
      item: _item,
      currentPage: _currentPage,
      typography: false,
      onChanged: _applyReaderPreferences,
    );
  }

  Future<void> _sampleBackground() async {
    _sampleLease?.release();
    _sampleLease = null;
    if (!_ready ||
        !_controller.isReady ||
        !{'color', 'immersive'}.contains(_background))
      return;
    final number = _currentPage;
    var numbers = _presentation?.pagesFor(number) ?? [number];
    if (_rtl && _layoutMode != 'vertical') numbers = numbers.reversed.toList();
    final lease = _sampleJobs.request<ReaderEdgeColors>(
      key: '$_revision:${numbers.join(',')}:$_layoutMode:$_rtl:edge-v1-white',
      priority: ReaderPriority.background,
      estimatedBytes: 1024 * 1024,
      run: (token) async {
        Future<ReaderEdgeColors> sample(int number) async {
          token.check();
          final page = _controller.document.pages[number - 1];
          final cancellation = page.createCancellationToken();
          token.onCancel(cancellation.cancel);
          final bitmap = await page.render(
            width: 128,
            height: 128,
            fullWidth: 128,
            fullHeight: 128,
            cancellationToken: cancellation,
          );
          if (bitmap == null) throw const ReaderCancelled();
          try {
            final image = await bitmap.createImage();
            try {
              final data = await image.toByteData(
                format: ui.ImageByteFormat.rawRgba,
              );
              token.check();
              return data == null
                  ? const ReaderEdgeColors(
                      Colors.black,
                      Colors.black,
                      Colors.black,
                    )
                  : ReaderEdgeColors.sample(
                      data,
                      128,
                      128,
                      sourceWidth: page.width.round(),
                      sourceHeight: page.height.round(),
                      vertical: _layoutMode == 'vertical',
                    );
            } finally {
              image.dispose();
            }
          } finally {
            bitmap.dispose();
          }
        }

        final first = await sample(numbers.first);
        if (numbers.length == 1) return first;
        final last = await sample(numbers.last);
        return ReaderEdgeColors(
          first.first,
          last.second,
          Color.lerp(first.combined, last.combined, .5)!,
        );
      },
    );
    _sampleLease = lease;
    try {
      final colors = await lease.future;
      if (mounted && identical(_sampleLease, lease) && number == _currentPage)
        setState(() => _edgeColors = colors);
    } catch (_) {
      /* Background sampling cannot block the native PDF surface. */
    }
  }

  Future<void> _setCompleted(bool value) async {
    final item = _item;
    if (item == null) return;
    await _saveProgress();
    await _database.setItemCompletion(item: item, completed: value);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(value ? 'Marked read' : 'Marked unread')),
      );
    }
  }

  Future<void> _back() async {
    await _saveProgress();
    if (!mounted) return;
    final libraryId = _item?.libraryId;
    context.go(libraryId == null ? '/' : '/library/$libraryId');
  }

  Future<void> _goToAnchor(ReaderLocator locator) async {
    if (!_ready || !locator.compatible(_item!.id, _revision)) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'This anchor belongs to a different content revision. The original page reference is retained.',
            ),
          ),
        );
      return;
    }
    final number = locator.page.clamp(1, _totalPages);
    _currentPage = number;
    await _restoreLocator(locator);
  }

  Future<void> _selectionChanged(PdfTextSelection selection) async {
    final generation = ++_selectionGeneration;
    if (!selection.hasSelectedText || !selection.isCopyAllowed) {
      _selectedText = null;
      _selectionRange = null;
      return;
    }
    final range = selection.textSelectionPointRange;
    if (range == null ||
        range.end.text.pageNumber - range.start.text.pageNumber > 20) {
      _selectedText = null;
      _selectionRange = null;
      return;
    }
    final text = await selection.getSelectedText();
    if (!mounted || generation != _selectionGeneration) return;
    _selectedText = text.length > 16000 ? text.substring(0, 16000) : text;
    final page = range.start.text.pageNumber;
    _selectionRange = ReaderTextAnchor(
      resourceId: _item!.id,
      revision: _revision,
      startKey: 'pdf:$page',
      startPage: page,
      startOffset: range.start.index,
      endKey: 'pdf:${range.end.text.pageNumber}',
      endPage: range.end.text.pageNumber,
      endOffset: range.end.index + 1,
      unit: 'pdfCharacter',
      quote: _selectedText!,
    );
  }

  Future<void> _goToTextAnchor(ReaderTextAnchor anchor) async {
    if (!_ready ||
        !anchor.compatible(_item!.id, _revision) ||
        anchor.unit != 'pdfCharacter' ||
        anchor.startKey != 'pdf:${anchor.startPage}' ||
        anchor.endKey != 'pdf:${anchor.endPage}' ||
        anchor.endPage > _totalPages ||
        anchor.endPage - anchor.startPage > 20) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'This passage belongs to another content revision. Its original reference is kept.',
            ),
          ),
        );
      return;
    }
    try {
      final document = _controller.document;
      final first = await document.pages[anchor.startPage - 1]
          .loadStructuredText();
      final last = anchor.startPage == anchor.endPage
          ? first
          : await document.pages[anchor.endPage - 1].loadStructuredText();
      if (!mounted || !_ready || !anchor.compatible(_item!.id, _revision))
        return;
      if (anchor.startOffset >= first.charRects.length ||
          anchor.endOffset > last.charRects.length)
        throw const FormatException('Passage offsets changed');
      await _controller.textSelectionDelegate.setTextSelectionPointRange(
        PdfTextSelectionRange.fromPoints(
          PdfTextSelectionPoint(first, anchor.startOffset),
          PdfTextSelectionPoint(last, anchor.endOffset - 1),
        ),
      );
      final selected = await _controller.textSelectionDelegate
          .getSelectedText();
      if (!selected.startsWith(anchor.quote)) {
        await _controller.textSelectionDelegate.clearTextSelection();
        throw const FormatException('Passage text changed');
      }
      await _controller.goToRectInsidePage(
        pageNumber: anchor.startPage,
        rect: first.charRects[anchor.startOffset],
      );
      _currentPage = anchor.startPage;
    } on Object {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'The passage could not be restored. Your note and original reference are retained.',
            ),
          ),
        );
    }
  }

  Future<void> _pageBrowser() async {
    if (!_ready || !_controller.isReady || _thumbnails == null) return;
    await _saveProgress();
    if (!mounted) return;
    final page = await showReaderPages(
      context: context,
      source: PdfThumbnailSource(_controller.document),
      revision: _revision,
      jobs: _sampleJobs,
      store: _thumbnails!,
      currentPage: _currentPage,
      rtl: _rtl && _layoutMode != 'vertical',
    );
    if (page != null && mounted) await _jumpToPage(page);
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
    if (!_ready || !_controller.isReady) return;
    final number = _currentPage,
        page = _controller.document.pages[_currentPage - 1];
    final text = await showReaderTextAnalysis(
      context: context,
      jobs: _sampleJobs,
      pageKey: '$_revision:pdf:$number:${page.rotation.index}',
      raster: (token) async {
        final scale = math.min(
          1.0,
          math.min(
            2048 / math.max(page.width, page.height),
            math.sqrt(4 * 1024 * 1024 / (page.width * page.height)),
          ),
        );
        final cancellation = page.createCancellationToken();
        token.onCancel(cancellation.cancel);
        final bitmap = await page.render(
          width: math.max(1, (page.width * scale).round()),
          height: math.max(1, (page.height * scale).round()),
          fullWidth: math.max(1, (page.width * scale).round()).toDouble(),
          fullHeight: math.max(1, (page.height * scale).round()).toDouble(),
          cancellationToken: cancellation,
        );
        if (bitmap == null) throw const ReaderCancelled();
        try {
          final image = await bitmap.createImage();
          try {
            return await ReaderImageAnalysis.opaquePng(image, token);
          } finally {
            image.dispose();
          }
        } finally {
          bitmap.dispose();
        }
      },
    );
    if (!mounted || number != _currentPage || text == null) return;
    _selectedText = text;
    _selectionRange = null;
    _showTools();
  }

  void _showTools() {
    final item = _item;
    if (item == null) return;
    showLessonToolsSheet(
      context: context,
      database: _database,
      item: item,
      currentPage: _currentPage,
      anchor: _captureLocator(),
      textAnchor: _selectionRange,
      onJumpToTextAnchor: _goToTextAnchor,
      selectedText: _selectedText,
      onJumpToAnchor: _goToAnchor,
      onJumpToPage: _jumpToPage,
    );
  }

  void _toggleSearch() {
    setState(() => _searchVisible = !_searchVisible);
    if (!_searchVisible) {
      _searchController.clear();
      _searcher?.resetTextSearch();
    }
  }

  @override
  Future<AppExitResponse> didRequestAppExit() async {
    await _saveProgress();
    return AppExitResponse.exit;
  }

  @override
  void didHaveMemoryPressure() {
    _sampleLease?.release();
    _sampleLease = null;
    _sampleJobs.releaseSpeculative();
    _edgeColors = null;
    _thumbnails?.clearMemory();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) unawaited(_saveProgress());
  }

  @override
  void dispose() {
    _releaseLibraryProcessing?.call();
    WidgetsBinding.instance.removeObserver(this);
    _saveTimer?.cancel();
    _sampleLease?.release();
    _sampleJobs.dispose();
    _thumbnails?.dispose();
    _controller.removeListener(_viewChanged);
    _searcher?.removeListener(_searchChanged);
    _searcher?.dispose();
    _searchController.dispose();
    if (_ready && !_restoring && _controller.isReady) {
      _writer
        ?..zoom = _controller.currentZoom
        ..scrollOffset = _controller.visibleRect.top;
    }
    final locator = _ready && !_restoring ? _captureLocator() : null;
    unawaited(
      Future.wait([
        if (_writer != null) _writer!.dispose(),
        if (locator != null) _session!.write(locator: locator),
      ]),
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final item = _item;
    final compact = AppBreakpoints.isCompact(context);
    return Scaffold(
      appBar: _focusMode
          ? null
          : AppTopBar(
              title: cleanDisplayTitle(
                item?.userTitle ?? item?.title ?? 'PDF reader',
              ),
              showBack: true,
              showHome: true,
              onBack: _back,
              actions: [
                IconButton(
                  tooltip: 'Page thumbnails',
                  onPressed: _ready ? _pageBrowser : null,
                  icon: const Icon(Icons.grid_view),
                ),
                if (!compact) ...[
                  IconButton(
                    tooltip: 'Reading preferences',
                    onPressed: _ready ? _readerSettings : null,
                    icon: const Icon(Icons.tune),
                  ),
                  IconButton(
                    tooltip: 'Previous reading cell',
                    onPressed: _ready ? () => _advanceCell(false) : null,
                    icon: const Icon(Icons.chevron_left),
                  ),
                  IconButton(
                    tooltip: 'Next reading cell',
                    onPressed: _ready ? () => _advanceCell(true) : null,
                    icon: const Icon(Icons.chevron_right),
                  ),
                  PopupMenuButton<bool>(
                    tooltip: 'Fit document',
                    onSelected: _fit,
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: true, child: Text('Fit width')),
                      PopupMenuItem(value: false, child: Text('Fit page')),
                    ],
                  ),
                ],
                if (_ready && !compact)
                  TextButton.icon(
                    onPressed: _jumpToPage,
                    icon: const Icon(Icons.find_in_page_outlined),
                    label: Text('$_currentPage / $_totalPages'),
                  ),
                if (!compact)
                  IconButton(
                    tooltip: ReaderImageAnalysis.available
                        ? 'Recognize page text'
                        : 'OCR availability',
                    onPressed: _ready ? _pageTextTools : null,
                    icon: const Icon(Icons.document_scanner_outlined),
                  ),
                if (!compact) ...[
                  IconButton(
                    tooltip: 'Search document',
                    onPressed: _ready ? _toggleSearch : null,
                    icon: const Icon(Icons.search_rounded),
                  ),
                  IconButton(
                    tooltip: 'Zoom out',
                    onPressed: _ready ? _controller.zoomDown : null,
                    icon: const Icon(Icons.zoom_out_rounded),
                  ),
                  IconButton(
                    tooltip: 'Zoom in',
                    onPressed: _ready ? _controller.zoomUp : null,
                    icon: const Icon(Icons.zoom_in_rounded),
                  ),
                  IconButton(
                    tooltip: 'Notes & bookmarks',
                    onPressed: item == null ? null : _showTools,
                    icon: const Icon(Icons.note_alt_outlined),
                  ),
                  IconButton(
                    tooltip: 'Enter focus mode',
                    onPressed: _ready
                        ? () => setState(() => _focusMode = true)
                        : null,
                    icon: const Icon(Icons.fullscreen_rounded),
                  ),
                ],
                PopupMenuButton<String>(
                  tooltip: 'Document actions',
                  onSelected: (value) {
                    if (value == 'focus') {
                      setState(() => _focusMode = true);
                    }
                    if (value == 'settings') _readerSettings();
                    if (value == 'ocr') _pageTextTools();
                    if (value == 'previous') _advanceCell(false);
                    if (value == 'next') _advanceCell(true);
                    if (value == 'fitWidth') _fit(true);
                    if (value == 'fitPage') _fit(false);
                    if (value == 'complete') _setCompleted(true);
                    if (value == 'incomplete') _setCompleted(false);
                  },
                  itemBuilder: (_) => [
                    if (compact) ...[
                      PopupMenuItem(
                        enabled: _ready,
                        value: 'settings',
                        child: const Text('Reading preferences'),
                      ),
                      PopupMenuItem(
                        enabled: _ready,
                        value: 'ocr',
                        child: Text(
                          ReaderImageAnalysis.available
                              ? 'Image text recognition'
                              : 'OCR availability',
                        ),
                      ),
                      PopupMenuItem(
                        enabled: _ready,
                        value: 'previous',
                        child: const Text('Previous reading cell'),
                      ),
                      PopupMenuItem(
                        enabled: _ready,
                        value: 'next',
                        child: const Text('Next reading cell'),
                      ),
                      PopupMenuItem(
                        enabled: _ready,
                        value: 'fitWidth',
                        child: const Text('Fit width'),
                      ),
                      PopupMenuItem(
                        enabled: _ready,
                        value: 'fitPage',
                        child: const Text('Fit page'),
                      ),
                    ],
                    if (compact)
                      const PopupMenuItem(
                        value: 'focus',
                        child: Text('Focus mode'),
                      ),
                    const PopupMenuItem(
                      value: 'complete',
                      child: Text('Mark read'),
                    ),
                    const PopupMenuItem(
                      value: 'incomplete',
                      child: Text('Mark unread'),
                    ),
                  ],
                ),
              ],
            ),
      body: Stack(
        children: [
          Positioned.fill(
            child: CallbackShortcuts(
              bindings: {
                const SingleActivator(LogicalKeyboardKey.arrowLeft): () =>
                    _advanceCell(_rtl),
                const SingleActivator(LogicalKeyboardKey.arrowRight): () =>
                    _advanceCell(!_rtl),
                const SingleActivator(LogicalKeyboardKey.pageDown): () =>
                    _advanceCell(true),
                const SingleActivator(LogicalKeyboardKey.pageUp): () =>
                    _advanceCell(false),
              },
              child: Focus(autofocus: true, child: _body()),
            ),
          ),
          if (_focusMode)
            Positioned(
              top: AppSpace.md,
              right: AppSpace.md,
              child: SafeArea(
                child: IconButton.filledTonal(
                  tooltip: 'Exit focus mode',
                  onPressed: () => setState(() => _focusMode = false),
                  icon: const Icon(Icons.fullscreen_exit_rounded),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: !_focusMode && compact && _filePath != null
          ? _ReaderBottomBar(
              ready: _ready,
              currentPage: _currentPage,
              totalPages: _totalPages,
              onPage: _jumpToPage,
              onSearch: _toggleSearch,
              onZoomOut: _controller.zoomDown,
              onZoomIn: _controller.zoomUp,
              onStudy: _showTools,
            )
          : null,
    );
  }

  Widget _body() {
    if (_error != null) {
      return StudyPage(
        maxWidth: 760,
        child: ContentState(
          icon: Icons.picture_as_pdf_outlined,
          title: 'This PDF cannot be opened',
          message: _error!,
          action: FilledButton.icon(
            onPressed: _back,
            icon: const Icon(Icons.arrow_back_rounded),
            label: const Text('Back to library'),
          ),
          tone: ContentStateTone.error,
        ),
      );
    }
    if (_filePath == null) {
      return const _ReaderLoadingState();
    }
    return Column(
      children: [
        if (_searchVisible) _searchBar(),
        Expanded(
          child: LayoutBuilder(
            builder: (context, box) {
              final size = box.biggest;
              if (size != _viewport) {
                final anchor = _ready ? _captureLocator() : null;
                _viewport = size;
                if (_ready)
                  WidgetsBinding.instance.addPostFrameCallback((_) async {
                    if (!mounted) return;
                    _controller.invalidate();
                    if (anchor != null) await _goToAnchor(anchor);
                  });
              }
              return Stack(
                children: [
                  Positioned.fill(
                    child: ReaderBackgroundSurface(
                      first: _background == 'white'
                          ? Colors.white
                          : _background == 'color'
                          ? _edgeColors?.combined ?? Colors.black
                          : _background == 'immersive'
                          ? _edgeColors?.first ?? Colors.black
                          : Colors.black,
                      second: _background == 'white'
                          ? Colors.white
                          : _background == 'color'
                          ? _edgeColors?.combined ?? Colors.black
                          : _background == 'immersive'
                          ? _edgeColors?.second ?? Colors.black
                          : Colors.black,
                      vertical: _layoutMode == 'vertical',
                    ),
                  ),
                  Positioned.fill(
                    child: PdfViewer(
                      _remoteSource == null
                          ? PdfDocumentRefFile(_filePath!)
                          : PdfDocumentRefUri(
                              _remoteSource!.uri,
                              headers: _remoteSource!.headers,
                            ),
                      controller: _controller,
                      params: PdfViewerParams(
                        maxImageBytesCachedOnMemory: 64 * 1024 * 1024,
                        horizontalCacheExtent: 0,
                        verticalCacheExtent: 0,
                        limitRenderingCache: true,
                        onePassRenderingSizeThreshold: 2000,
                        enableKeyboardNavigation: false,
                        onGeneralTap: _readerTap,
                        onInteractionStart: (_) => _interacting = true,
                        onInteractionEnd: (_) => _interactionEnded(),
                        layoutPages: _layoutPdf,
                        textSelectionParams: PdfTextSelectionParams(
                          onTextSelectionChange: _selectionChanged,
                        ),
                        onViewerReady: _viewerReady,
                        onDocumentLoadFinished: (documentRef, succeeded) {
                          if (!succeeded && mounted) {
                            setState(
                              () => _error =
                                  'This PDF could not be loaded. Check the file or the desktop connection and try again.',
                            );
                          }
                        },
                        onPageChanged: _pageChanged,
                        pagePaintCallbacks: _searcher == null
                            ? null
                            : [_searcher!.pageTextMatchPaintCallback],
                        backgroundColor: Colors.transparent,
                        errorBannerBuilder:
                            (
                              context,
                              error,
                              stackTrace,
                              documentRef,
                            ) => const Padding(
                              padding: EdgeInsets.all(AppSpace.lg),
                              child: ContentState(
                                icon: Icons.error_outline_rounded,
                                title: 'A page could not be rendered',
                                message:
                                    'The document may contain unsupported or damaged page data.',
                                tone: ContentStateTone.error,
                                compact: true,
                              ),
                            ),
                      ),
                    ),
                  ),
                  if (!_ready)
                    const Positioned.fill(child: _ReaderLoadingState()),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _searchBar() {
    final searcher = _searcher;
    final current = searcher?.currentIndex;
    final count = searcher?.matches.length ?? 0;
    final field = TextField(
      controller: _searchController,
      autofocus: true,
      decoration: const InputDecoration(
        hintText: 'Search this PDF',
        prefixIcon: Icon(Icons.search_rounded),
      ),
      onChanged: (value) => searcher?.startTextSearch(value),
    );
    final controls = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (searcher?.isSearching == true)
          const SizedBox.square(
            dimension: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        else
          Semantics(
            liveRegion: true,
            label: count == 0
                ? 'No search matches'
                : '${(current ?? 0) + 1} of $count search matches',
            child: StudyStatusBadge(
              label: count == 0
                  ? 'No matches'
                  : '${(current ?? 0) + 1} of $count',
              tone: count == 0
                  ? StudyStatusTone.neutral
                  : StudyStatusTone.primary,
            ),
          ),
        IconButton(
          tooltip: 'Previous match',
          onPressed: count == 0 ? null : searcher?.goToPrevMatch,
          icon: const Icon(Icons.keyboard_arrow_up_rounded),
        ),
        IconButton(
          tooltip: 'Next match',
          onPressed: count == 0 ? null : searcher?.goToNextMatch,
          icon: const Icon(Icons.keyboard_arrow_down_rounded),
        ),
        IconButton(
          tooltip: 'Close search',
          onPressed: _toggleSearch,
          icon: const Icon(Icons.close_rounded),
        ),
      ],
    );
    return Container(
      padding: const EdgeInsets.all(AppSpace.sm),
      decoration: BoxDecoration(
        color: context.studyColors.surfaceRaised,
        border: Border(
          bottom: BorderSide(color: context.studyColors.outlineSoft),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 560) {
            return Column(
              children: [
                field,
                const SizedBox(height: AppSpace.xs),
                Align(alignment: Alignment.centerRight, child: controls),
              ],
            );
          }
          return Row(
            children: [
              Expanded(child: field),
              const SizedBox(width: AppSpace.xs),
              controls,
            ],
          );
        },
      ),
    );
  }
}

class _ReaderBottomBar extends StatelessWidget {
  const _ReaderBottomBar({
    required this.ready,
    required this.currentPage,
    required this.totalPages,
    required this.onPage,
    required this.onSearch,
    required this.onZoomOut,
    required this.onZoomIn,
    required this.onStudy,
  });

  final bool ready;
  final int currentPage;
  final int totalPages;
  final VoidCallback onPage;
  final VoidCallback onSearch;
  final VoidCallback onZoomOut;
  final VoidCallback onZoomIn;
  final VoidCallback onStudy;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: context.studyColors.surfaceRaised,
          border: Border(
            top: BorderSide(color: context.studyColors.outlineSoft),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.xs),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            IconButton(
              tooltip: 'Go to page',
              onPressed: ready ? onPage : null,
              icon: const Icon(Icons.find_in_page_outlined),
            ),
            TextButton(
              onPressed: ready ? onPage : null,
              child: Text(ready ? '$currentPage / $totalPages' : '— / —'),
            ),
            IconButton(
              tooltip: 'Search document',
              onPressed: ready ? onSearch : null,
              icon: const Icon(Icons.search_rounded),
            ),
            PopupMenuButton<String>(
              tooltip: 'Zoom controls',
              enabled: ready,
              onSelected: (value) {
                if (value == 'out') onZoomOut();
                if (value == 'in') onZoomIn();
              },
              icon: const Icon(Icons.zoom_in_rounded),
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'out', child: Text('Zoom out')),
                PopupMenuItem(value: 'in', child: Text('Zoom in')),
              ],
            ),
            IconButton(
              tooltip: 'Notes & bookmarks',
              onPressed: ready ? onStudy : null,
              icon: const Icon(Icons.note_alt_outlined),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReaderLoadingState extends StatelessWidget {
  const _ReaderLoadingState();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: context.studyColors.surfaceSubtle,
      child: Semantics(
        liveRegion: true,
        label: 'Loading document',
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                  ),
                  child: const Padding(
                    padding: EdgeInsets.all(AppSpace.lg),
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  ),
                ),
                const SizedBox(height: AppSpace.lg),
                Text(
                  'Preparing your document',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: AppSpace.xs),
                Text(
                  'Restoring your page and reading settings…',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
