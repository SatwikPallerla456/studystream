import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/display_utils.dart';
import '../../data/db/app_database.dart';
import '../../data/providers/app_providers.dart';
import '../../domain/services/progress_writer.dart';
import '../../shared/widgets/app_top_bar.dart';
import '../../shared/widgets/content_state.dart';
import '../../shared/widgets/lesson_tools_sheet.dart';
import '../../shared/widgets/study_ui.dart';

class ResourceScreen extends ConsumerStatefulWidget {
  const ResourceScreen({super.key, required this.itemId});

  final String itemId;

  @override
  ConsumerState<ResourceScreen> createState() => _ResourceScreenState();
}

class _ResourceScreenState extends ConsumerState<ResourceScreen>
    with WidgetsBindingObserver {
  late final AppDatabase _database;
  final _scrollController = ScrollController();
  Item? _item;
  ReadingProgressWriter? _writer;
  Timer? _saveTimer;
  String? _content;
  String? _externalUrl;
  String? _error;
  bool _loading = true;
  bool _navigating = false;
  bool _focusMode = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _database = ref.read(appDatabaseProvider);
    _scrollController.addListener(_scrollChanged);
    _load();
  }

  Future<void> _load() async {
    try {
      final item = await _database.getItemById(widget.itemId);
      if (item == null) throw StateError('This resource no longer exists.');
      _item = item;
      if (item.unavailable || !await File(item.filePath).exists()) {
        throw StateError(
          'This file is missing. Rescan or relink it from the library.',
        );
      }
      final saved = await _database.getReadingByItemId(item.id);
      final preferences = await ref
          .read(appPreferencesRepositoryProvider)
          .load();
      _writer =
          ReadingProgressWriter(
              database: _database,
              item: item,
              completionThreshold: preferences.completionThreshold,
            )
            ..currentPage = (saved?.percentRead ?? 0).round().clamp(1, 100)
            ..totalPages = 100
            ..pagesVisited = (saved?.percentRead ?? 0) > 0 ? 2 : 1
            ..scrollOffset = saved?.resumeScrollOffset ?? 0;
      switch (item.itemType) {
        case 'txt':
        case 'html':
          _content = await File(item.filePath).readAsString();
        case 'link':
          _content = await File(item.filePath).readAsString();
          _externalUrl = _extractUrl(_content!);
      }
      if (!mounted) return;
      setState(() => _loading = false);
      if ((saved?.resumeScrollOffset ?? 0) > 0) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            _scrollController.jumpTo(
              (saved!.resumeScrollOffset).clamp(
                0,
                _scrollController.position.maxScrollExtent,
              ),
            );
          }
        });
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        final message = error.toString().toLowerCase();
        _error =
            message.contains('missing') || message.contains('no longer exists')
            ? 'The resource file is missing or has moved. Relink it from the library to keep your progress.'
            : 'StudyStream could not open this resource. The file may be inaccessible or unsupported.';
        _loading = false;
      });
    }
  }

  String? _extractUrl(String content) {
    for (final line in content.split(RegExp(r'\r?\n'))) {
      final trimmed = line.trim();
      if (trimmed.toUpperCase().startsWith('URL=')) {
        return trimmed.substring(4).trim();
      }
    }
    return null;
  }

  void _scrollChanged() {
    if (!_scrollController.hasClients) return;
    final max = _scrollController.position.maxScrollExtent;
    final fraction = max <= 0
        ? 0.0
        : (_scrollController.offset / max).clamp(0.0, 1.0);
    final writer = _writer;
    if (writer == null) return;
    writer
      ..currentPage = (fraction * 99 + 1).round()
      ..pagesVisited = fraction > 0.02 ? 2 : 1
      ..scrollOffset = _scrollController.offset;
    _saveTimer?.cancel();
    _saveTimer = Timer(
      const Duration(milliseconds: 800),
      () => unawaited(writer.save()),
    );
  }

  Future<void> _setCompleted(bool value) async {
    final item = _item;
    if (item == null) return;
    await _writer?.save();
    await _database.setItemCompletion(item: item, completed: value);
    if (mounted) _message(value ? 'Marked complete' : 'Marked incomplete');
  }

  Future<void> _navigate(bool forward) async {
    if (_navigating) return;
    final item = _item;
    if (item == null) return;
    _navigating = true;
    await _writer?.save();
    final next = forward
        ? await _database.getNextSequentialItem(item.id)
        : await _database.getPreviousSequentialItem(item.id);
    if (!mounted) return;
    if (next == null) {
      context.go('/library/${item.libraryId}');
      return;
    }
    context.pushReplacement(switch (next.itemType) {
      'video' || 'audio' => '/player/${next.id}',
      'pdf' => '/pdf/${next.id}',
      _ => '/resource/${next.id}',
    });
  }

  Future<void> _back() async {
    await _writer?.save();
    if (!mounted) return;
    final libraryId = _item?.libraryId;
    context.go(libraryId == null ? '/' : '/library/$libraryId');
  }

  Future<void> _openExternal() async {
    final item = _item;
    if (item == null) return;
    final uri = item.itemType == 'link'
        ? Uri.tryParse(_externalUrl ?? '')
        : Uri.file(item.filePath);
    if (uri == null) {
      _message('This resource does not contain a valid link.');
      return;
    }
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (mounted && !opened) _message('No application could open this file.');
  }

  void _showTools() {
    final item = _item;
    if (item == null) return;
    showLessonToolsSheet(context: context, database: _database, item: item);
  }

  void _message(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) unawaited(_writer?.save());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _saveTimer?.cancel();
    _scrollController
      ..removeListener(_scrollChanged)
      ..dispose();
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
                item?.userTitle ?? item?.title ?? 'Resource',
              ),
              showBack: true,
              showHome: true,
              onBack: _back,
              actions: [
                if (!compact)
                  IconButton(
                    tooltip: 'Previous lesson',
                    onPressed: item == null ? null : () => _navigate(false),
                    icon: const Icon(Icons.skip_previous_rounded),
                  ),
                IconButton(
                  tooltip: 'Study tools',
                  onPressed: item == null ? null : _showTools,
                  icon: const Icon(Icons.note_alt_outlined),
                ),
                if (!compact)
                  IconButton(
                    tooltip: 'Enter focus mode',
                    onPressed: item == null
                        ? null
                        : () => setState(() => _focusMode = true),
                    icon: const Icon(Icons.fullscreen_rounded),
                  ),
                PopupMenuButton<String>(
                  tooltip: 'Resource actions',
                  onSelected: (value) {
                    if (value == 'previous') _navigate(false);
                    if (value == 'next') _navigate(true);
                    if (value == 'open') _openExternal();
                    if (value == 'complete') _setCompleted(true);
                    if (value == 'incomplete') _setCompleted(false);
                  },
                  itemBuilder: (_) => [
                    if (compact) ...[
                      const PopupMenuItem(
                        value: 'previous',
                        child: Text('Previous lesson'),
                      ),
                      const PopupMenuItem(
                        value: 'next',
                        child: Text('Next lesson'),
                      ),
                      const PopupMenuDivider(),
                    ],
                    if (item != null)
                      const PopupMenuItem(
                        value: 'open',
                        child: Text('Open externally'),
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
                if (!compact)
                  IconButton(
                    tooltip: 'Next lesson',
                    onPressed: item == null ? null : () => _navigate(true),
                    icon: const Icon(Icons.skip_next_rounded),
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
      bottomNavigationBar: !_focusMode && compact && item != null
          ? _ResourceBottomBar(
              onPrevious: () => _navigate(false),
              onStudy: _showTools,
              onFocus: () => setState(() => _focusMode = true),
              onNext: () => _navigate(true),
            )
          : null,
    );
  }

  Widget _body() {
    if (_loading) return const _ResourceLoadingState();
    if (_error != null) {
      return StudyPage(
        maxWidth: 760,
        child: ContentState(
          icon: Icons.file_present_outlined,
          title: 'This resource cannot be opened',
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
    final item = _item!;
    return switch (item.itemType) {
      'txt' => _readable(SelectableText(_content ?? '')),
      'html' => _readable(Html(data: _content ?? '')),
      'image' => ColoredBox(
        color: context.studyColors.surfaceSubtle,
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.md),
          child: InteractiveViewer(
            minScale: 0.5,
            maxScale: 5,
            child: Center(
              child: Image.file(
                File(item.filePath),
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => const ContentState(
                  icon: Icons.broken_image_outlined,
                  title: 'Image could not be decoded',
                  message:
                      'The image may be damaged or use a format unavailable on this device.',
                  tone: ContentStateTone.error,
                ),
              ),
            ),
          ),
        ),
      ),
      'link' => _ExternalResource(
        icon: Icons.link,
        title: 'External link',
        detail: _externalUrl ?? 'No valid URL was found in this shortcut.',
        buttonLabel: 'Open link',
        onOpen: _externalUrl == null ? null : _openExternal,
      ),
      'doc' || 'ppt' || 'epub' => _ExternalResource(
        icon: Icons.open_in_new,
        title: '${item.itemType.toUpperCase()} requires another app',
        detail:
            'StudyStream keeps this file organised and tracks manual completion, but does not pretend to render a format it cannot display reliably.',
        buttonLabel: 'Open in another app',
        onOpen: _openExternal,
      ),
      _ => _ExternalResource(
        icon: Icons.insert_drive_file_outlined,
        title: 'Preview unavailable',
        detail: 'This resource can be opened with another application.',
        buttonLabel: 'Open externally',
        onOpen: _openExternal,
      ),
    };
  }

  Widget _readable(Widget child) {
    return ColoredBox(
      color: context.studyColors.surfaceSubtle,
      child: Scrollbar(
        controller: _scrollController,
        child: SingleChildScrollView(
          controller: _scrollController,
          padding: EdgeInsets.symmetric(
            horizontal: AppBreakpoints.isCompact(context)
                ? AppSpace.md
                : AppSpace.xl,
            vertical: AppSpace.lg,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 860),
              child: StudySurface(
                padding: EdgeInsets.all(
                  AppBreakpoints.isCompact(context)
                      ? AppSpace.lg
                      : AppSpace.xxl,
                ),
                child: DefaultTextStyle.merge(
                  style: Theme.of(context).textTheme.bodyLarge,
                  child: child,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ExternalResource extends StatelessWidget {
  const _ExternalResource({
    required this.icon,
    required this.title,
    required this.detail,
    required this.buttonLabel,
    required this.onOpen,
  });

  final IconData icon;
  final String title;
  final String detail;
  final String buttonLabel;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    return StudyPage(
      maxWidth: 760,
      child: ContentState(
        icon: icon,
        title: title,
        message: detail,
        action: FilledButton.icon(
          onPressed: onOpen,
          icon: const Icon(Icons.open_in_new_rounded),
          label: Text(buttonLabel),
        ),
      ),
    );
  }
}

class _ResourceBottomBar extends StatelessWidget {
  const _ResourceBottomBar({
    required this.onPrevious,
    required this.onStudy,
    required this.onFocus,
    required this.onNext,
  });

  final VoidCallback onPrevious;
  final VoidCallback onStudy;
  final VoidCallback onFocus;
  final VoidCallback onNext;

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
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            IconButton(
              tooltip: 'Previous lesson',
              onPressed: onPrevious,
              icon: const Icon(Icons.skip_previous_rounded),
            ),
            IconButton(
              tooltip: 'Study tools',
              onPressed: onStudy,
              icon: const Icon(Icons.note_alt_outlined),
            ),
            IconButton(
              tooltip: 'Focus mode',
              onPressed: onFocus,
              icon: const Icon(Icons.fullscreen_rounded),
            ),
            IconButton(
              tooltip: 'Next lesson',
              onPressed: onNext,
              icon: const Icon(Icons.skip_next_rounded),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResourceLoadingState extends StatelessWidget {
  const _ResourceLoadingState();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: context.studyColors.surfaceSubtle,
      child: Semantics(
        liveRegion: true,
        label: 'Loading resource',
        child: Center(
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
                'Preparing your resource',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpace.xs),
              Text(
                'Restoring your reading progress…',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
