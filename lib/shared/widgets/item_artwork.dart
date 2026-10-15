import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/db/app_database.dart';
import '../../data/providers/app_providers.dart';
import '../../domain/services/thumbnail_cache.dart';
import 'study_ui.dart';

final thumbnailCacheProvider = Provider((ref) => ThumbnailCache());
final _thumbnailProvider = FutureProvider.autoDispose.family<String?, Item>(
  (ref, item) => ref.read(thumbnailCacheProvider).forItem(item),
);
final _coverProvider = FutureProvider.autoDispose.family<String?, Library>((
  ref,
  library,
) async {
  final db = ref.read(appDatabaseProvider);
  final cache = ref.read(thumbnailCacheProvider);
  final item =
      await (db.select(db.items)
            ..where(
              (t) =>
                  t.libraryId.equals(library.id) &
                  t.unavailable.not() &
                  t.itemType.isIn(['image', 'pdf', 'video']),
            )
            ..orderBy([(t) => drift.OrderingTerm.asc(t.orderIndex)])
            ..limit(1))
          .getSingleOrNull();
  return item == null ? null : cache.forItem(item);
});

class ItemArtwork extends ConsumerWidget {
  const ItemArtwork({super.key, required this.item, required this.size});
  final Item item;
  final double size;
  @override
  Widget build(BuildContext context, WidgetRef ref) => StudyArtwork(
    path:
        item.thumbnailPath ?? ref.watch(_thumbnailProvider(item)).asData?.value,
    kind: item.itemType,
    unavailable: item.unavailable,
    size: size,
  );
}

class LibraryArtwork extends ConsumerWidget {
  const LibraryArtwork({
    super.key,
    required this.library,
    required this.size,
    this.radius,
  });
  final Library library;
  final double size;
  final double? radius;
  @override
  Widget build(BuildContext context, WidgetRef ref) => StudyArtwork(
    path: library.coverPath ?? ref.watch(_coverProvider(library)).asData?.value,
    kind: 'library',
    unavailable: library.unavailable,
    size: size,
    radius: radius ?? 12,
  );
}
