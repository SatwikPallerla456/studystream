import 'dart:math' as math;

import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../data/providers/app_providers.dart';
import 'tangerine_controls.dart';
import '../../domain/catalog/browse_options.dart';
import '../../domain/catalog/catalog_discovery_repository.dart';

class CatalogBrowseControls extends StatelessWidget {
  const CatalogBrowseControls({
    super.key,
    required this.sort,
    required this.grid,
    required this.favorites,
    required this.tag,
    required this.onSort,
    required this.onGrid,
    required this.onFavorites,
    required this.onTag,
    this.libraryId,
    this.category,
  });
  final BrowseSort sort;
  final bool grid, favorites;
  final String? tag, libraryId, category;
  final ValueChanged<BrowseSort> onSort;
  final ValueChanged<bool> onGrid, onFavorites;
  final ValueChanged<String?> onTag;
  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 8,
    crossAxisAlignment: WrapCrossAlignment.start,
    children: [
      ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: TangerineChoicePicker<BrowseSort>(
          value: sort,
          label: 'Sort',
          icon: Icons.sort,
          choices: [
            for (final value in BrowseSort.values)
              TangerineChoice(value: value, label: value.label),
          ],
          onChanged: onSort,
        ),
      ),
      TangerineSegments<bool>(
        label: 'View',
        value: grid,
        choices: const [
          TangerineChoice(value: true, label: 'Grid', icon: Icons.grid_view),
          TangerineChoice(value: false, label: 'List', icon: Icons.view_list),
        ],
        onChanged: onGrid,
      ),
      TangerineInteraction(
        child: FilterChip(
          label: const Text('Favorites'),
          avatar: const Icon(Icons.favorite_border, size: 18),
          selected: favorites,
          onSelected: onFavorites,
        ),
      ),
      CatalogTagFilter(
        value: tag,
        libraryId: libraryId,
        category: category,
        onChanged: onTag,
      ),
    ],
  );
}

class CatalogTagFilter extends StatelessWidget {
  const CatalogTagFilter({
    super.key,
    this.value,
    this.libraryId,
    this.category,
    required this.onChanged,
  });
  final String? value, libraryId, category;
  final ValueChanged<String?> onChanged;
  @override
  Widget build(BuildContext context) => Wrap(
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      TangerineInteraction(
        child: TextButton.icon(
          icon: const Icon(Icons.label_outline, size: 20),
          label: Text(value == null ? 'Tags' : 'Tag: $value'),
          onPressed: () async {
            final result = await showModalBottomSheet<String>(
              context: context,
              isScrollControlled: true,
              useSafeArea: true,
              showDragHandle: true,
              sheetAnimationStyle: _pickerMotion(context),
              builder: (_) => _TagPicker(
                libraryId: libraryId,
                category: category,
                selected: value,
              ),
            );
            if (context.mounted && result != null)
              onChanged(result.isEmpty ? null : result);
          },
        ),
      ),
      if (value != null)
        TangerineInteraction(
          child: IconButton(
            tooltip: 'Clear tag filter',
            onPressed: () => onChanged(null),
            icon: const Icon(Icons.close, size: 18),
          ),
        ),
    ],
  );
}

class _TagPicker extends ConsumerStatefulWidget {
  const _TagPicker({this.libraryId, this.category, this.selected});
  final String? libraryId, category, selected;
  @override
  ConsumerState<_TagPicker> createState() => _TagPickerState();
}

