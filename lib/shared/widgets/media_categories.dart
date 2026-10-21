import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../data/providers/app_providers.dart';
import '../../domain/catalog/media_catalog_repository.dart';

IconData mediaCategoryIcon(LibraryKind kind) => switch (kind) {
  LibraryKind.movies => Icons.movie_outlined,
  LibraryKind.television => Icons.live_tv_outlined,
  LibraryKind.music => Icons.library_music_outlined,
  LibraryKind.musicVideos => Icons.music_video_outlined,
  LibraryKind.homeVideos => Icons.video_camera_back_outlined,
  LibraryKind.photos => Icons.photo_library_outlined,
  LibraryKind.audiobooks => Icons.headphones_outlined,
  LibraryKind.podcasts => Icons.podcasts,
  LibraryKind.books => Icons.menu_book_outlined,
  LibraryKind.comics => Icons.auto_stories_outlined,
  LibraryKind.documents => Icons.description_outlined,
  LibraryKind.courses => Icons.school_outlined,
  LibraryKind.mixed => Icons.folder_copy_outlined,
};

/// Category entry points exist even before a library of that kind is created.
class MediaCategories extends ConsumerWidget {
  const MediaCategories({super.key, this.compact = false});
  final bool compact;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(appDatabaseProvider);
    return StreamBuilder(
      stream: db
          .customSelect(
            "SELECT f.value,COUNT(*) AS total FROM catalog_facets f JOIN items i ON i.id=f.item_id WHERE f.field='category' AND i.unavailable=0 GROUP BY f.value",
            readsFrom: {db.items, db.libraries},
          )
          .watch(),
      builder: (context, snapshot) {
        final counts = {
          for (final row in snapshot.data ?? [])
            row.data['value']: row.data['total'],
        };
        if (compact)
          return Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final kind in [
                ...LibraryKind.values.where((k) => k != LibraryKind.mixed),
                LibraryKind.mixed,
              ])
                ActionChip(
                  avatar: Icon(mediaCategoryIcon(kind), size: 18),
                  label: Text(
                    '${kind.label}${counts[kind.name] == null ? '' : ' · ${counts[kind.name]}'}',
                  ),
                  onPressed: () => context.push('/category/${kind.name}'),
                ),
            ],
          );
        return LayoutBuilder(
          builder: (context, box) {
            final columns = (box.maxWidth / 165).floor().clamp(2, 6);
            final width = (box.maxWidth - (columns - 1) * 12) / columns;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final kind in [
                  ...LibraryKind.values.where((k) => k != LibraryKind.mixed),
                  LibraryKind.mixed,
                ])
                  SizedBox(
                    width: width,
                    child: Material(
                      color: Theme.of(context).colorScheme.surfaceContainerLow,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: Theme.of(context).colorScheme.outlineVariant,
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () => context.push('/category/${kind.name}'),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                mediaCategoryIcon(kind),
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              const SizedBox(height: 10),
                              Text(
                                kind.label,
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${counts[kind.name] ?? 0} titles',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }
}
