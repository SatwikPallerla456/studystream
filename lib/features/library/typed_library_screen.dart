import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/db/app_database.dart';
import '../../data/providers/app_providers.dart';
import '../../domain/catalog/media_catalog_repository.dart';
import '../../domain/catalog/catalog_hints.dart';
import '../../domain/services/player_library_repository.dart';
import '../../shared/widgets/app_top_bar.dart';
import '../../shared/widgets/cinematic_media.dart';
import '../../shared/widgets/study_ui.dart';
import '../media/media_browser_section.dart';
import 'collections_screen.dart';
import 'photo_slideshow_screen.dart';
import 'library_scan_dialog.dart';

class TypedLibraryScreen extends ConsumerStatefulWidget {
  const TypedLibraryScreen({
    super.key,
    required this.library,
    required this.kind,
    this.field,
    this.filters = const {},
    this.onChanged,
  });
  final Library library;
  final LibraryKind kind;
  final String? field;
  final Map<String, String> filters;
  final VoidCallback? onChanged;
  @override
  ConsumerState<TypedLibraryScreen> createState() => _TypedLibraryState();
}

class _CatalogPage {
  const _CatalogPage(this.rows, this.artwork);
  final List<drift.QueryRow> rows;
  final Map<String, Item> artwork;
}

class _TypedLibraryState extends ConsumerState<TypedLibraryScreen> {
  String? _after;
  final _history = <String?>[];
  late String? _field = widget.filters.isNotEmpty
      ? widget.field
      : widget.field ?? _defaultField;
  String? get _defaultField => switch (widget.kind) {
    LibraryKind.television => 'show',
    LibraryKind.music => 'artist',
    LibraryKind.audiobooks || LibraryKind.books => 'author',
    LibraryKind.podcasts => 'series',
    LibraryKind.photos || LibraryKind.homeVideos => 'month',
    _ => null,
  };
  late Future<_CatalogPage> _page = _load();

  Future<_CatalogPage> _load() async {
    final db = ref.read(appDatabaseProvider);
    final clauses = <String>['i.library_id=?', 'i.unavailable=0'];
    final values = <drift.Variable>[drift.Variable(widget.library.id)];
    for (final filter in widget.filters.entries) {
      clauses.add(
        'EXISTS(SELECT 1 FROM catalog_facets x WHERE x.item_id=i.id AND x.field=? AND x.value=?)',
      );
      values.addAll([drift.Variable(filter.key), drift.Variable(filter.value)]);
    }
    late List<drift.QueryRow> rows;
    if (_field != null) {
      clauses.add('f.field=?');
      values.add(drift.Variable(_field!));
      final sort = _field == 'season'
          ? "printf('%08d',CAST(f.value AS INTEGER))"
          : 'f.value';
      if (_after != null) {
        clauses.add('$sort>?');
        values.add(drift.Variable(_after!));
      }
      rows = await db
          .customSelect(
            'SELECT f.value,$sort AS sort_key,COUNT(*) AS count,MIN(i.id) AS item_id FROM catalog_facets f JOIN items i ON i.id=f.item_id WHERE ${clauses.join(' AND ')} GROUP BY f.value ORDER BY $sort LIMIT 61',
            variables: values,
          )
          .get();
    } else {
      final sort =
          "printf('%08d:%08d:%s:%s',COALESCE((SELECT number FROM catalog_facets WHERE item_id=i.id AND field='${widget.kind == LibraryKind.television ? 'season' : 'disc'}'),0),COALESCE((SELECT number FROM catalog_facets WHERE item_id=i.id AND field='${widget.kind == LibraryKind.television ? 'episode' : 'track'}'),0),COALESCE(s.title,i.user_title,i.title),i.id)";
      if (_after != null) {
        clauses.add('$sort>?');
        values.add(drift.Variable(_after!));
      }
      rows = await db.customSelect(
        '''SELECT i.id AS item_id,$sort AS sort_key,COALESCE(s.title,i.user_title,i.title) AS effective_title,
        COALESCE(p.percent_watched,r.percent_read) AS progress,
        (SELECT number FROM catalog_facets WHERE item_id=i.id AND field='season') AS season,
        (SELECT number FROM catalog_facets WHERE item_id=i.id AND field='episode') AS episode,
        (SELECT number FROM catalog_facets WHERE item_id=i.id AND field='episodeEnd') AS episodeEnd
        FROM items i LEFT JOIN catalog_search s ON s.item_id=i.id
        LEFT JOIN playback_progress p ON p.item_id=i.id LEFT JOIN reading_progress r ON r.item_id=i.id
        WHERE ${clauses.join(' AND ')} ORDER BY $sort LIMIT 61''',
        variables: values,
      ).get();
    }
    final ids = rows
        .take(60)
        .map((row) => row.data['item_id'] as String)
        .toSet()
        .toList();
    final items = ids.isEmpty
        ? <drift.QueryRow>[]
        : await db
              .customSelect(
                'SELECT * FROM items WHERE library_id=? AND id IN (${List.filled(ids.length, '?').join(',')})',
                variables: [
                  drift.Variable(widget.library.id),
                  ...ids.map((id) => drift.Variable(id)),
                ],
              )
              .get();
    return _CatalogPage(rows, {
      for (final row in items) row.data['id'] as String: db.items.map(row.data),
    });
  }