class _TagPickerState extends ConsumerState<_TagPicker> {
  final _query = TextEditingController();
  String? _after;
  final _history = <String?>[];
  late Future<List<({String name, int count})>> _page = _load();
  Future<List<({String name, int count})>> _load() =>
      CatalogDiscoveryRepository(ref.read(appDatabaseProvider)).tags(
        libraryId: widget.libraryId,
        category: widget.category,
        query: _query.text.trim(),
        after: _after,
      );
  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _CatalogPickerSurface(
    title: 'Filter by tag',
    description:
        'Choose a tag from this selection. Manage tags from title details.',
    query: TextField(
      controller: _query,
      maxLength: 120,
      decoration: const InputDecoration(
        labelText: 'Find a tag',
        prefixIcon: Icon(Icons.search),
      ),
      onChanged: (_) => setState(() {
        _after = null;
        _history.clear();
        _page = _load();
      }),
    ),
    allChoice: _CatalogPickerRow(
      title: 'All tags',
      icon: Icons.label_outline,
      selected: widget.selected == null,
      onTap: () => Navigator.pop(context, ''),
    ),
    results: FutureBuilder(
      future: _page,
      builder: (context, snapshot) {
        if (snapshot.hasError)
          return const SliverToBoxAdapter(
            child: _PickerMessage('Tags could not load. Close and try again.'),
          );
        if (!snapshot.hasData)
          return const SliverToBoxAdapter(child: LinearProgressIndicator());
        final page = snapshot.data!;
        return SliverList.list(
          children: [
            if (page.isEmpty)
              const _PickerMessage(
                'No matching tags. Add tags from title details.',
              ),
            for (final row in page.take(60))
              _CatalogPickerRow(
                title: row.name,
                icon: Icons.label_outline,
                selected: row.name == widget.selected,
                detail: '${row.count}',
                onTap: () => Navigator.pop(context, row.name),
              ),
            if (_history.isNotEmpty || page.length > 60)
              Wrap(
                spacing: 12,
                children: [
                  TextButton(
                    onPressed: _history.isEmpty
                        ? null
                        : () => setState(() {
                            _after = _history.removeLast();
                            _page = _load();
                          }),
                    child: const Text('Previous'),
                  ),
                  TextButton(
                    onPressed: page.length <= 60
                        ? null
                        : () => setState(() {
                            _history.add(_after);
                            _after = page[59].name;
                            _page = _load();
                          }),
                    child: const Text('Next'),
                  ),
                ],
              ),
          ],
        );
      },
    ),
  );
}

Future<String?> chooseCatalogLibrary(
  BuildContext context, {
  bool allowAll = true,
  String? selectedLibrary,
}) => showModalBottomSheet<String>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  sheetAnimationStyle: _pickerMotion(context),
  builder: (_) => _LibraryPicker(allowAll: allowAll, selected: selectedLibrary),
);

class CatalogLibraryFilter extends ConsumerWidget {
  const CatalogLibraryFilter({
    super.key,
    required this.value,
    required this.onChanged,
  });
  final String? value;
  final ValueChanged<String?> onChanged;
  @override
  Widget build(BuildContext context, WidgetRef ref) => FutureBuilder(
    key: ValueKey(value),
    future: value == null
        ? null
        : ref.read(appDatabaseProvider).getLibraryById(value!),
    builder: (context, snapshot) => TangerineInteraction(
      child: TextButton.icon(
        icon: const Icon(Icons.folder_outlined, size: 20),
        label: Text(
          snapshot.data?.title ??
              (value == null ? 'All libraries' : 'Selected library'),
        ),
        onPressed: () async {
          final result = await chooseCatalogLibrary(
            context,
            selectedLibrary: value,
          );
          if (context.mounted && result != null)
            onChanged(result.isEmpty ? null : result);
        },
      ),
    ),
  );
}

class _LibraryPicker extends ConsumerStatefulWidget {
  const _LibraryPicker({this.allowAll = true, this.selected});
  final bool allowAll;
  final String? selected;
  @override
  ConsumerState<_LibraryPicker> createState() => _LibraryPickerState();
}

