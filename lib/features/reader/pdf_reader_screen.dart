import 'dart:async';
import 'dart:io';
import 'dart:ui' show AppExitResponse;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/display_utils.dart';
import '../../data/db/app_database.dart';
import '../../data/providers/app_providers.dart';
import '../../data/sync/lan_sync_client.dart';
import '../../domain/services/progress_writer.dart';
import '../../shared/widgets/app_top_bar.dart';
import '../../shared/widgets/content_state.dart';
import '../../shared/widgets/lesson_tools_sheet.dart';
import '../../shared/widgets/study_ui.dart';

class PdfReaderScreen extends ConsumerStatefulWidget {
  const PdfReaderScreen({super.key, required this.itemId, this.initialPage});

  final String itemId;
  final int? initialPage;

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

  @override
  void initState() {
    super.initState();
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
      final saved = await _database.getReadingByItemId(item.id);
      final preferences = await ref
          .read(appPreferencesRepositoryProvider)
          .load();
      _currentPage = widget.initialPage ?? saved?.resumePage ?? 1;
      _savedZoom = saved?.zoom ?? 1;
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
      await controller.goToPosition(
        documentOffset: Offset(
          controller.visibleRect.left,
          _savedOffset > 0 ? _savedOffset : controller.visibleRect.top,
        ),
        zoom: _savedZoom,
        duration: Duration.zero,
      );
      if (mounted) {
        _restoring = false;
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
    _writer?.readingMode = width ? 'fitWidth' : 'fitPage';
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
    setState(() => _currentPage = page);
    _visitedPages.add(page);
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

  Future<void> _saveProgress() async {
    final writer = _writer;
    if (writer == null || !_ready || _restoring || !_controller.isReady) return;
    writer
      ..zoom = _controller.currentZoom
      ..scrollOffset = _controller.visibleRect.top;
    await writer.save();
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
    await _controller.goToPage(pageNumber: page.clamp(1, _totalPages));
  }

  Future<void> _setCompleted(bool value) async {
    final item = _item;
    if (item == null) return;
    await _saveProgress();
    await _database.setItemCompletion(item: item, completed: value);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(value ? 'Marked complete' : 'Marked incomplete'),
        ),
      );
    }
  }

  Future<void> _back() async {
    await _saveProgress();
    if (!mounted) return;
    final libraryId = _item?.libraryId;
    context.go(libraryId == null ? '/' : '/library/$libraryId');
  }

  void _showTools() {
    final item = _item;
    if (item == null) return;
    showLessonToolsSheet(
      context: context,
      database: _database,
      item: item,
      currentPage: _currentPage,
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
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) unawaited(_saveProgress());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _saveTimer?.cancel();
    _controller.removeListener(_viewChanged);
    _searcher?.removeListener(_searchChanged);
    _searcher?.dispose();
    _searchController.dispose();
    if (_ready && !_restoring && _controller.isReady) {
      _writer
        ?..zoom = _controller.currentZoom
        ..scrollOffset = _controller.visibleRect.top;
    }
    unawaited(_writer?.dispose());
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
                PopupMenuButton<bool>(
                  tooltip: 'Fit document',
                  onSelected: _fit,
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: true, child: Text('Fit width')),
                    PopupMenuItem(value: false, child: Text('Fit page')),
                  ],
                ),
                if (_ready && !compact)
                  TextButton.icon(
                    onPressed: _jumpToPage,
                    icon: const Icon(Icons.find_in_page_outlined),
                    label: Text('$_currentPage / $_totalPages'),
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
                    tooltip: 'Study tools',
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
                    if (value == 'complete') _setCompleted(true);
                    if (value == 'incomplete') _setCompleted(false);
                  },
                  itemBuilder: (_) => [
                    if (compact)
                      const PopupMenuItem(
                        value: 'focus',
                        child: Text('Focus mode'),
                      ),
                    const PopupMenuItem(
                      value: 'complete',
                      child: Text('Mark complete'),
                    ),
                    const PopupMenuItem(
                      value: 'incomplete',
                      child: Text('Mark incomplete'),
                    ),
                  ],
                ),
              ],
            ),
      body: Stack(
        children: [
          Positioned.fill(child: _body()),
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
          child: Stack(
            children: [
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
                    enableKeyboardNavigation: true,
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
                    backgroundColor: context.studyColors.surfaceSubtle,
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
              if (!_ready) const Positioned.fill(child: _ReaderLoadingState()),
            ],
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
              tooltip: 'Study tools',
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
