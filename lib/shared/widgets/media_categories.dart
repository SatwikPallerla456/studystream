import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../data/providers/app_providers.dart';
import '../../domain/catalog/media_catalog_repository.dart';
import 'tangerine_controls.dart';

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
          return _CategoryRibbon(
            children: [
              for (final kind in [
                ...LibraryKind.values.where((k) => k != LibraryKind.mixed),
                LibraryKind.mixed,
              ])
                TangerineInteraction(
                  child: TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.onSurface,
                      backgroundColor: context.studyColors.surfaceRaised,
                      minimumSize: const Size(48, 48),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      shape: const StadiumBorder(),
                    ),
                    icon: Icon(
                      mediaCategoryIcon(kind),
                      size: 19,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    label: Text(
                      '${kind.label}${counts[kind.name] == null ? '' : ' · ${counts[kind.name]}'}',
                    ),
                    onPressed: () => context.push('/category/${kind.name}'),
                  ),
                ),
            ],
          );
        return LayoutBuilder(
          builder: (context, box) {
            final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
            final columns = (box.maxWidth / (180 * textScale)).floor().clamp(
              1,
              5,
            );
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
                    child: Semantics(
                      button: true,
                      label: '${kind.label}, ${counts[kind.name] ?? 0} titles',
                      excludeSemantics: true,
                      onTap: () => context.push('/category/${kind.name}'),
                      child: TangerineInteraction(
                        lift: 2,
                        child: Material(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(18),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(18),
                            onTap: () => context.push('/category/${kind.name}'),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 8,
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 38,
                                    height: 38,
                                    decoration: BoxDecoration(
                                      color: context.studyColors.surfaceStrong
                                          .withValues(alpha: .5),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      mediaCategoryIcon(kind),
                                      size: 22,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          kind.label,
                                          style: Theme.of(
                                            context,
                                          ).textTheme.titleSmall,
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          '${counts[kind.name] ?? 0} titles',
                                          style: Theme.of(
                                            context,
                                          ).textTheme.bodySmall,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(
                                    Icons.chevron_right_rounded,
                                    size: 18,
                                    color: context.studyColors.textMuted,
                                  ),
                                ],
                              ),
                            ),
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

class _CategoryRibbon extends StatefulWidget {
  const _CategoryRibbon({required this.children});
  final List<Widget> children;
  @override
  State<_CategoryRibbon> createState() => _CategoryRibbonState();
}

class _CategoryRibbonState extends State<_CategoryRibbon> {
  final _scroll = ScrollController();
  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _move(int direction) {
    if (!_scroll.hasClients) return;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final target =
        (_scroll.offset +
                direction *
                    (rtl ? -1 : 1) *
                    _scroll.position.viewportDimension *
                    .75)
            .clamp(0.0, _scroll.position.maxScrollExtent);
    _scroll.animateTo(
      target,
      duration: AppMotion.resolve(context, AppMotion.emphasized),
      curve: AppMotion.settle,
    );
  }

  @override
  Widget build(BuildContext context) => Row(
    children: [
      IconButton(
        tooltip: 'Previous categories',
        onPressed: () =>
            _move(Directionality.of(context) == TextDirection.rtl ? 1 : -1),
        icon: const Icon(Icons.chevron_left_rounded),
      ),
      Expanded(
        child: SingleChildScrollView(
          key: const PageStorageKey('home-category-ribbon'),
          controller: _scroll,
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (var i = 0; i < widget.children.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                widget.children[i],
              ],
            ],
          ),
        ),
      ),
      IconButton(
        tooltip: 'Next categories',
        onPressed: () =>
            _move(Directionality.of(context) == TextDirection.rtl ? -1 : 1),
        icon: const Icon(Icons.chevron_right_rounded),
      ),
    ],
  );
}
