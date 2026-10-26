import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers/app_providers.dart';
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
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      PopupMenuButton<BrowseSort>(
        tooltip: 'Sort titles and groups',
        initialValue: sort,
        onSelected: onSort,
        itemBuilder: (_) => [
          for (final value in BrowseSort.values)
            PopupMenuItem(value: value, child: Text(value.label)),
        ],
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.sort),
              const SizedBox(width: 8),
              Text(sort.label),
            ],
          ),
        ),
      ),
      IconButton(
        tooltip: 'Grid view',
        isSelected: grid,
        onPressed: () => onGrid(true),
        icon: const Icon(Icons.grid_view),
      ),
      IconButton(
        tooltip: 'List view',
        isSelected: !grid,
        onPressed: () => onGrid(false),
        icon: const Icon(Icons.view_list),
      ),
      FilterChip(
        label: const Text('Favorites'),
        avatar: const Icon(Icons.favorite_border, size: 18),
        selected: favorites,
        onSelected: onFavorites,
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
  Widget build(BuildContext context) => InputChip(
    label: Text(value == null ? 'Filter by tag' : 'Tag: $value'),
    avatar: const Icon(Icons.label_outline, size: 18),
    onDeleted: value == null ? null : () => onChanged(null),
    onPressed: () async {
      final result = await showModalBottomSheet<String>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => _TagPicker(libraryId: libraryId, category: category),
      );
      if (result != null) onChanged(result.isEmpty ? null : result);
    },
  );
}

class _TagPicker extends ConsumerStatefulWidget {
  const _TagPicker({this.libraryId, this.category});
  final String? libraryId, category;
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
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
    child: SizedBox(
      height: MediaQuery.sizeOf(context).height * .75,
      child: Column(
        children: [
          ListTile(
            title: const Text('Tags'),
            trailing: IconButton(
              tooltip: 'Close tags',
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close),
            ),
          ),
          ListTile(
            title: const Text('All tags'),
            onTap: () => Navigator.pop(context, ''),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _query,
              maxLength: 120,
              decoration: const InputDecoration(labelText: 'Find a tag'),
              onChanged: (_) => setState(() {
                _after = null;
                _history.clear();
                _page = _load();
              }),
            ),
          ),
          Expanded(
            child: FutureBuilder(
              future: _page,
              builder: (context, snapshot) {
                if (snapshot.hasError)
                  return const Center(
                    child: Text('Tags could not load. Close and try again.'),
                  );
                if (!snapshot.hasData)
                  return const Center(child: CircularProgressIndicator());
                final page = snapshot.data!;
                return ListView(
                  children: [
                    if (page.isEmpty)
                      const ListTile(
                        title: Text(
                          'No matching tags. Add tags from title details.',
                        ),
                      ),
                    for (final row in page.take(60))
                      ListTile(
                        title: Text(row.name),
                        trailing: Text('${row.count}'),
                        onTap: () => Navigator.pop(context, row.name),
                      ),
                    Wrap(
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
          ),
        ],
      ),
    ),
  );
}

Future<String?> chooseCatalogLibrary(
  BuildContext context, {
  bool allowAll = true,
}) => showModalBottomSheet<String>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (_) => _LibraryPicker(allowAll: allowAll),
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
    builder: (context, snapshot) => ActionChip(
      avatar: const Icon(Icons.folder_outlined, size: 18),
      label: Text(
        snapshot.data?.title ??
            (value == null ? 'All libraries' : 'Selected library'),
      ),
      onPressed: () async {
        final result = await chooseCatalogLibrary(context);
        if (result != null) onChanged(result.isEmpty ? null : result);
      },
    ),
  );
}

class _LibraryPicker extends ConsumerStatefulWidget {
  const _LibraryPicker({this.allowAll = true});
  final bool allowAll;
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
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
    child: SizedBox(
      height: MediaQuery.sizeOf(context).height * .75,
      child: Column(
        children: [
          ListTile(
            title: const Text('Source library'),
            trailing: IconButton(
              tooltip: 'Close libraries',
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close),
            ),
          ),
          if (widget.allowAll)
            ListTile(
              title: const Text('All libraries'),
              onTap: () => Navigator.pop(context, ''),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _query,
              maxLength: 200,
              decoration: const InputDecoration(labelText: 'Find a library'),
              onChanged: (_) => setState(() {
                _after = null;
                _history.clear();
                _page = _load();
              }),
            ),
          ),
          Expanded(
            child: FutureBuilder(
              future: _page,
              builder: (context, snapshot) {
                if (snapshot.hasError)
                  return const Center(
                    child: Text(
                      'Libraries could not load. Close and try again.',
                    ),
                  );
                if (!snapshot.hasData)
                  return const Center(child: CircularProgressIndicator());
                final rows = snapshot.data!;
                return ListView(
                  children: [
                    if (rows.isEmpty)
                      const ListTile(
                        title: Text(
                          'No matching libraries. Create a named library from Home first.',
                        ),
                      ),
                    for (final row in rows.take(50))
                      ListTile(
                        title: Text(row.data['title'] as String),
                        onTap: () =>
                            Navigator.pop(context, row.data['id'] as String),
                      ),
                    Wrap(
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
          ),
        ],
      ),
    ),
  );
}
