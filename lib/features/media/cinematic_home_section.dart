import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../data/db/app_database.dart';
import '../../data/providers/app_providers.dart';
import '../../shared/widgets/cinematic_media.dart';
import '../../domain/catalog/media_catalog_repository.dart';
import '../library/collection_details_screen.dart';
import '../library/collections_screen.dart';

// Keep the existing query boundary for callers that need recent files by kind.
final recentlyAddedMediaProvider = StreamProvider.autoDispose
    .family<List<Item>, String>((ref, kind) {
      final db = ref.watch(appDatabaseProvider);
      final query = db.select(db.items)
        ..where(
          (item) =>
              item.unavailable.not() &
              (kind == 'all'
                  ? const drift.Constant(true)
                  : kind == 'reading'
                  ? item.itemType.isNotIn(['video', 'audio', 'image'])
                  : item.itemType.equals(kind)),
        )
        ..orderBy([
          (item) => drift.OrderingTerm.desc(item.createdAt),
          (item) => drift.OrderingTerm.asc(item.id),
        ])
        ..limit(12);
      return query.watch();
    });

class _HomeTitle {
  const _HomeTitle(this.item, this.title, this.progress);
  final Item item;
  final String title;
  final double? progress;
}

final _homeTitles = StreamProvider.autoDispose.family<List<_HomeTitle>, String>((
  ref,
  shelf,
) {
  final db = ref.watch(appDatabaseProvider);
  final continuing = shelf != 'recent';
  final type = switch (shelf) {
    'watching' => "i.item_type='video'",
    'listening' => "i.item_type='audio'",
    'reading' => "i.item_type NOT IN ('audio','video','image')",
    _ => '1=1',
  };
  const active =
      "CASE WHEN i.item_type IN ('audio','video') THEN COALESCE(p.completed,0)=0 AND (COALESCE(p.last_position_seconds,0)>0 OR COALESCE(p.last_opened_at,0)>0) ELSE COALESCE(r.completed,0)=0 AND (COALESCE(r.last_opened_at,0)>0 OR COALESCE(r.last_page,1)>1 OR COALESCE(r.last_scroll_offset,0)>0 OR COALESCE((SELECT CASE WHEN json_valid(json_extract(m.payload,'\$.locator')) THEN json_extract(json_extract(m.payload,'\$.locator'),'\$.textOffset') ELSE 0 END FROM media_records m WHERE m.id='reader:'||i.id AND m.deleted=0),0)>0) END";
  return db
      .customSelect(
        '''SELECT i.*,COALESCE(s.title,i.user_title,i.title) AS display_title,
    CASE WHEN i.item_type IN ('audio','video') THEN p.percent_watched ELSE r.percent_read END AS progress
    FROM items i LEFT JOIN catalog_search s ON s.item_id=i.id
    LEFT JOIN playback_progress p ON p.item_id=i.id LEFT JOIN reading_progress r ON r.item_id=i.id
    WHERE i.unavailable=0 AND $type ${continuing ? 'AND ($active)' : ''}
    ORDER BY ${continuing ? 'MAX(COALESCE(p.last_opened_at,0),COALESCE(r.last_opened_at,0)) DESC' : 'i.created_at DESC'},i.id LIMIT 12''',
        readsFrom: {
          db.items,
          db.playbackProgress,
          db.readingProgress,
          db.appSettings,
        },
      )
      .watch()
      .map(
        (rows) => [
          for (final row in rows)
            _HomeTitle(
              db.items.map(row.data),
              row.data['display_title'] as String,
              (row.data['progress'] as num?)?.toDouble(),
            ),
        ],
      );
});

class _HomeCollection {
  const _HomeCollection(this.record, this.library, this.cover);
  final MediaRecord record;
  final String library;
  final Item? cover;
}

final _homeCollections = StreamProvider.autoDispose<List<_HomeCollection>>((
  ref,
) {
  final db = ref.watch(appDatabaseProvider);
  return db
      .customSelect(
        '''SELECT c.*,l.title AS library_title,
    (SELECT m.item_id FROM catalog_memberships m JOIN items i ON i.id=m.item_id AND i.library_id=c.library_id
      WHERE m.collection_id=c.id AND m.library_id=c.library_id AND m.deleted=0 AND i.unavailable=0 ORDER BY m.position,m.item_id LIMIT 1) AS cover_id
    FROM media_records c JOIN libraries l ON l.id=c.library_id
    WHERE c.deleted=0 AND c.kind IN ('collection','album') ORDER BY c.updated_at DESC,c.id LIMIT 12''',
        readsFrom: {db.items, db.libraries, db.appSettings},
      )
      .watch()
      .asyncMap((rows) async {
        final result = <_HomeCollection>[];
        for (final row in rows) {
          final coverId = row.data['cover_id'] as String?;
          result.add(
            _HomeCollection(
              MediaRecord(row.data),
              row.data['library_title'] as String,
              coverId == null ? null : await db.getItemById(coverId),
            ),
          );
        }
        return result;
      });
});