class _LibraryPickerState extends ConsumerState<_LibraryPicker> {
  final _query = TextEditingController();
  (String, String)? _after;
  final _history = <(String, String)?>[];
  late Future<List<drift.QueryRow>> _page = _load();
  Future<List<drift.QueryRow>> _load() => ref
      .read(appDatabaseProvider)
      .customSelect(
        '''SELECT id,title,lower(title) AS sort_title FROM libraries WHERE instr(lower(title),lower(?))>0
    ${_after == null ? '' : 'AND (lower(title),id)>(?,?)'} ORDER BY lower(title),id LIMIT 51''',
        variables: [
          drift.Variable(_query.text.trim()),
          if (_after != null) ...[
            drift.Variable(_after!.$1),
            drift.Variable(_after!.$2),
          ],
        ],
      )
      .get();
  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _CatalogPickerSurface(
    title: widget.allowAll ? 'Browse a library' : 'Choose a source library',
    description: widget.allowAll
        ? 'Keep every library in view, or focus on one.'
        : 'Collections belong to a named library. Choose where to create yours.',
    query: TextField(
      controller: _query,
      maxLength: 200,
      decoration: const InputDecoration(
        labelText: 'Find a library',
        prefixIcon: Icon(Icons.search),
      ),
      onChanged: (_) => setState(() {
        _after = null;
        _history.clear();
        _page = _load();
      }),
    ),
    allChoice: widget.allowAll
        ? _CatalogPickerRow(
            title: 'All libraries',
            icon: Icons.video_library_outlined,
            selected: widget.selected == null,
            onTap: () => Navigator.pop(context, ''),
          )
        : null,
    results: FutureBuilder(
      future: _page,
      builder: (context, snapshot) {
        if (snapshot.hasError)
          return const SliverToBoxAdapter(
            child: _PickerMessage(
              'Libraries could not load. Close and try again.',
            ),
          );
        if (!snapshot.hasData)
          return const SliverToBoxAdapter(child: LinearProgressIndicator());
        final rows = snapshot.data!;
        return SliverList.list(
          children: [
            if (rows.isEmpty)
              const _PickerMessage(
                'No matching libraries. Create a named library from Home first.',
              ),
            for (final row in rows.take(50))
              _CatalogPickerRow(
                title: row.data['title'] as String,
                icon: Icons.folder_outlined,
                selected: row.data['id'] == widget.selected,
                onTap: () => Navigator.pop(context, row.data['id'] as String),
              ),
            if (_history.isNotEmpty || rows.length > 50)
              Wrap(
                spacing: 12,
                children: [
                  TextButton(
                    onPressed: _history.isEmpty
                        ? null
                        : () => setState(() {
                            _after = _history.removeLast();
                            _page = _load();
                          }),
                    child: const Text('Previous'),
                  ),
                  TextButton(
                    onPressed: rows.length <= 50
                        ? null
                        : () => setState(() {
                            _history.add(_after);
                            _after = (
                              rows[49].data['sort_title'] as String,
                              rows[49].data['id'] as String,
                            );
                            _page = _load();
                          }),
                    child: const Text('Next'),
                  ),
                ],
              ),
          ],
        );
      },
    ),
  );
}

AnimationStyle _pickerMotion(BuildContext context) => AnimationStyle(
  duration: AppMotion.resolve(context, AppMotion.emphasized),
  reverseDuration: AppMotion.resolve(context, AppMotion.standard),
);

/// One bounded scroll owner keeps the heading, search and choices reachable
/// together when a software keyboard or large text shortens the sheet.
class _CatalogPickerSurface extends StatelessWidget {
  const _CatalogPickerSurface({
    required this.title,
    required this.description,
    required this.query,
    required this.results,
    this.allChoice,
  });
  final String title, description;
  final Widget query, results;
  final Widget? allChoice;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final inset = MediaQuery.viewInsetsOf(context).bottom;
      final maximum = box.maxHeight.isFinite
          ? box.maxHeight
          : MediaQuery.sizeOf(context).height;
      return AnimatedPadding(
        duration: AppMotion.resolve(context, AppMotion.standard),
        curve: AppMotion.settle,
        padding: EdgeInsets.only(bottom: inset),
        child: SizedBox(
          height: math.max(0, maximum - inset) * .85,
          child: CustomScrollView(
            primary: false,
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                          ),
                          TangerineInteraction(
                            child: IconButton(
                              tooltip: 'Close picker',
                              onPressed: () => Navigator.pop(context),
                              icon: const Icon(Icons.close),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        description,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 20),
                      query,
                      if (allChoice != null) ...[
                        const SizedBox(height: 8),
                        allChoice!,
                      ],
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                sliver: results,
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _CatalogPickerRow extends StatelessWidget {
  const _CatalogPickerRow({
    required this.title,
    required this.icon,
    required this.selected,
    required this.onTap,
    this.detail,
  });
  final String title;
  final String? detail;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Semantics(
    selected: selected,
    inMutuallyExclusiveGroup: true,
    child: TangerineInteraction(
      lift: 1,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Material(
          color: selected
              ? Theme.of(
                  context,
                ).colorScheme.primaryContainer.withValues(alpha: .5)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
          child: ListTile(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            minVerticalPadding: 14,
            leading: Icon(icon),
            title: Text(title),
            trailing: !selected && detail == null
                ? null
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (detail != null) Text(detail!),
                      if (detail != null && selected) const SizedBox(width: 8),
                      if (selected) const Icon(Icons.check_rounded),
                    ],
                  ),
            onTap: onTap,
          ),
        ),
      ),
    ),
  );
}

class _PickerMessage extends StatelessWidget {
  const _PickerMessage(this.message);
  final String message;
  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Text(message, style: Theme.of(context).textTheme.bodyLarge),
    ),
  );
}
