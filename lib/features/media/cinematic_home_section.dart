import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../data/db/app_database.dart';
import '../../data/providers/app_providers.dart';
import '../../shared/widgets/cinematic_media.dart';

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

final _homeTitles = StreamProvider.autoDispose.family<List<_HomeTitle>, bool>((
  ref,
  continuing,
) {
  final db = ref.watch(appDatabaseProvider);
  const active =
      '(COALESCE(p.completed,r.completed,0)=0 AND (COALESCE(p.last_position_seconds,0)>0 OR COALESCE(r.last_page,1)>1 OR COALESCE(r.last_scroll_offset,0)>0))';
  return db
      .customSelect(
        '''SELECT i.*,COALESCE(s.title,i.user_title,i.title) AS display_title,
    COALESCE(p.percent_watched,r.percent_read) AS progress FROM items i
    LEFT JOIN catalog_search s ON s.item_id=i.id
    LEFT JOIN playback_progress p ON p.item_id=i.id LEFT JOIN reading_progress r ON r.item_id=i.id
    WHERE i.unavailable=0 AND ${continuing ? active : 'NOT $active'}
    ORDER BY ${continuing ? 'MAX(COALESCE(p.last_opened_at,0),COALESCE(r.last_opened_at,0)) DESC' : 'i.created_at DESC'},i.id LIMIT 12''',
        readsFrom: {db.items, db.playbackProgress, db.readingProgress},
      )
      .watch()
      .map(
        (rows) => rows
            .map(
              (row) => _HomeTitle(
                db.items.map(row.data),
                row.data['display_title'] as String,
                (row.data['progress'] as num?)?.toDouble(),
              ),
            )
            .toList(),
      );
});

/// Home offers one resume shelf and one discovery shelf. Empty media categories
/// do not turn the dashboard into a collection of setup instructions.
class CinematicHomeSection extends ConsumerWidget {
  const CinematicHomeSection({super.key, required this.onOpen});
  final ValueChanged<Item> onOpen;
  @override
  Widget build(BuildContext context, WidgetRef ref) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (final continuing in [true, false])
        ref
            .watch(_homeTitles(continuing))
            .when(
              loading: () => const SizedBox.shrink(),
              error: (_, _) => Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpace.md),
                child: Text(
                  continuing
                      ? 'Recent activity could not load.'
                      : 'Recently added titles could not load.',
                ),
              ),
              data: (titles) => titles.isEmpty
                  ? const SizedBox.shrink()
                  : Padding(
                      padding: const EdgeInsets.only(bottom: AppSpace.xl),
                      child: continuing
                          ? _ResumeShelf(titles: titles, onOpen: onOpen)
                          : CinematicMediaRow(
                              compact: true,
                              title: continuing ? 'Continue' : 'Recently added',
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
    ],
  );
}

class _ResumeShelf extends StatelessWidget {
  const _ResumeShelf({required this.titles, required this.onOpen});
  final List<_HomeTitle> titles;
  final ValueChanged<Item> onOpen;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('Continue', style: Theme.of(context).textTheme.titleLarge),
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