  void _reload({String? field, bool changeField = false}) => setState(() {
    if (changeField) _field = field;
    _after = null;
    _history.clear();
    _page = _load();
  });

  Future<void> _drill(String value) async {
    final next = switch (_field) {
      'show' => 'season',
      'artist' => 'album',
      _ => null,
    };
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => TypedLibraryScreen(
          library: widget.library,
          kind: widget.kind,
          field: next,
          filters: {...widget.filters, _field!: value},
          onChanged: widget.onChanged,
        ),
      ),
    );
    if (mounted) _reload();
  }

  Future<void> _details(Item item) async {
    await context.push('/details/${Uri.encodeComponent(item.id)}');
    if (mounted) _reload();
  }

  String _groupTitle(String value) => switch (_field) {
    'season' => value == '0' ? 'Specials' : 'Season $value',
    _ => value,
  };
  String get _sectionTitle => switch (_field) {
    'show' => 'Shows',
    'season' => 'Seasons',
    'artist' => 'Artists',
    'album' => 'Albums',
    'author' => 'Authors',
    'series' => 'Series',
    'month' => 'By month',
    _ => 'Titles',
  };
  IconData get _groupIcon => switch (_field) {
    'show' || 'season' => Icons.live_tv,
    'artist' => Icons.person_outline,
    'album' => Icons.album_outlined,
    'author' => Icons.menu_book_outlined,
    'month' => Icons.photo_library_outlined,
    _ => Icons.collections_bookmark_outlined,
  };

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppTopBar(
      title: widget.filters.values.lastOrNull ?? widget.library.title,
      showBack: true,
      actions: [
        if (widget.kind == LibraryKind.photos)
          IconButton(
            tooltip: 'Slideshow',
            icon: const Icon(Icons.slideshow_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) =>
                    PhotoSlideshowScreen(libraryId: widget.library.id),
              ),
            ),
          ),
        IconButton(
          tooltip: 'Collections and albums',
          icon: const Icon(Icons.collections_bookmark_outlined),
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => CollectionsScreen(libraryId: widget.library.id),
            ),
          ),
        ),
        IconButton(
          tooltip: 'Library type and sources',
          icon: const Icon(Icons.folder_outlined),
          onPressed: () async {
            await context.push('/library/${widget.library.id}/sources');
            widget.onChanged?.call();
            if (mounted) _reload();
          },
        ),
      ],
    ),
    body: StudyPage(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.filters.isEmpty) ...[
            Text(
              widget.kind.label,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                OutlinedButton.icon(
                  onPressed: () async {
                    await showLibraryScan(
                      context,
                      libraryId: widget.library.id,
                    );
                    if (mounted) _reload();
                  },
                  icon: const Icon(Icons.sync),
                  label: const Text('Scan library'),
                ),
                OutlinedButton.icon(
                  onPressed: () async {
                    await context.push(
                      '/library/${widget.library.id}/identify',
                    );
                    if (mounted) _reload();
                  },
                  icon: const Icon(Icons.manage_search),
                  label: const Text('Identify titles'),
                ),
                TextButton.icon(
                  onPressed: () =>
                      context.push('/library/${widget.library.id}/sources'),
                  icon: const Icon(Icons.folder_outlined),
                  label: const Text('Sources & settings'),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
          if (widget.filters.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                widget.filters.entries
                    .map(
                      (entry) => entry.key == 'season'
                          ? (entry.value == '0'
                                ? 'Specials'
                                : 'Season ${entry.value}')
                          : entry.value,
                    )
                    .join(' / '),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          if (widget.filters.isEmpty && _defaultField != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('All files'),
                    selected: _field == null,
                    onSelected: (_) => _reload(changeField: true),
                  ),
                  if (_defaultField != null)
                    ChoiceChip(
                      label: Text(switch (_defaultField) {
                        'show' => 'Shows and seasons',
                        'artist' => 'Artists and albums',
                        'author' => 'Authors',
                        'series' => 'Series',
                        _ => 'By month',
                      }),
                      selected: _field != null,
                      onSelected: (_) =>
                          _reload(field: _defaultField, changeField: true),
                    ),
                ],
              ),
            ),
          if (_field == null && widget.filters.isEmpty)
            MediaBrowserSection(
              initialLibraryId: widget.library.id,
              onOpenItem: (item) => context.push(MediaVisuals.route(item)),
            )
          else
            FutureBuilder<_CatalogPage>(
              future: _page,
              builder: (context, snapshot) {
                if (snapshot.hasError)
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('This catalog page could not load.'),
                      TextButton(
                        onPressed: _reload,
                        child: const Text('Try again'),
                      ),
                    ],
                  );
                if (!snapshot.hasData) return const LinearProgressIndicator();
                final page = snapshot.data!;
                final rows = page.rows.take(60).toList();
                final listening =
                    _field == null &&
                    {
                      LibraryKind.music,
                      LibraryKind.audiobooks,
                      LibraryKind.podcasts,
                    }.contains(widget.kind);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _sectionTitle,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    if (listening && rows.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: FilledButton.icon(
                          icon: const Icon(Icons.queue_music),
                          label: Text(
                            'Play these ${rows.length} tracks in order',
                          ),
                          onPressed: () async {
                            final ids = rows
                                .map((row) => row.data['item_id'] as String)
                                .toList();
                            await PlayerLibraryRepository(
                              ref.read(appDatabaseProvider),
                            ).setQueue(ids);
                            if (context.mounted)
                              context.push(
                                '/player/${Uri.encodeComponent(ids.first)}?queue=1',
                              );
                          },
                        ),
                      ),
                    if (rows.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            Icon(_groupIcon, size: 48),
                            const SizedBox(height: 12),
                            const Text(
                              'No identified groups here yet. Add catalog metadata from a title’s Details page, or browse all files.',
                            ),
                            TextButton(
                              onPressed: () => _reload(changeField: true),
                              child: const Text('Browse files in this group'),
                            ),
                          ],
                        ),
                      ),
                    LayoutBuilder(
                      builder: (context, box) {
                        final columns = (box.maxWidth / 190).floor().clamp(
                          1,
                          6,
                        );
                        final width =
                            (box.maxWidth - (columns - 1) * 16) / columns;
                        final textScale =
                            MediaQuery.textScalerOf(context).scale(14) / 14;
                        final poster =
                            _field == null ||
                            {'show', 'season', 'author'}.contains(_field);
                        return GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: rows.length,
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: columns,
                                crossAxisSpacing: 16,
                                mainAxisSpacing: 16,
                                mainAxisExtent:
                                    width * (poster ? 1.5 : 1) + 96 * textScale,
                              ),
                          itemBuilder: (context, index) {
                            final row = rows[index],
                                item =
                                    page.artwork[rows[index].data['item_id']];
                            if (_field != null)
                              return CinematicGroupCard(
                                item: item,
                                icon: _groupIcon,
                                title: _groupTitle(row.data['value'] as String),
                                subtitle: '${row.data['count']} files',
                                onOpen: () =>
                                    _drill(row.data['value'] as String),
                              );
                            if (item == null) return const SizedBox.shrink();
                            return CinematicMediaCard(
                              item: item,
                              displayTitle:
                                  row.data['effective_title'] as String?,
                              subtitle: widget.kind == LibraryKind.television
                                  ? CatalogHints.episodeLabel(row.data)
                                  : null,
                              progressPercent: (row.data['progress'] as num?)
                                  ?.toDouble(),
                              onDetails: () => _details(item),
                              onOpen: () =>
                                  context.push(MediaVisuals.route(item)),
                            );
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    if (_history.isNotEmpty || page.rows.length > 60)
                      Row(
                        children: [
                          TextButton(
                            onPressed: _history.isEmpty
                                ? null
                                : () => setState(() {
                                    _after = _history.removeLast();
                                    _page = _load();
                                  }),
                            child: const Text('Previous'),
                          ),
                          TextButton(
                            onPressed: page.rows.length <= 60
                                ? null
                                : () => setState(() {
                                    _history.add(_after);
                                    _after =
                                        rows.last.data['sort_key'] as String;
                                    _page = _load();
                                  }),
                            child: const Text('Next'),
                          ),
                        ],
                      ),
                  ],
                );
              },
            ),
        ],
      ),
    ),
  );
}
