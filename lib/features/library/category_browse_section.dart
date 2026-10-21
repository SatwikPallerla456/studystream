import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../data/db/app_database.dart';
import '../../data/providers/app_providers.dart';
import '../../domain/catalog/category_browse_repository.dart';
import '../../domain/catalog/catalog_hints.dart';
import '../../domain/catalog/media_catalog_repository.dart';
import '../../domain/services/player_library_repository.dart';
import '../../shared/widgets/app_top_bar.dart';
import '../../shared/widgets/cinematic_media.dart';
import '../../shared/widgets/item_artwork.dart';
import '../../shared/widgets/media_categories.dart';
import '../../shared/widgets/study_ui.dart';

bool hasCategoryHierarchy(LibraryKind kind) => {
  LibraryKind.television,
  LibraryKind.music,
  LibraryKind.books,
  LibraryKind.comics,
}.contains(kind);
String? _firstGroup(LibraryKind kind) => switch (kind) {
  LibraryKind.television => 'show',
  LibraryKind.music => 'artist',
  LibraryKind.comics => 'series',
  _ => null,
};
String _fieldLabel(String? field, LibraryKind kind) => switch (field) {
  'show' => 'Shows',
  'season' => 'Seasons',
  'artist' => 'Artists',
  'album' => 'Albums',
  'author' => 'Authors',
  'series' => 'Series',
  _ =>
    kind == LibraryKind.television
        ? 'Episodes'
        : kind == LibraryKind.music
        ? 'Tracks'
        : kind == LibraryKind.comics
        ? 'Volumes & chapters'
        : 'Books',
};
String _groupLabel(String field, String value, LibraryKind kind) {
  if (value.isNotEmpty)
    return field == 'season'
        ? value == '0'
              ? 'Specials'
              : 'Season $value'
        : value;
  return switch (field) {
    'show' => 'Unidentified shows',
    'season' => 'Season not identified',
    'artist' => 'Unknown artist',
    'album' => 'Unknown album',
    'author' => 'Unknown author',
    _ =>
      kind == LibraryKind.comics ? 'Series not identified' : 'Standalone books',
  };
}

/// The same visible hierarchy at category roots and inside named libraries.
class CategoryBrowseSection extends ConsumerStatefulWidget {
  const CategoryBrowseSection({
    super.key,
    required this.kind,
    this.libraryId,
    this.filters = const {},
    this.group,
    this.nested = false,
    this.emptyAction,
    this.rootRoute,
  });
  final LibraryKind kind;
  final String? libraryId;
  final Map<String, String> filters;
  final String? group;
  final bool nested;
  final Widget? emptyAction;
  final Route<dynamic>? rootRoute;
  @override
  ConsumerState<CategoryBrowseSection> createState() => _CategoryBrowseState();
}

class _CategoryBrowseState extends ConsumerState<CategoryBrowseSection> {
  final _search = TextEditingController();
  late String? _group = widget.nested ? widget.group : _firstGroup(widget.kind);
  String? _library;
  ShelfStatus _status = ShelfStatus.all;
  ReadingUnits _units = ReadingUnits.all;
  (String, String)? _after;
  final _history = <(String, String)?>[];
  Timer? _searchTimer, _refreshTimer;
  StreamSubscription<dynamic>? _changes;
  bool _busy = false;
  String? _message;
  late Future<CategoryPage> _page;
  bool get _reading =>
      {LibraryKind.books, LibraryKind.comics}.contains(widget.kind);
  CategoryScope get _scope => CategoryScope(
    kind: widget.kind,
    libraryId: widget.libraryId ?? _library,
    filters: widget.filters,
    query: _search.text,
    status: _status,
    units: _units,
  );
  CategoryBrowseRepository get _repo =>
      CategoryBrowseRepository(ref.read(appDatabaseProvider));
  @override
  void initState() {
    super.initState();
    _page = _load();
    final db = ref.read(appDatabaseProvider);
    _changes = db
        .customSelect(
          'SELECT COUNT(*) AS count FROM items',
          readsFrom: {
            db.items,
            db.libraries,
            db.playbackProgress,
            db.readingProgress,
          },
        )
        .watch()
        .listen((_) {
          _refreshTimer?.cancel();
          _refreshTimer = Timer(const Duration(milliseconds: 250), () {
            if (mounted) _reload(reset: false);
          });
        });
  }

