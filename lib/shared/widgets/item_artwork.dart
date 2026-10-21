import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/db/app_database.dart';
import '../../data/providers/app_providers.dart';
import '../../domain/services/thumbnail_cache.dart';
import '../../domain/services/catalog_artwork_cache.dart';
import '../../domain/catalog/media_catalog_repository.dart';
import 'study_ui.dart';
import 'remote_item_artwork.dart';

final thumbnailCacheProvider = Provider((ref) => ThumbnailCache());
final catalogArtworkPathProvider = FutureProvider.autoDispose.family<String?, Item>((
  ref,
  item,
) async {
  if (item.filePath.startsWith('remote:')) return null;
  final db = ref.read(appDatabaseProvider);
  // Matching emits an Items update. Keep already visible tiles in step with a
  // new selection, clear or artwork override without changing the source file.
  ref.watch(_catalogArtworkRevisionProvider(item.id));
  final metadata = await MediaCatalogRepository(db).metadata(item);
  return CatalogArtworkCache.instance.get(metadata['artworkUrl'] as String?);
});
final _catalogArtworkRevisionProvider = StreamProvider.autoDispose
    .family<Item?, String>(
      (ref, id) =>
          (ref
                  .read(appDatabaseProvider)
                  .select(ref.read(appDatabaseProvider).items)
                ..where((t) => t.id.equals(id)))
              .watchSingleOrNull(),
    );
final itemArtworkPathProvider = FutureProvider.autoDispose
    .family<String?, Item>((ref, item) {
      final lease = ref.read(thumbnailCacheProvider).acquire(item);
      ref.onDispose(lease.release);
      return lease.future;
    });
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
  if (item == null) return null;
  final lease = cache.acquire(item);
  ref.onDispose(lease.release);
  return lease.future;
});

class ItemArtwork extends ConsumerWidget {
  const ItemArtwork({super.key, required this.item, required this.size});
  final Item item;
  final double size;
  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      item.filePath.startsWith('remote:')
      ? SizedBox(
          width: size,
          height: size,
          child: RemoteItemArtwork(
            item: item,
            placeholder: StudyArtwork(
              path: null,
              kind: item.itemType,
              unavailable: item.unavailable,
              size: size,
            ),
          ),
        )
      : StudyArtwork(
          path:
              ref.watch(catalogArtworkPathProvider(item)).asData?.value ??
              item.thumbnailPath ??
              ref.watch(itemArtworkPathProvider(item)).asData?.value,
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
