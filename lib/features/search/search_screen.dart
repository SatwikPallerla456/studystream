import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/display_utils.dart';
import '../../data/db/app_database.dart';
import '../../data/providers/app_providers.dart';
import '../../shared/widgets/content_state.dart';
import '../../shared/widgets/study_ui.dart';

enum _SearchFilter { all, lesson, note, bookmark }

enum _SearchSort { recent, title }

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  Timer? _debounce;
  List<GlobalSearchEntry> _results = const [];
  bool _searching = false;
  _SearchFilter _filter = _SearchFilter.all;
  _SearchSort _sort = _SearchSort.recent;
  bool _failed = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _changed(String value) {
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 240), () => _search(value));
  }

  void _clear() {
    _controller.clear();
    _debounce?.cancel();
    setState(() {
      _results = const [];
      _searching = false;
      _failed = false;
    });
  }

  Future<void> _search(String query) async {
    if (query.trim().isEmpty) {
      if (mounted) _clear();
      return;
    }
    setState(() {
      _searching = true;
      _failed = false;
    });
    try {
      final results = await ref.read(appDatabaseProvider).searchAll(query);
      if (!mounted || query != _controller.text) return;
      setState(() {
        _results = results;
        _searching = false;
      });
    } catch (_) {
      if (!mounted || query != _controller.text) return;
      setState(() {
        _failed = true;
        _searching = false;
      });
    }
  }

  void _open(GlobalSearchEntry entry) {
    final item = entry.item;
    if (item == null) return;
    final path = switch (item.itemType) {
      'video' || 'audio' => Uri(
        path: '/player/${item.id}',
        queryParameters: entry.positionSeconds == null
            ? null
            : {'position': entry.positionSeconds.toString()},
      ).toString(),
      'pdf' => Uri(
        path: '/pdf/${item.id}',
        queryParameters: entry.pageNumber == null
            ? null
            : {'page': entry.pageNumber.toString()},
      ).toString(),
      _ => '/resource/${item.id}',
    };
    context.push(path);
  }

  List<GlobalSearchEntry> get _visibleResults {
    final visible = _filter == _SearchFilter.all
        ? [..._results]
        : _results
              .where((entry) => entry.kind == _filter.name)
              .toList(growable: true);
    switch (_sort) {
      case _SearchSort.recent:
        visible.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      case _SearchSort.title:
        visible.sort(
          (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
        );
    }
    return visible;
  }

  @override
  Widget build(BuildContext context) {
    final results = _visibleResults;
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.slash): () {
          _focusNode.requestFocus();
        },
        const SingleActivator(LogicalKeyboardKey.escape): _clear,
      },
      child: StudyPage(
        maxWidth: 1120,
        scrollable: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const StudyPageHeader(
              eyebrow: 'Across your learning',
              title: 'Search',
              description:
                  'Find a lesson, a saved thought, or the exact page and moment you need.',
            ),
            const SizedBox(height: AppSpace.lg),
            Semantics(
              textField: true,
              label: 'Search lessons, notes, and bookmarks',
              child: StudySearchField(
                controller: _controller,
                focusNode: _focusNode,
                autofocus:
                    MediaQuery.sizeOf(context).width >= AppBreakpoints.expanded,
                hintText: 'Search lessons, notes, and bookmarks',
                onChanged: _changed,
                onSubmitted: _search,
              ),
            ),
            const SizedBox(height: AppSpace.sm),
            _SearchControls(
              filter: _filter,
              sort: _sort,
              resultCount: results.length,
              hasQuery: _controller.text.trim().isNotEmpty,
              onFilter: (value) => setState(() => _filter = value),
              onSort: (value) => setState(() => _sort = value),
            ),
            if (_searching) ...[
              const SizedBox(height: AppSpace.sm),
              const LinearProgressIndicator(
                semanticsLabel: 'Searching your libraries',
              ),
            ],
            const SizedBox(height: AppSpace.lg),
            Expanded(child: _body(results)),
          ],
        ),
      ),
    );
  }

  Widget _body(List<GlobalSearchEntry> results) {
    if (_controller.text.trim().isEmpty) {
      return const _SearchStartState();
    }
    if (_failed) {
      return ContentState(
        icon: Icons.cloud_off_rounded,
        title: 'Search is temporarily unavailable',
        message:
            'StudyStream could not read the local search index. Try again in a moment.',
        action: FilledButton.icon(
          onPressed: () => _search(_controller.text),
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Try again'),
        ),
        tone: ContentStateTone.error,
      );
    }
    if (!_searching && results.isEmpty) {
      return ContentState(
        icon: Icons.search_off_rounded,
        title: _filter == _SearchFilter.all
            ? 'No results for “${_controller.text.trim()}”'
            : 'No matching ${_filter.name}s',
        message: _filter == _SearchFilter.all
            ? 'Try a shorter title, a filename, or a broader phrase.'
            : 'Choose All results or try a different search term.',
        action: _filter == _SearchFilter.all
            ? null
            : OutlinedButton(
                onPressed: () => setState(() => _filter = _SearchFilter.all),
                child: const Text('Show all results'),
              ),
      );
    }
    if (_searching && results.isEmpty) {
      return const ContentLoadingState(label: 'Searching your libraries');
    }
    return StudySurface(
      padding: EdgeInsets.zero,
      child: ListView.separated(
        padding: const EdgeInsets.all(AppSpace.xs),
        itemCount: results.length,
        separatorBuilder: (_, _) =>
            const Divider(indent: 80, endIndent: AppSpace.sm),
        itemBuilder: (context, index) {
          final entry = results[index];
          return _SearchResultRow(
            entry: entry,
            onTap: entry.item == null || entry.item!.unavailable
                ? null
                : () => _open(entry),
          );
        },
      ),
    );
  }
}