  Future<CategoryPage> _load() =>
      _repo.page(_scope, group: _group, after: _after);
  void _reload({bool reset = true}) => setState(() {
    if (reset) {
      _after = null;
      _history.clear();
    }
    _page = _load();
  });
  void _changeGroup(String? group) => setState(() {
    _group = group;
    _after = null;
    _history.clear();
    _page = _load();
  });
  @override
  void dispose() {
    _changes?.cancel();
    _searchTimer?.cancel();
    _refreshTimer?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _openGroup(CategoryGroup group) async {
    final filters = {...widget.filters};
    var title = _groupLabel(_group!, group.label ?? group.value, widget.kind);
    if (_group == 'album' && !filters.containsKey('artist')) {
      final pair = (jsonDecode(group.value) as List).cast<String>();
      filters.addAll({'artist': pair[0], 'album': pair[1]});
    } else {
      filters[_group!] = group.value;
    }
    final next = switch (_group) {
      'show' => 'season',
      'artist' => 'album',
      'author' => 'series',
      _ => null,
    };
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _CategoryDrillScreen(
          kind: widget.kind,
          libraryId: widget.libraryId ?? _library,
          filters: filters,
          group: next,
          title: title,
          rootRoute: widget.rootRoute ?? ModalRoute.of(context),
        ),
      ),
    );
    if (mounted) _reload(reset: false);
  }

  Future<void> _details(Item item) async {
    await context.push('/details/${Uri.encodeComponent(item.id)}');
    if (mounted) _reload(reset: false);
  }

  Future<void> _play({
    String? start,
    bool shuffle = false,
    bool nextUnwatched = false,
  }) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final ids = await _repo.queue(_scope, unfinishedOnly: nextUnwatched);
      if (ids.isEmpty)
        throw const FormatException('No playable titles in this selection.');
      final selected = start == null
          ? shuffle
                ? Random().nextInt(ids.length)
                : 0
          : ids.indexOf(start);
      if (selected < 0)
        throw const FormatException(
          'This title changed. Refresh the list and try again.',
        );
      final repository = PlayerLibraryRepository(ref.read(appDatabaseProvider));
      await ref.read(appDatabaseProvider).transaction(() async {
        await repository.setShuffle(false);
        await repository.setQueue(ids, currentIndex: selected);
        if (shuffle) await repository.setShuffle(true);
      });
      if (mounted)
        await context.push(
          '/player/${Uri.encodeComponent(ids[selected])}?queue=1',
        );
    } catch (error) {
      if (mounted)
        setState(
          () => _message = error is FormatException
              ? error.message.toString()
              : 'Playback could not start. Refresh this selection and try again.',
        );
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        _reload(reset: false);
      }
    }
  }

  String _count(CategoryGroup group) {
    final singular = widget.kind == LibraryKind.music
        ? 'track'
        : widget.kind == LibraryKind.television
        ? 'episode file'
        : widget.kind == LibraryKind.comics
        ? 'comic'
        : 'book';
    final unit = group.count == 1 ? singular : '${singular}s';
    return '${group.count} $unit${group.inProgress > 0 ? ' · ${group.inProgress} in progress' : ''}${group.completed > 0 ? ' · ${group.completed} completed' : ''}${group.unavailable > 0 ? ' · ${group.unavailable} offline' : ''}';
  }

  Widget _roots() => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      for (final group in switch (widget.kind) {
        LibraryKind.television => <String?>['show', null],
        LibraryKind.music => <String?>['artist', 'album', null],
        _ => <String?>[null, 'series', 'author'],
      })
        ChoiceChip(
          label: Text(_fieldLabel(group, widget.kind)),
          selected: _group == group,
          onSelected: (_) => _changeGroup(group),
        ),
    ],
  );
  Widget _statusFilters() => SizedBox(
    width: 180,
    child: DropdownButtonFormField<ShelfStatus>(
      key: ValueKey(_status),
      initialValue: _status,
      decoration: InputDecoration(
        labelText: _reading ? 'Reading status' : 'Watch status',
      ),
      items: [
        for (final status in ShelfStatus.values)
          DropdownMenuItem(
            value: status,
            child: Text(switch (status) {
              ShelfStatus.all => 'All',
              ShelfStatus.inProgress => _reading ? 'Reading' : 'In progress',
              ShelfStatus.unread => _reading ? 'Unread' : 'Unwatched',
              ShelfStatus.completed => _reading ? 'Read' : 'Watched',
            }),
          ),
      ],
      onChanged: (value) {
        if (value != null) {
          _status = value;
          _reload();
        }
      },
    ),
  );
  Widget _libraryFilter() {
    final db = ref.read(appDatabaseProvider);
    return StreamBuilder<List<Library>>(
      stream: db
          .customSelect(
            '''SELECT l.* FROM libraries l WHERE
        EXISTS(SELECT 1 FROM items i JOIN catalog_facets f ON f.item_id=i.id
          WHERE i.library_id=l.id AND f.field='category' AND f.value=?)
        OR EXISTS(SELECT 1 FROM media_records m WHERE m.id='library:'||l.id
          AND m.deleted=0 AND json_extract(m.payload,'\$.type')=?)
        ORDER BY l.title,l.id LIMIT 200''',
            variables: [
              drift.Variable(widget.kind.name),
              drift.Variable(widget.kind.name),
            ],
            readsFrom: {db.items, db.libraries},
          )
          .watch()
          .map(
            (rows) => rows.map((row) => db.libraries.map(row.data)).toList(),
          ),
      builder: (context, snapshot) {
        final libraries = snapshot.data ?? [];
        final selected = libraries.any((l) => l.id == _library)
            ? _library
            : null;
        if (snapshot.hasData && _library != null && selected == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _library != null) {
              _library = null;
              _reload();
            }
          });
        }
        if (snapshot.hasData && libraries.length < 2)
          return const SizedBox.shrink();
        return SizedBox(
          width: 280,
          child: DropdownButtonFormField<String>(
            key: ValueKey(selected),
            initialValue: selected ?? '',
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Source library'),
            items: [
              const DropdownMenuItem(
                value: '',
                child: Text('All source libraries'),
              ),
              for (final library in libraries)
                DropdownMenuItem(
                  value: library.id,
                  child: Text(
                    library.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: (value) {
              _library = value == '' ? null : value;
              _reload();
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (!widget.nested) ...[_roots(), const SizedBox(height: 16)],
      Wrap(
        spacing: 16,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 420,
            child: TextField(
              controller: _search,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                labelText: 'Search ${widget.kind.label.toLowerCase()}',
                hintText: widget.kind == LibraryKind.music
                    ? 'Title, artist or album'
                    : widget.kind == LibraryKind.television
                    ? 'Show or episode title'
                    : 'Title, author or series',
                suffixIcon: _search.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear search',
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _search.clear();
                          _reload();
                        },
                      ),
              ),
              onChanged: (_) {
                _searchTimer?.cancel();
                _searchTimer = Timer(const Duration(milliseconds: 250), () {
                  if (mounted) _reload();
                });
              },
            ),
          ),
          if (_reading || widget.kind == LibraryKind.television)
            _statusFilters(),
          if (widget.libraryId == null && !widget.nested) _libraryFilter(),
        ],
      ),
      if (widget.kind == LibraryKind.comics &&
          widget.filters.containsKey('series')) ...[
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final units in ReadingUnits.values)
              ChoiceChip(
                label: Text(switch (units) {
                  ReadingUnits.all => 'All formats',
                  ReadingUnits.volumes => 'Volumes',
                  ReadingUnits.chapters => 'Chapters / issues',
                }),
                selected: _units == units,
                onSelected: (_) {
                  _units = units;
                  _reload();
                },
              ),
          ],
        ),
      ],
      const SizedBox(height: 20),
      if (_message != null)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(_message!),
        ),
      if (_busy) const LinearProgressIndicator(),
      FutureBuilder<CategoryPage>(
        future: _page,
        builder: (context, snapshot) {
          if (snapshot.hasError)
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('This catalog page could not load.'),
                TextButton(
                  onPressed: () => _reload(reset: false),
                  child: const Text('Try again'),
                ),
              ],
            );
          if (!snapshot.hasData) return const LinearProgressIndicator();
          final page = snapshot.data!;
          if (page.groups.isEmpty && page.titles.isEmpty)
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(mediaCategoryIcon(widget.kind), size: 48),
                  const SizedBox(height: 12),
                  Text(
                    widget.filters.isEmpty &&
                            _search.text.isEmpty &&
                            _status == ShelfStatus.all
                        ? 'No ${widget.kind.label.toLowerCase()} yet'
                        : 'No titles match this selection',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(switch (widget.kind) {
                    LibraryKind.television =>
                      'Browse shows, then seasons and episodes. Scan a source or identify files to organize your TV library.',
                    LibraryKind.music =>
                      'Browse artists, albums and numbered tracks. Embedded tags and chosen catalog matches organize your music.',
                    LibraryKind.comics =>
                      'Browse series, volumes and chapters. Local filename hints help organize comics; title details can correct them.',
                    _ =>
                      'Browse your book shelf, authors and series. Reading progress stays attached to each book.',
                  }),
                  if (widget.emptyAction != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: widget.emptyAction!,
                    ),
                  if (_status != ShelfStatus.all ||
                      _search.text.isNotEmpty ||
                      _units != ReadingUnits.all)
                    TextButton(
                      onPressed: () {
                        _status = ShelfStatus.all;
                        _units = ReadingUnits.all;
                        _search.clear();
                        _reload();
                      },
                      child: const Text('Reset filters'),
                    ),
                ],
              ),
            );
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    '${_fieldLabel(_group, widget.kind)}${page.more ? ' · more on the next page' : ''}',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  if (widget.kind == LibraryKind.music ||
                      widget.kind == LibraryKind.television &&
                          _group == null) ...[
                    FilledButton.icon(
                      onPressed: _busy
                          ? null
                          : () => _play(
                              nextUnwatched:
                                  widget.kind == LibraryKind.television,
                            ),
                      icon: const Icon(Icons.play_arrow),
                      label: Text(
                        widget.kind == LibraryKind.television
                            ? 'Play next unwatched'
                            : widget.filters.containsKey('album')
                            ? 'Play album'
                            : 'Play selection',
                      ),
                    ),
                    if (widget.kind == LibraryKind.music)
                      OutlinedButton.icon(
                        onPressed: _busy ? null : () => _play(shuffle: true),
                        icon: const Icon(Icons.shuffle),
                        label: const Text('Shuffle selection'),
                      ),
                  ],
                ],
              ),
              const SizedBox(height: 12),
              if (_group != null)
                _grid(page.groups.length, (index) {
                  final group = page.groups[index];
                  final name = _groupLabel(
                    _group!,
                    group.label ?? group.value,
                    widget.kind,
                  );
                  return CinematicGroupCard(
                    item: group.cover,
                    artworkFit: _reading ? BoxFit.contain : BoxFit.cover,
                    title: name,
                    subtitle:
                        '${group.qualifier == null ? '' : '${_groupLabel('artist', group.qualifier!, widget.kind)} · '}${_count(group)}',
                    icon: switch (_group) {
                      'show' || 'season' => Icons.live_tv,
                      'artist' => Icons.person_outline,
                      'album' => Icons.album_outlined,
                      _ => Icons.auto_stories_outlined,
                    },
                    onOpen: () => _openGroup(group),
                  );
                }, square: widget.kind == LibraryKind.music)
              else if (_reading)
                _grid(page.titles.length, (index) {
                  final title = page.titles[index],
                      metadata = page.titles[index].metadata;
                  return CinematicMediaCard(
                    item: title.item,
                    displayTitle: '${metadata['title'] ?? title.item.title}',
                    subtitle: _readingLabel(title),
                    progressPercent: title.progress,
                    actionLabel: title.progress > 0 && !title.completed
                        ? 'Resume reading'
                        : 'Read',
                    onDetails: () => _details(title.item),
                    onOpen: () => context.push(MediaVisuals.route(title.item)),
                  );
                }, square: false)
              else
                for (final title in page.titles) _mediaRow(title),
              if (_history.isNotEmpty || page.more)
                Padding(
                  padding: const EdgeInsets.only(top: 20),
                  child: Wrap(
                    spacing: 12,
                    children: [
                      OutlinedButton(
                        onPressed: _history.isEmpty
                            ? null
                            : () => setState(() {
                                _after = _history.removeLast();
                                _page = _load();
                              }),
                        child: const Text('Previous page'),
                      ),
                      OutlinedButton(
                        onPressed: !page.more || page.cursor == null
                            ? null
                            : () => setState(() {
                                _history.add(_after);
                                _after = page.cursor;
                                _page = _load();
                              }),
                        child: const Text('Next page'),
                      ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    ],
  );
  String _readingLabel(CategoryTitle title) => [
    if (title.metadata['volume'] != null) 'Volume ${title.metadata['volume']}',
    if (title.metadata['chapter'] != null)
      'Chapter ${title.metadata['chapter']}',
    if (title.metadata['author'] != null) '${title.metadata['author']}',
    title.completed
        ? 'Read'
        : title.progress > 0
        ? '${title.progress.round()}% read'
        : 'Unread',
  ].join(' · ');
  Widget _grid(
    int count,
    Widget Function(int) builder, {
    required bool square,
  }) => LayoutBuilder(
    builder: (context, box) {
      final columns = (box.maxWidth / (_group == null && _reading ? 150 : 185))
              .floor()
              .clamp(1, 6),
          width = (box.maxWidth - (columns - 1) * 16) / columns;
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: count,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          mainAxisExtent:
              width *
                  (square
                      ? 1
                      : _group != null
                      ? 1.2
                      : 1.5) +
              MediaQuery.textScalerOf(context).scale(80),
        ),
        itemBuilder: (_, index) => builder(index),
      );
    },
  );
  Widget _mediaRow(CategoryTitle title) {
    final metadata = title.metadata, tv = widget.kind == LibraryKind.television;
    final number = tv
        ? metadata['episode'] == null
              ? '—'
              : 'E${metadata['episode']}${metadata['episodeEnd'] == null ? '' : '–${metadata['episodeEnd']}'}'
        : '${metadata['disc'] == null ? '' : '${metadata['disc']}.'}${metadata['track'] ?? '—'}';
    final duration = title.item.durationSeconds;
    final subtitle = [
      if (tv && CatalogHints.episodeLabel(metadata) != null)
        CatalogHints.episodeLabel(metadata)!,
      if (!tv && metadata['artist'] != null) '${metadata['artist']}',
      if (!tv && metadata['album'] != null) '${metadata['album']}',
      if (duration != null)
        '${duration ~/ 60}:${(duration.toInt() % 60).toString().padLeft(2, '0')}',
      if (metadata['edition'] is String &&
          (metadata['edition'] as String).isNotEmpty)
        '${metadata['edition']}',
      title.item.filename.split('.').last.toUpperCase(),
      if (title.item.unavailable) 'Source offline',
      if (title.completed)
        tv ? 'Watched' : 'Played'
      else if (title.progress > 0)
        '${title.progress.round()}%',
      if (widget.libraryId == null) title.libraryTitle,
    ].join(' · ');
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        leading: SizedBox(
          width: 88,
          child: Row(
            children: [
              SizedBox(width: 32, child: Text(number, maxLines: 2)),
              const SizedBox(width: 8),
              ItemArtwork(item: title.item, size: 48),
            ],
          ),
        ),
        title: Text(
          '${metadata['title'] ?? title.item.title}',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(subtitle),
            if (title.progress > 0 && !title.completed)
              LinearProgressIndicator(
                value: (title.progress / 100).clamp(0, 1),
              ),
          ],
        ),
        onTap: () => _details(title.item),
        trailing: IconButton(
          tooltip: title.progress > 0 && !title.completed ? 'Resume' : 'Play',
          onPressed: _busy || title.item.unavailable
              ? null
              : () => _play(start: title.item.id),
          icon: const Icon(Icons.play_circle_outline),
        ),
      ),
    );
  }
}

