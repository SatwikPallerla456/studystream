import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../data/db/app_database.dart';
import '../../data/providers/app_providers.dart';
import '../../shared/widgets/cinematic_media.dart';

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

class CinematicHomeSection extends ConsumerWidget {
  const CinematicHomeSection({super.key, required this.onOpen});
  final ValueChanged<Item> onOpen;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void details(Item item) =>
        context.push('/details/${Uri.encodeComponent(item.id)}');
    final recent = ref.watch(recentlyAddedMediaProvider('all'));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        recent.when(
          loading: () => const SizedBox(
            height: 280,
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (_, _) =>
              const Text('Recently added media could not be loaded.'),
          data: (items) => items.isEmpty
              ? const SizedBox.shrink()
              : FeaturedMedia(
                  item: items.first,
                  onOpen: () => onOpen(items.first),
                  onDetails: () => details(items.first),
                ),
        ),
        for (final (kind, label) in [
          ('all', 'Recently Added'),
          ('video', 'Your Videos'),
          ('audio', 'Your Listening Library'),
          ('reading', 'Books & Documents'),
        ])
          ref
              .watch(recentlyAddedMediaProvider(kind))
              .when(
                loading: () => const SizedBox.shrink(),
                error: (_, _) => Padding(
                  padding: const EdgeInsets.only(top: AppSpace.lg),
                  child: Text('$label is unavailable.'),
                ),
                data: (items) => items.isEmpty
                    ? const SizedBox.shrink()
                    : Padding(
                        padding: const EdgeInsets.only(top: AppSpace.xl),
                        child: CinematicMediaRow(
                          title: label,
                          items: items,
                          onDetails: details,
                          onOpen: onOpen,
                        ),
                      ),
              ),
      ],
    );
  }
}