/// Independent bounded shelves prevent one medium from crowding out another.
class CinematicHomeSection extends ConsumerWidget {
  const CinematicHomeSection({super.key, required this.onOpen});
  final ValueChanged<Item> onOpen;
  @override
  Widget build(BuildContext context, WidgetRef ref) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (final shelf in ['watching', 'reading', 'listening', 'recent'])
        ref
            .watch(_homeTitles(shelf))
            .when(
              loading: () => const SizedBox.shrink(),
              error: (_, _) => Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpace.md),
                child: Text(
                  shelf != 'recent'
                      ? 'Recent activity could not load.'
                      : 'Recently added titles could not load.',
                ),
              ),
              data: (titles) => titles.isEmpty
                  ? const SizedBox.shrink()
                  : Padding(
                      padding: const EdgeInsets.only(bottom: AppSpace.xl),
                      child: shelf != 'recent'
                          ? _ResumeShelf(
                              title: switch (shelf) {
                                'watching' => 'Continue Watching',
                                'reading' => 'Continue Reading',
                                _ => 'Continue Listening',
                              },
                              titles: titles,
                              onOpen: onOpen,
                            )
                          : CinematicMediaRow(
                              compact: true,
                              title: 'Recently added',
                              items: titles.map((entry) => entry.item).toList(),
                              displayTitles: {
                                for (final entry in titles)
                                  entry.item.id: entry.title,
                              },
                              progress: {
                                for (final entry in titles)
                                  if (entry.progress != null)
                                    entry.item.id: entry.progress!,
                              },
                              onDetails: (item) => context.push(
                                '/details/${Uri.encodeComponent(item.id)}',
                              ),
                              onOpen: onOpen,
                            ),
                    ),
            ),
      ref
          .watch(_homeCollections)
          .when(
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const Text('Collections could not load.'),
            data: (collections) => collections.isEmpty
                ? Padding(
                    padding: const EdgeInsets.only(bottom: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Collections & albums',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const Text(
                          'Group titles or arrange a photo album from a named library.',
                        ),
                        TextButton.icon(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) => const CollectionsScreen(),
                            ),
                          ),
                          icon: const Icon(Icons.add),
                          label: const Text('Create a collection'),
                        ),
                      ],
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Collections & albums',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          ),
                          TextButton(
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute<void>(
                                builder: (_) => const CollectionsScreen(),
                              ),
                            ),
                            child: const Text('View all'),
                          ),
                        ],
                      ),
                      SizedBox(
                        height: 290,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: collections.length,
                          separatorBuilder: (_, _) => const SizedBox(width: 12),
                          itemBuilder: (context, index) {
                            final collection = collections[index],
                                record = collections[index].record;
                            return SizedBox(
                              width: 200,
                              child: Card(
                                clipBehavior: Clip.antiAlias,
                                child: InkWell(
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute<void>(
                                      builder: (_) => CollectionDetailsScreen(
                                        collectionId: record.id,
                                        onEdit: () => editCatalogCollection(
                                          context,
                                          libraryId: record.libraryId,
                                          record: record,
                                        ),
                                      ),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: SizedBox(
                                          width: double.infinity,
                                          child: collection.cover == null
                                              ? const Center(
                                                  child: Icon(
                                                    Icons
                                                        .collections_bookmark_outlined,
                                                    size: 48,
                                                  ),
                                                )
                                              : CinematicArtwork(
                                                  item: collection.cover!,
                                                ),
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.all(12),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              record.data['title'] as String,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: Theme.of(
                                                context,
                                              ).textTheme.titleMedium,
                                            ),
                                            Text(
                                              collection.library,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            Text(
                                              '${(record.data['items'] as List).length} members · ${record.kind == 'album' ? 'Ordered album' : 'Collection'}',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
          ),
    ],
  );
}

class _ResumeShelf extends StatelessWidget {
  const _ResumeShelf({
    required this.title,
    required this.titles,
    required this.onOpen,
  });
  final String title;
  final List<_HomeTitle> titles;
  final ValueChanged<Item> onOpen;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 12),
      SizedBox(
        height:
            152 *
            (MediaQuery.textScalerOf(context).scale(14) / 14).clamp(1, 1.8),
        child: LayoutBuilder(
          builder: (context, box) => ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: titles.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final entry = titles[index];
              return SizedBox(
                width: box.maxWidth.clamp(240, 380),
                child: Card(
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => context.push(
                      '/details/${Uri.encodeComponent(entry.item.id)}',
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 92,
                          child: CinematicArtwork(item: entry.item),
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  entry.title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                                const SizedBox(height: 8),
                                if (entry.progress != null)
                                  LinearProgressIndicator(
                                    value: (entry.progress! / 100).clamp(0, 1),
                                    semanticsLabel:
                                        '${entry.progress!.round()} percent complete',
                                  ),
                                const SizedBox(height: 4),
                                TextButton.icon(
                                  onPressed: () => onOpen(entry.item),
                                  icon: const Icon(Icons.play_arrow),
                                  label: Text(
                                    MediaVisuals.isReading(entry.item)
                                        ? 'Continue reading'
                                        : 'Resume',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    ],
  );
}
