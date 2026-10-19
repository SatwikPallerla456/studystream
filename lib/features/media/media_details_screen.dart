import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/display_utils.dart';
import '../../data/db/app_database.dart';
import '../../data/providers/app_providers.dart';
import '../../domain/catalog/media_catalog_repository.dart';
import '../../shared/widgets/app_top_bar.dart';
import '../../shared/widgets/cinematic_media.dart';
import '../../shared/widgets/lesson_tools_sheet.dart';
import '../../shared/widgets/study_ui.dart';

class _Details {
  const _Details(
    this.item,
    this.library,
    this.metadata,
    this.favorite,
    this.playback,
    this.reading,
  );
  final Item item;
  final Library? library;
  final Map<String, dynamic> metadata;
  final bool favorite;
  final PlaybackProgressData? playback;
  final ReadingProgressData? reading;
  bool get completed =>
      playback?.completed == true || reading?.completed == true;
  bool get hasResume =>
      (playback?.resumePositionSeconds ?? 0) > 0 ||
      (reading?.resumePage ?? 1) > 1 ||
      (reading?.resumeScrollOffset ?? 0) > 0;
}

class MediaDetailsScreen extends ConsumerStatefulWidget {
  const MediaDetailsScreen({super.key, required this.itemId});
  final String itemId;
  @override
  ConsumerState<MediaDetailsScreen> createState() => _MediaDetailsScreenState();
}

class _MediaDetailsScreenState extends ConsumerState<MediaDetailsScreen> {
  late Future<_Details?> _details;
  bool _saving = false;
  @override
  void initState() {
    super.initState();
    _details = _load();
  }