class _CategoryDrillScreen extends StatelessWidget {
  const _CategoryDrillScreen({
    required this.kind,
    required this.libraryId,
    required this.filters,
    required this.group,
    required this.title,
    required this.rootRoute,
  });
  final LibraryKind kind;
  final String? libraryId, group;
  final Map<String, String> filters;
  final String title;
  final Route<dynamic>? rootRoute;
  void _ancestor(BuildContext context, String key) {
    final prefix = <String, String>{};
    for (final entry in filters.entries) {
      prefix[entry.key] = entry.value;
      if (entry.key == key) break;
    }
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => _CategoryDrillScreen(
          kind: kind,
          libraryId: libraryId,
          filters: prefix,
          title: _groupLabel(key, filters[key]!, kind),
          group: switch (key) {
            'show' => 'season',
            'artist' => 'album',
            'author' => 'series',
            _ => null,
          },
          rootRoute: rootRoute,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppTopBar(title: title, showBack: true),
    body: StudyPage(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 4,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              TextButton(
                onPressed: () => Navigator.of(context).popUntil(
                  (route) => identical(route, rootRoute) || route.isFirst,
                ),
                child: Text(kind.label),
              ),
              for (final entry in filters.entries) ...[
                const Icon(Icons.chevron_right, size: 16),
                TextButton(
                  onPressed: entry.key == filters.keys.last
                      ? null
                      : () => _ancestor(context, entry.key),
                  child: Text(_groupLabel(entry.key, entry.value, kind)),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          CategoryBrowseSection(
            kind: kind,
            libraryId: libraryId,
            filters: filters,
            group: group,
            nested: true,
            rootRoute: rootRoute,
          ),
        ],
      ),
    ),
  );
}