class _SearchControls extends StatelessWidget {
  const _SearchControls({
    required this.filter,
    required this.sort,
    required this.resultCount,
    required this.hasQuery,
    required this.onFilter,
    required this.onSort,
  });

  final _SearchFilter filter;
  final _SearchSort sort;
  final int resultCount;
  final bool hasQuery;
  final ValueChanged<_SearchFilter> onFilter;
  final ValueChanged<_SearchSort> onSort;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _chip('All', _SearchFilter.all),
                const SizedBox(width: AppSpace.xs),
                _chip('Lessons', _SearchFilter.lesson),
                const SizedBox(width: AppSpace.xs),
                _chip('Notes', _SearchFilter.note),
                const SizedBox(width: AppSpace.xs),
                _chip('Bookmarks', _SearchFilter.bookmark),
              ],
            ),
          ),
        ),
        if (hasQuery) ...[
          const SizedBox(width: AppSpace.sm),
          Semantics(
            liveRegion: true,
            label: '$resultCount search results',
            child: StudyStatusBadge(
              label: '$resultCount ${resultCount == 1 ? 'result' : 'results'}',
              tone: StudyStatusTone.primary,
            ),
          ),
          const SizedBox(width: AppSpace.xs),
          PopupMenuButton<_SearchSort>(
            tooltip: 'Sort search results',
            initialValue: sort,
            onSelected: onSort,
            icon: const Icon(Icons.sort_rounded),
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: _SearchSort.recent,
                child: Text('Most recent'),
              ),
              PopupMenuItem(value: _SearchSort.title, child: Text('Title A–Z')),
            ],
          ),
        ],
      ],
    );
  }

  Widget _chip(String label, _SearchFilter value) => FilterChip(
    label: Text(label),
    selected: filter == value,
    onSelected: (_) => onFilter(value),
  );
}

class _SearchStartState extends StatelessWidget {
  const _SearchStartState();

  @override
  Widget build(BuildContext context) {
    return StudySurface(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(AppRadius.xl),
                ),
                child: Icon(
                  Icons.manage_search_rounded,
                  size: 34,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(height: AppSpace.lg),
              Text(
                'Everything is within reach',
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpace.xs),
              Text(
                'Search titles and filenames, the notes you wrote, and the bookmarks you saved.',
                style: Theme.of(context).textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpace.lg),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: AppSpace.xs,
                runSpacing: AppSpace.xs,
                children: const [
                  StudyStatusBadge(
                    label: 'Lessons',
                    icon: Icons.play_circle_outline_rounded,
                  ),
                  StudyStatusBadge(label: 'Notes', icon: Icons.notes_rounded),
                  StudyStatusBadge(
                    label: 'Bookmarks',
                    icon: Icons.bookmark_outline_rounded,
                  ),
                  StudyShortcutHint(keys: '/ to focus'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchResultRow extends StatelessWidget {
  const _SearchResultRow({required this.entry, required this.onTap});

  final GlobalSearchEntry entry;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final title = entry.kind == 'lesson'
        ? cleanDisplayTitle(entry.title)
        : entry.title;
    return Semantics(
      button: onTap != null,
      label: '${_typeLabel(entry.kind)} result, $title',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.sm),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              StudyArtwork(
                path: entry.item?.thumbnailPath,
                kind: entry.item?.itemType ?? entry.kind,
                unavailable: entry.item?.unavailable ?? false,
                size: 56,
              ),
              const SizedBox(width: AppSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        StudyStatusBadge(
                          label: _typeLabel(entry.kind),
                          icon: _kindIcon(entry.kind),
                          tone: _tone(entry.kind),
                        ),
                        if (entry.item?.unavailable == true) ...[
                          const SizedBox(width: AppSpace.xs),
                          const StudyStatusBadge(
                            label: 'Missing file',
                            icon: Icons.link_off_rounded,
                            tone: StudyStatusTone.error,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: AppSpace.xs),
                    Text(
                      title,
                      maxLines: entry.kind == 'note' ? 3 : 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppSpace.xxs),
                    StudyMeta(
                      items: [
                        cleanDisplayTitle(entry.libraryTitle),
                        cleanDisplayTitle(entry.sectionTitle),
                        if (entry.kind == 'lesson')
                          '${entry.progressPercent.toStringAsFixed(0)}% complete'
                        else
                          _location(entry),
                      ],
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpace.sm),
              Icon(
                onTap == null
                    ? Icons.block_rounded
                    : Icons.arrow_forward_rounded,
                color: onTap == null
                    ? context.studyColors.textMuted
                    : Theme.of(context).colorScheme.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _typeLabel(String kind) => switch (kind) {
    'note' => 'Note',
    'bookmark' => 'Bookmark',
    _ => 'Lesson',
  };

  static IconData _kindIcon(String kind) => switch (kind) {
    'note' => Icons.notes_rounded,
    'bookmark' => Icons.bookmark_rounded,
    _ => Icons.play_circle_outline_rounded,
  };

  static StudyStatusTone _tone(String kind) => switch (kind) {
    'note' => StudyStatusTone.info,
    'bookmark' => StudyStatusTone.warning,
    _ => StudyStatusTone.primary,
  };

  static String _location(GlobalSearchEntry entry) {
    if (entry.pageNumber != null) return 'Page ${entry.pageNumber}';
    final seconds = entry.positionSeconds;
    if (seconds == null) return 'General';
    final duration = Duration(seconds: seconds.round());
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final remainder = duration.inSeconds
        .remainder(60)
        .toString()
        .padLeft(2, '0');
    return duration.inHours > 0
        ? '${duration.inHours}:$minutes:$remainder'
        : '$minutes:$remainder';
  }
}