  @override
  void didUpdateWidget(covariant MediaDetailsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.itemId != widget.itemId) _details = _load();
  }

  Future<_Details?> _load() async {
    final db = ref.read(appDatabaseProvider);
    final item = await db.getItemById(widget.itemId);
    if (item == null) return null;
    final catalog = MediaCatalogRepository(db);
    return _Details(
      item,
      await db.getLibraryById(item.libraryId),
      await catalog.metadata(item),
      (await catalog.record('organization:${item.id}'))?.data['favorite'] ==
          true,
      await db.getPlaybackByItemId(item.id),
      await db.getReadingByItemId(item.id),
    );
  }

  Future<void> _change(Future<void> Function() action) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await action();
      if (mounted) {
        setState(() {
          _details = _load();
        });
      }
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('The change could not be saved. Try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _open(Item item) async {
    await context.push(MediaVisuals.route(item));
    if (mounted) {
      setState(() {
        _details = _load();
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: const AppTopBar(title: 'Details', showBack: true),
    body: FutureBuilder<_Details?>(
      future: _details,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('These details could not be loaded.'),
                TextButton(
                  onPressed: () => setState(() {
                    _details = _load();
                  }),
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final details = snapshot.data;
        if (details == null) {
          return const Center(
            child: Text('This item is no longer in your library.'),
          );
        }
        final item = details.item;
        final title = cleanDisplayTitle(
          item.userTitle ?? details.metadata['title'] as String? ?? item.title,
        );
        final creator =
            details.metadata['author'] ??
            details.metadata['artist'] ??
            details.metadata['credits'];
        return StudyPage(
          key: PageStorageKey('details-${item.id}'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LayoutBuilder(
                builder: (context, box) {
                  final text = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        details.library?.title ?? 'Your library',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: AppSpace.sm),
                      Text(
                        title,
                        style: Theme.of(context).textTheme.headlineLarge,
                      ),
                      const SizedBox(height: AppSpace.sm),
                      Text(
                        [
                          if (details.metadata['year'] != null)
                            '${details.metadata['year']}',
                          item.itemType.toUpperCase(),
                          if (details.completed) 'Completed',
                          item.filePath.startsWith('remote:')
                              ? 'Server'
                              : 'Local',
                        ].join(' · '),
                      ),
                      if (creator is String && creator.isNotEmpty) ...[
                        const SizedBox(height: AppSpace.sm),
                        Text(creator),
                      ],
                      const SizedBox(height: AppSpace.lg),
                      if (item.unavailable)
                        const Padding(
                          padding: EdgeInsets.only(bottom: AppSpace.md),
                          child: Text(
                            'This source is unavailable. Relink or reconnect it in the library.',
                          ),
                        ),
                      Wrap(
                        spacing: AppSpace.sm,
                        runSpacing: AppSpace.sm,
                        children: [
                          FilledButton.icon(
                            onPressed: item.unavailable
                                ? null
                                : () => _open(item),
                            icon: Icon(
                              MediaVisuals.isReading(item)
                                  ? Icons.menu_book
                                  : Icons.play_arrow,
                            ),
                            label: Text(
                              details.hasResume && !details.completed
                                  ? 'Resume'
                                  : MediaVisuals.action(item),
                            ),
                          ),
                          OutlinedButton.icon(
                            onPressed: () => showLessonToolsSheet(
                              context: context,
                              database: ref.read(appDatabaseProvider),
                              item: item,
                              currentPage: details.reading?.resumePage,
                              currentPositionSeconds:
                                  details.playback?.resumePositionSeconds,
                            ),
                            icon: const Icon(Icons.edit_note),
                            label: const Text('Study'),
                          ),
                          OutlinedButton.icon(
                            onPressed: _saving
                                ? null
                                : () => _change(
                                    () => MediaCatalogRepository(
                                      ref.read(appDatabaseProvider),
                                    ).setFavorite(item, !details.favorite),
                                  ),
                            icon: Icon(
                              details.favorite
                                  ? Icons.favorite
                                  : Icons.favorite_border,
                            ),
                            label: Text(
                              details.favorite ? 'Favorited' : 'Favorite',
                            ),
                          ),
                          OutlinedButton.icon(
                            onPressed: _saving
                                ? null
                                : () => _change(
                                    () => ref
                                        .read(appDatabaseProvider)
                                        .setItemCompletion(
                                          item: item,
                                          completed: !details.completed,
                                        ),
                                  ),
                            icon: Icon(
                              details.completed
                                  ? Icons.check_circle
                                  : Icons.check_circle_outline,
                            ),
                            label: Text(
                              details.completed
                                  ? 'Mark incomplete'
                                  : 'Mark complete',
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                  final art = SizedBox(
                    width: box.maxWidth < 700 ? 160 : 240,
                    child: AspectRatio(
                      aspectRatio: MediaVisuals.isListening(item)
                          ? 1
                          : MediaVisuals.posterRatio,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        child: CinematicArtwork(item: item),
                      ),
                    ),
                  );
                  return box.maxWidth < 700
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            art,
                            const SizedBox(height: AppSpace.lg),
                            text,
                          ],
                        )
                      : Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            art,
                            const SizedBox(width: AppSpace.xl),
                            Expanded(child: text),
                          ],
                        );
                },
              ),
              const SizedBox(height: AppSpace.xl),
              Text(
                'About this title',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpace.sm),
              Text(
                details.metadata['synopsis'] as String? ??
                    'No synopsis has been added. Your original file is ready to open.',
              ),
              const SizedBox(height: AppSpace.xl),
              Text(
                'Available file',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpace.sm),
              SelectableText(item.filename),
              Text(
                [
                  if (item.durationSeconds != null)
                    '${(item.durationSeconds! / 60).toStringAsFixed(1)} minutes',
                  if (item.pageCount != null) '${item.pageCount} pages',
                  if (item.fileSize != null)
                    '${(item.fileSize! / (1024 * 1024)).toStringAsFixed(1)} MiB',
                ].join(' · '),
              ),
              const SizedBox(height: AppSpace.sm),
              Text(
                details.metadata['matchState'] == 'matched'
                    ? 'Catalog metadata · file history is retained'
                    : 'Local title · not matched to a catalog',
              ),
              const SizedBox(height: AppSpace.lg),
              TextButton.icon(
                onPressed: () => context.push(
                  '/library/${Uri.encodeComponent(item.libraryId)}',
                ),
                icon: const Icon(Icons.video_library_outlined),
                label: const Text('Open library'),
              ),
            ],
          ),
        );
      },
    ),
  );
}
