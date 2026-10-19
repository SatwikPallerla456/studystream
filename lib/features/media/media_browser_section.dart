import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/display_utils.dart';
import '../../data/db/app_database.dart';
import '../../data/providers/app_providers.dart';
import '../../shared/widgets/item_artwork.dart';
import '../../shared/widgets/cinematic_media.dart';

typedef MediaFilter = ({
  String kind,
  String query,
  String? afterTitle,
  String? afterId,
});
const _pageSize = 60;

final mediaCatalogueProvider = StreamProvider.autoDispose
    .family<List<Item>, MediaFilter>((ref, filter) {
      final db = ref.watch(appDatabaseProvider);
      final query = db.select(db.items)
        ..where((item) {
          var predicate = item.unavailable.not();
          if (filter.kind == 'video' || filter.kind == 'audio') {
            predicate = predicate & item.itemType.equals(filter.kind);
          } else if (filter.kind == 'documents') {
            predicate = predicate & item.itemType.isNotIn(['video', 'audio']);
          } else if (filter.kind == 'server') {
            predicate = predicate & item.filePath.like('remote:%');
          }
          if (filter.query.isNotEmpty) {
            predicate =
                predicate &
                (item.title.contains(filter.query) |
                    item.userTitle.contains(filter.query) |
                    item.filename.contains(filter.query));
          }
          if (filter.afterTitle != null && filter.afterId != null) {
            predicate =
                predicate &
                (item.title.isBiggerThanValue(filter.afterTitle!) |
                    (item.title.equals(filter.afterTitle!) &
                        item.id.isBiggerThanValue(filter.afterId!)));
          }
          return predicate;
        })
        ..orderBy([
          (item) => drift.OrderingTerm.asc(item.title),
          (item) => drift.OrderingTerm.asc(item.id),
        ])
        ..limit(_pageSize + 1);
      return query.watch();
    });

/// Tangerine's media-first browsing surface, shared by local and paired libraries.
class MediaBrowserSection extends ConsumerStatefulWidget {
  const MediaBrowserSection({super.key, required this.onOpenItem});
  final ValueChanged<Item> onOpenItem;

  @override
  ConsumerState<MediaBrowserSection> createState() =>
      _MediaBrowserSectionState();
}

class _MediaBrowserSectionState extends ConsumerState<MediaBrowserSection> {
  final _search = TextEditingController();
  String _kind = 'all';
  bool _grid = true;
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
        afterTitle: _cursors.lastOrNull?.$1,
        afterId: _cursors.lastOrNull?.$2,
      )),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: AppSpace.xs,
          runSpacing: AppSpace.xs,
          children: [
            for (final category in const [
              ('all', 'All media'),
              ('video', 'Videos'),
              ('audio', 'Music'),
              ('documents', 'Documents'),
              ('server', 'From server'),
            ])
              ChoiceChip(
                label: Text(category.$2),
                selected: _kind == category.$1,
                onSelected: (_) => setState(() {
                  _kind = category.$1;
                  _reset();
                }),
              ),
          ],
        ),
        const SizedBox(height: AppSpace.md),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _search,
                onChanged: (_) => setState(_reset),
                decoration: InputDecoration(
                  hintText: 'Search your media',
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
            const SizedBox(width: AppSpace.xs),
            IconButton(
              tooltip: 'Media grid',
              isSelected: _grid,
              onPressed: () => setState(() => _grid = true),
              icon: const Icon(Icons.grid_view_rounded),
            ),
            IconButton(
              tooltip: 'Media list',
              isSelected: !_grid,
              onPressed: () => setState(() => _grid = false),
              icon: const Icon(Icons.view_list_rounded),
            ),
          ],
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
            final items = page.take(_pageSize).toList();
            final hasMore = page.length > _pageSize;
            if (items.isEmpty && _cursors.isNotEmpty) {
              return TextButton(
                onPressed: () => setState(_reset),
                child: const Text('Return to the first page'),
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
                        _search.text.isNotEmpty
                            ? 'No matching media. Try another title.'
                            : _kind == 'server'
                            ? 'Pair a server in Network to browse its media here.'
                            : 'Add files, add a folder, or connect to a server to fill your library.',
                      ),
                    ),
                  ],
                ),
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Page ${_cursors.length + 1} · ${items.length} items · ${_kind == 'all' ? 'All libraries' : 'Filtered library'}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: AppSpace.sm),
                if (_grid)
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final columns = (constraints.maxWidth / 235)
                          .floor()
                          .clamp(1, 5);
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
                                  width * 1.25 +
                                  MediaQuery.textScalerOf(context).scale(72),
                              child: CinematicMediaCard(
                                item: item,
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
                                items.last.title,
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
