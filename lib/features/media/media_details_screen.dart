import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../domain/catalog/catalog_online_policy.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/display_utils.dart';
import '../../data/db/app_database.dart';
import '../../data/providers/app_providers.dart';
import '../../domain/catalog/media_catalog_repository.dart';
import '../../domain/catalog/catalog_playback.dart';
import '../../domain/catalog/catalog_hints.dart';
import '../../domain/catalog/media_experience.dart';
import '../../shared/widgets/app_top_bar.dart';
import '../../shared/widgets/cinematic_media.dart';
import '../../shared/widgets/lesson_tools_sheet.dart';
import '../../shared/widgets/study_ui.dart';
import 'catalog_editor_screen.dart';
import 'media_versions_section.dart';
import 'technical_media_panel.dart';
import '../library/collections_screen.dart';

class _Details {
  const _Details(
    this.item,
    this.library,
    this.metadata,
    this.favorite,
    this.playback,
    this.reading, {
    required this.experience,
    this.multipart = false,
    this.partsResume = false,
    this.partsComplete = false,
    this.partsAvailable = false,
  });
  final Item item;
  final Library? library;
  final Map<String, dynamic> metadata;
  final bool favorite;
  final PlaybackProgressData? playback;
  final ReadingProgressData? reading;
  final MediaExperience experience;
  final bool multipart, partsResume, partsComplete, partsAvailable;
  bool get completed => multipart
      ? partsComplete
      : playback?.completed == true || reading?.completed == true;
  bool get hasResume => multipart
      ? partsResume
      : (playback?.resumePositionSeconds ?? 0) > 0 ||
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
    TitleFiles? files;
    try {
      files = await CatalogPlayback(db).files(item);
    } on FormatException {
      /* Exact-file Details remains usable without catalog identity. */
    }
    final parts = files?.parts ?? <CatalogPart>[];
    final histories = await Future.wait(
      parts.map((part) => db.getPlaybackByItemId(part.item.id)),
    );
    return _Details(
      item,
      await db.getLibraryById(item.libraryId),
      await catalog.metadata(item),
      (await catalog.record('organization:${item.id}'))?.data['favorite'] ==
          true,
      await db.getPlaybackByItemId(item.id),
      await db.getReadingByItemId(item.id),
      experience: MediaExperience(
        await catalog.libraryKind(item.libraryId),
        item.itemType,
      ),
      multipart: parts.isNotEmpty,
      partsResume: histories.any(
        (progress) =>
            progress?.completed == true ||
            (progress?.resumePositionSeconds ?? 0) > 0,
      ),
      partsComplete:
          histories.isNotEmpty &&
          histories.every((progress) => progress?.completed == true),
      partsAvailable: parts.every((part) => !part.item.unavailable),
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

  Future<void> _open(_Details details) async {
    try {
      final item = details.item;
      var route = MediaVisuals.route(item);
      if (details.multipart) {
        final target = await CatalogPlayback(
          ref.read(appDatabaseProvider),
        ).resumePart(item.id);
        route = CatalogPlayback.partRoute(
          item.id,
          target.itemId,
          position: target.position,
        );
      }
      if (!mounted) return;
      await context.push(route);
      if (mounted) setState(() => _details = _load());
    } on Object {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'This title could not open. Check its files and source availability.',
            ),
          ),
        );
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
                          if (CatalogHints.episodeLabel(details.metadata)
                              case final String episode)
                            episode,
                          if (details.metadata['year'] != null)
                            '${details.metadata['year']}',
                          item.itemType.toUpperCase(),
                          if (details.completed &&
                              details.experience.completion)
                            details.experience.completedLabel,
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
                            onPressed:
                                (details.multipart
                                    ? !details.partsAvailable
                                    : item.unavailable)
                                ? null
                                : () => _open(details),
                            icon: Icon(
                              MediaVisuals.isReading(item)
                                  ? Icons.menu_book
                                  : Icons.play_arrow,
                            ),
                            label: Text(
                              details.hasResume && !details.completed
                                  ? (details.multipart
                                        ? 'Resume title'
                                        : 'Resume')
                                  : details.multipart
                                  ? 'Play title'
                                  : MediaVisuals.action(item),
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => CollectionsScreen(
                                  libraryId: item.libraryId,
                                  item: item,
                                ),
                              ),
                            ),
                            icon: const Icon(
                              Icons.collections_bookmark_outlined,
                            ),
                            label: const Text('Add to collection'),
                          ),
                          TextButton.icon(
                            onPressed: () async {
                              await Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) =>
                                      CatalogEditorScreen(item: item),
                                ),
                              );
                              if (mounted)
                                setState(() {
                                  _details = _load();
                                });
                            },
                            icon: const Icon(Icons.manage_search),
                            label: const Text('Edit details'),
                          ),
                          if (details.experience.notes)
                            TextButton.icon(
                              onPressed: () => showLessonToolsSheet(
                                context: context,
                                database: ref.read(appDatabaseProvider),
                                item: item,
                                title: details.experience.course
                                    ? 'Study tools'
                                    : 'Notes & bookmarks',
                                currentPage: details.reading?.resumePage,
                                currentPositionSeconds:
                                    details.playback?.resumePositionSeconds,
                              ),
                              icon: const Icon(Icons.edit_note),
                              label: Text(details.experience.notesLabel),
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
                          if (details.experience.completion)
                            TextButton.icon(
                              onPressed: _saving
                                  ? null
                                  : () => _change(
                                      () => details.multipart
                                          ? CatalogPlayback(
                                              ref.read(appDatabaseProvider),
                                            ).setTitleCompletion(
                                              item,
                                              !details.completed,
                                            )
                                          : ref
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
                                details.experience.completionLabel(
                                  details.completed,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  );
                  final art = SizedBox(
                    width: box.maxWidth < 560 ? 140 : 180,
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
                  return box.maxWidth < 560
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
              if ((details.metadata['synopsis'] as String? ?? '')
                  .trim()
                  .isNotEmpty) ...[
                Text(
                  details.experience.reading
                      ? 'About this book or document'
                      : 'About',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: AppSpace.sm),
                Text(
                  details.metadata['synopsis'] as String? ??
                      'No description available.',
                ),
                const SizedBox(height: AppSpace.xl),
              ],
              if (details.metadata['attribution'] is String) ...[
                Text(
                  details.metadata['attribution'] as String,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (CatalogOnlinePolicy.source(
                  details.metadata['sourceUrl'] as String?,
                ))
                  TextButton.icon(
                    icon: const Icon(Icons.open_in_new, size: 16),
                    label: const Text('View metadata source'),
                    onPressed: () => launchUrl(
                      Uri.parse(details.metadata['sourceUrl'] as String),
                      mode: LaunchMode.externalApplication,
                    ),
                  ),
                const SizedBox(height: AppSpace.md),
              ],
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                initiallyExpanded: details.multipart,
                title: Text(
                  details.experience.photo
                      ? 'File information'
                      : 'Files & versions',
                ),
                subtitle: Text(
                  item.filename,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                children: [
                  if (!details.experience.photo)
                    MediaVersionsSection(
                      item: item,
                      onChanged: () => setState(() => _details = _load()),
                    ),
                  if (details.experience.photo) SelectableText(item.filename),
                  if ({'audio', 'video'}.contains(item.itemType))
                    TechnicalMediaPanel(key: ValueKey(item.id), item: item),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      [
                        if (item.durationSeconds != null)
                          '${(item.durationSeconds! / 60).toStringAsFixed(1)} minutes',
                        if (item.pageCount != null) '${item.pageCount} pages',
                        if (item.fileSize != null)
                          '${(item.fileSize! / (1024 * 1024)).toStringAsFixed(1)} MiB',
                      ].join(' · '),
                    ),
                  ),
                  Text(
                    details.metadata['matchState'] == 'matched'
                        ? 'Catalog metadata'
                        : 'Local metadata',
                  ),
                ],
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
