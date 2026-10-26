import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/display_utils.dart';
import '../../data/db/app_database.dart';
import '../../data/providers/app_providers.dart';
import '../../domain/catalog/media_catalog_repository.dart';
import '../../domain/catalog/browse_options.dart';
import '../../shared/widgets/catalog_browse_controls.dart';
import '../../shared/widgets/item_artwork.dart';
import '../../shared/widgets/cinematic_media.dart';

typedef MediaFilter = ({
  String kind,
  String query,
  String? libraryId,
  String? afterTitle,
  String? afterId,
  BrowseSort sort,
  bool favorites,
  String? tag,
});
const _pageSize = 60;

final mediaCatalogueProvider = StreamProvider.autoDispose
    .family<List<({Item item, String sortKey})>, MediaFilter>((ref, filter) {
      final db = ref.watch(appDatabaseProvider);
      final clauses = <String>['i.unavailable=0'];
      final values = <drift.Variable>[];
      if (filter.libraryId != null) {
        clauses.add('i.library_id=?');
        values.add(drift.Variable(filter.libraryId!));
      }
      if (filter.kind == 'server') {
        clauses.add("i.file_path LIKE 'remote:%'");
      } else if (filter.kind != 'all') {
        clauses.add(
          "EXISTS(SELECT 1 FROM catalog_facets category WHERE category.item_id=i.id AND category.field='category' AND category.value=?)",
        );
        values.add(drift.Variable(filter.kind));
      }
      if (filter.query.isNotEmpty) {
        // Quote tokens as literals, never accept FTS operators from user input.
        final terms = filter.query
            .trim()
            .split(RegExp(r'\s+'))
            .take(8)
            .map((term) => '"${term.replaceAll('"', '""')}"*')
            .join(' AND ');
        clauses.add(
          'i.id IN (SELECT item_id FROM catalog_search WHERE catalog_search MATCH ?)',
        );
        values.add(drift.Variable(terms));
      }
      final org = organizationWhere(
        favorites: filter.favorites,
        tag: filter.tag,
      );
      clauses.addAll(org.sql);
      values.addAll(org.values);
      final sort = browseItemOrder(filter.sort);
      final descending = filter.sort == BrowseSort.titleDescending;
      if (filter.afterTitle != null && filter.afterId != null) {
        clauses.add('($sort,i.id)${descending ? '<' : '>'}(?,?)');
        values.addAll([
          drift.Variable(filter.afterTitle!),
          drift.Variable(filter.afterId!),
        ]);
      }
      return db
          .customSelect(
            'SELECT i.*, COALESCE(s.title,i.user_title,i.title) AS catalog_title,$sort AS sort_key FROM items i LEFT JOIN catalog_search s ON s.item_id=i.id LEFT JOIN playback_progress p ON p.item_id=i.id LEFT JOIN reading_progress r ON r.item_id=i.id WHERE ${clauses.join(' AND ')} ORDER BY $sort ${descending ? 'DESC' : 'ASC'},i.id ${descending ? 'DESC' : 'ASC'} LIMIT ${_pageSize + 1}',
            variables: values,
            readsFrom: {
              db.items,
              db.libraries,
              db.appSettings,
              db.playbackProgress,
              db.readingProgress,
            },
          )
          .watch()
          .map(
            (rows) => rows
                .map(
                  (row) => (
                    item: db.items.map({
                      ...row.data,
                      'title': row.data['catalog_title'],
                    }),
                    sortKey: row.data['sort_key'] as String,
                  ),
                )
                .toList(),
          );
    });

/// Tangerine's media-first browsing surface, shared by local and paired libraries.
class MediaBrowserSection extends ConsumerStatefulWidget {
  const MediaBrowserSection({
    super.key,
    required this.onOpenItem,
    this.initialLibraryId,
    this.initialKind = 'all',
    this.lockCategory = false,
    this.emptyAction,
    this.emptyIcon,
  });
  final String? initialLibraryId;
  final String initialKind;
  final bool lockCategory;
  final Widget? emptyAction;
  final IconData? emptyIcon;
  final ValueChanged<Item> onOpenItem;

  @override
  ConsumerState<MediaBrowserSection> createState() =>
      _MediaBrowserSectionState();
}

class _MediaBrowserSectionState extends ConsumerState<MediaBrowserSection> {
  final _search = TextEditingController();
  late String _kind = widget.initialKind;
  late String? _libraryId = widget.initialLibraryId;
  bool _grid = true, _favorites = false;
  BrowseSort _sort = BrowseSort.natural;
  String? _tag;
  final _cursors = <(String, String)>[];
  void _reset() => _cursors.clear();
  void _details(Item item) =>
      context.push('/details/${Uri.encodeComponent(item.id)}');

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final catalogue = ref.watch(
      mediaCatalogueProvider((
        kind: _kind,
        query: _search.text.trim(),
        libraryId: _libraryId,
        afterTitle: _cursors.lastOrNull?.$1,
        afterId: _cursors.lastOrNull?.$2,
        sort: _sort,
        favorites: _favorites,
        tag: _tag,
      )),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.initialLibraryId == null && !widget.lockCategory) ...[
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              if (!widget.lockCategory)
                SizedBox(
                  width: 230,
                  child: DropdownButtonFormField<String>(
                    initialValue: _kind,
                    decoration: const InputDecoration(
                      labelText: 'Library type',
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: 'all',
                        child: Text('All types'),
                      ),
                      for (final kind in LibraryKind.values)
                        DropdownMenuItem(
                          value: kind.name,
                          child: Text(kind.label),
                        ),
                      const DropdownMenuItem(
                        value: 'server',
                        child: Text('From server'),
                      ),
                    ],
                    onChanged: (value) => setState(() {
                      _kind = value ?? 'all';
                      _reset();
                    }),
                  ),
                ),
              CatalogLibraryFilter(
                value: _libraryId,
                onChanged: (value) => setState(() {
                  _libraryId = value;
                  _reset();
                }),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.md),
        ],
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _search,
                onChanged: (_) => setState(_reset),
                decoration: InputDecoration(
                  hintText: widget.lockCategory
                      ? 'Search ${LibraryKind.values.firstWhere((kind) => kind.name == _kind).label.toLowerCase()}'
                      : 'Search your media',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _search.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Clear media search',
                          onPressed: () => setState(() {
                            _search.clear();
                            _reset();
                          }),
                          icon: const Icon(Icons.close_rounded),
                        ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpace.sm),
        CatalogBrowseControls(
          sort: _sort,
          grid: _grid,
          favorites: _favorites,
          tag: _tag,
          libraryId: _libraryId,
          category: {'all', 'server'}.contains(_kind) ? null : _kind,
          onSort: (value) => setState(() {
            _sort = value;
            _reset();
          }),
          onGrid: (value) => setState(() => _grid = value),
          onFavorites: (value) => setState(() {
            _favorites = value;
            _reset();
          }),
          onTag: (value) => setState(() {
            _tag = value;
            _reset();
          }),
        ),
        const SizedBox(height: AppSpace.md),
        catalogue.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(AppSpace.md),
            child: LinearProgressIndicator(),
          ),
          error: (_, _) => const Text(
            'The media catalogue could not be loaded. Reopen the app to try again.',
          ),
          data: (page) {
            final items = page
                .take(_pageSize)
                .map((entry) => entry.item)
                .toList();
            final hasMore = page.length > _pageSize;
            if (items.isEmpty && _cursors.isNotEmpty) {
              return TextButton(
                onPressed: () => setState(_reset),
                child: const Text('Return to the first page'),
              );
            }
            if (items.isEmpty &&
                widget.emptyAction != null &&
                _search.text.isEmpty &&
                !_favorites &&
                _tag == null) {
              final name = LibraryKind.values
                  .firstWhere((kind) => kind.name == _kind)
                  .label
                  .toLowerCase();
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      widget.emptyIcon ?? Icons.folder_outlined,
                      size: 48,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No $name yet',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Add a source folder to scan and organise this collection.',
                    ),
                    const SizedBox(height: 16),
                    widget.emptyAction!,
                  ],
                ),
              );
            }
            if (items.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpace.lg),
                child: Row(
                  children: [
                    Icon(
                      Icons.video_library_outlined,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: AppSpace.sm),
                    Expanded(
                      child: Text(
                        _favorites || _tag != null
                            ? 'No titles match these favorites/tag filters. Clear a filter or choose another tag.'
                            : _search.text.isNotEmpty
                            ? 'No matching media. Try another title.'
                            : _kind == 'server'
                            ? 'Pair a server in Network to browse its media here.'
                            : _kind != 'all'
                            ? 'No ${LibraryKind.values.firstWhere((kind) => kind.name == _kind, orElse: () => LibraryKind.mixed).label.toLowerCase()} titles yet. Add a library or review local identification.'
                            : 'Add files, add a folder, or connect to a server to fill your library.',
                      ),
                    ),
                    if (_favorites || _tag != null)
                      TextButton(
                        onPressed: () => setState(() {
                          _favorites = false;
                          _tag = null;
                          _reset();
                        }),
                        child: const Text('Clear filters'),
                      ),
                  ],
                ),
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${items.length} ${items.length == 1 ? 'title' : 'titles'}${_cursors.isEmpty ? '' : ' · Page ${_cursors.length + 1}'}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: AppSpace.sm),
                if (_grid)
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final columns = (constraints.maxWidth / 180)
                          .floor()
                          .clamp(constraints.maxWidth >= 300 ? 2 : 1, 6);
                      final width =
                          (constraints.maxWidth - (columns - 1) * AppSpace.md) /
                          columns;
                      return Wrap(
                        spacing: AppSpace.md,
                        runSpacing: AppSpace.md,
                        children: [
                          for (final item in items)
                            SizedBox(
                              width: width,
                              height:
                                  width *
                                      ({
                                            'music',
                                            'audiobooks',
                                            'podcasts',
                                            'photos',
                                            'homeVideos',
                                            'musicVideos',
                                          }.contains(_kind)
                                          ? 1
                                          : 1.25) +
                                  MediaQuery.textScalerOf(context).scale(72),
                              child: CinematicMediaCard(
                                item: item,
                                subtitle:
                                    items
                                            .where(
                                              (other) =>
                                                  (other.userTitle ??
                                                      other.title) ==
                                                  (item.userTitle ??
                                                      item.title),
                                            )
                                            .length >
                                        1
                                    ? 'File ${items.indexOf(item) + 1}'
                                    : null,
                                onDetails: () => _details(item),
                                onOpen: () => widget.onOpenItem(item),
                              ),
                            ),
                        ],
                      );
                    },
                  )
                else ...[
                  for (final item in items)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: ItemArtwork(item: item, size: 52),
                      title: Text(
                        cleanDisplayTitle(item.userTitle ?? item.title),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        '${item.itemType.toUpperCase()} · ${item.filePath.startsWith('remote:') ? 'Server' : 'Local'}',
                      ),
                      trailing: IconButton(
                        tooltip: MediaVisuals.action(item),
                        icon: Icon(
                          MediaVisuals.isReading(item)
                              ? Icons.menu_book
                              : Icons.play_circle_outline_rounded,
                        ),
                        onPressed: () => widget.onOpenItem(item),
                      ),
                      onTap: () => _details(item),
                    ),
                ],
                const SizedBox(height: AppSpace.md),
                if (hasMore || _cursors.isNotEmpty)
                  Wrap(
                    spacing: AppSpace.sm,
                    runSpacing: AppSpace.sm,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _cursors.isEmpty
                            ? null
                            : () => setState(() => _cursors.removeLast()),
                        icon: const Icon(Icons.chevron_left),
                        label: const Text('Previous page'),
                      ),
                      OutlinedButton.icon(
                        onPressed: !hasMore
                            ? null
                            : () => setState(
                                () => _cursors.add((
                                  page.take(_pageSize).last.sortKey,
                                  items.last.id,
                                )),
                              ),
                        icon: const Icon(Icons.chevron_right),
                        label: const Text('Next page'),
                      ),
                      if (_cursors.isNotEmpty)
                        TextButton(
                          onPressed: () => setState(_reset),
                          child: const Text('Start over'),
                        ),
                    ],
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}
