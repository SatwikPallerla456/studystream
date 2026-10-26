import 'dart:async';
import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../data/db/app_database.dart';
import '../../data/providers/app_providers.dart';
import '../../domain/catalog/media_catalog_repository.dart';
import '../../shared/widgets/app_top_bar.dart';
import '../../shared/widgets/cinematic_media.dart';
import 'collection_details_screen.dart';
import '../../domain/catalog/catalog_discovery_repository.dart';
import '../../shared/widgets/catalog_browse_controls.dart';

Future<void> editCatalogCollection(
  BuildContext context, {
  required String libraryId,
  MediaRecord? record,
  Item? initial,
}) async {
  if (record != null) {
    final db = ProviderScope.containerOf(context).read(appDatabaseProvider);
    record = await MediaCatalogRepository(db).record(record.id);
    if (!context.mounted || record == null) return;
  }
  await Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => _CollectionEditor(
        libraryId: libraryId,
        record: record,
        initial: initial,
      ),
    ),
  );
}

class CollectionsScreen extends ConsumerStatefulWidget {
  const CollectionsScreen({super.key, this.libraryId, this.item});
  final String? libraryId;
  final Item? item;
  @override
  ConsumerState<CollectionsScreen> createState() => _CollectionsState();
}

class _CollectionsState extends ConsumerState<CollectionsScreen> {
  (String, String)? _after;
  final _history = <(String, String)?>[];
  late Future<List<drift.QueryRow>> _rows = _load();
  Future<List<drift.QueryRow>> _load() => ref
      .read(appDatabaseProvider)
      .customSelect(
        "SELECT *,(SELECT title FROM libraries WHERE id=media_records.library_id) AS library_title,lower(json_extract(payload,'\$.title')) AS sort_title FROM media_records WHERE ${widget.libraryId == null ? '1=1' : 'library_id=?'} AND kind IN ('collection','album') AND deleted=0 ${_after == null ? '' : "AND (lower(json_extract(payload,'\$.title')),id)>(?,?)"} ORDER BY sort_title,id LIMIT 61",
        variables: [
          if (widget.libraryId != null) drift.Variable(widget.libraryId!),
          if (_after != null) ...[
            drift.Variable(_after!.$1),
            drift.Variable(_after!.$2),
          ],
        ],
      )
      .get();
  Future<void> _edit([MediaRecord? record]) async {
    final libraryId =
        record?.libraryId ??
        widget.libraryId ??
        await chooseCatalogLibrary(context, allowAll: false);
    if (!mounted || libraryId == null || libraryId.isEmpty) return;
    await editCatalogCollection(
      context,
      libraryId: libraryId,
      record: record,
      initial: widget.item,
    );
    if (mounted) setState(() => _rows = _load());
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppTopBar(
      title: 'Collections and albums',
      showBack: true,
      actions: [
        IconButton(
          tooltip: 'New collection in this library',
          onPressed: () => _edit(),
          icon: const Icon(Icons.add),
        ),
      ],
    ),
    body: FutureBuilder<List<drift.QueryRow>>(
      future: _rows,
      builder: (context, snapshot) {
        if (snapshot.hasError)
          return const Center(child: Text('Collections could not load.'));
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());
        final rows = snapshot.data!.take(60).toList();
        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            if (rows.isEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.libraryId == null
                        ? 'Open a named library to create a collection or ordered album.'
                        : 'Create a collection from files in this library.',
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () => _edit(),
                    icon: const Icon(Icons.add),
                    label: const Text('New collection'),
                  ),
                ],
              ),
            for (final row in rows)
              Builder(
                builder: (context) {
                  final record = MediaRecord(row.data);
                  return ListTile(
                    title: Text(record.data['title'] as String),
                    subtitle: Text(
                      '${(record.data['items'] as List).length} items · ${record.kind} · ${row.data['library_title']}',
                    ),
                    trailing: widget.item == null
                        ? IconButton(
                            tooltip: 'Edit membership and order',
                            icon: const Icon(Icons.edit_outlined),
                            onPressed: () => _edit(record),
                          )
                        : IconButton(
                            tooltip: 'Add current title',
                            icon: Icon(
                              (record.data['items'] as List).contains(
                                    widget.item!.id,
                                  )
                                  ? Icons.check
                                  : Icons.add,
                            ),
                            onPressed:
                                (record.data['items'] as List).contains(
                                  widget.item!.id,
                                )
                                ? null
                                : () async {
                                    try {
                                      final catalog = MediaCatalogRepository(
                                        ref.read(appDatabaseProvider),
                                      );
                                      final current = await catalog.record(
                                        record.id,
                                      );
                                      if (current == null) return;
                                      await catalog.saveCollection(
                                        record.libraryId,
                                        current.data['title'] as String,
                                        [
                                          ...List<String>.from(
                                            current.data['items'] as List,
                                          ),
                                          widget.item!.id,
                                        ],
                                        id: record.id,
                                        type: record.kind,
                                      );
                                      if (mounted) {
                                        setState(() => _rows = _load());
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Added to collection.',
                                            ),
                                          ),
                                        );
                                      }
                                    } catch (_) {
                                      if (mounted)
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Could not add this title. Check the collection and try again.',
                                            ),
                                          ),
                                        );
                                    }
                                  },
                          ),
                    onTap: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => CollectionDetailsScreen(
                            collectionId: record.id,
                            onEdit: () => editCatalogCollection(
                              context,
                              libraryId: record.libraryId,
                              record: record,
                            ),
                          ),
                        ),
                      );
                      if (mounted) setState(() => _rows = _load());
                    },
                  );
                },
              ),
            if (_history.isNotEmpty || snapshot.data!.length > 60)
              Row(
                children: [
                  TextButton(
                    onPressed: _history.isEmpty
                        ? null
                        : () => setState(() {
                            _after = _history.removeLast();
                            _rows = _load();
                          }),
                    child: const Text('Previous'),
                  ),
                  TextButton(
                    onPressed: snapshot.data!.length <= 60
                        ? null
                        : () => setState(() {
                            _history.add(_after);
                            _after = (
                              rows.last.data['sort_title'] as String,
                              rows.last.data['id'] as String,
                            );
                            _rows = _load();
                          }),
                    child: const Text('Next'),
                  ),
                ],
              ),
          ],
        );
      },
    ),
  );
}

class _CollectionEditor extends ConsumerStatefulWidget {
  const _CollectionEditor({required this.libraryId, this.record, this.initial});
  final String libraryId;
  final MediaRecord? record;
  final Item? initial;
  @override
  ConsumerState<_CollectionEditor> createState() => _CollectionEditorState();
}

class _CollectionEditorState extends ConsumerState<_CollectionEditor> {
  late final _title = TextEditingController(
    text: widget.record?.data['title'] as String? ?? '',
  );
  final _query = TextEditingController();
  late final _ids = List<String>.from(
    widget.record?.data['items'] as List? ??
        [if (widget.initial != null) widget.initial!.id],
  );
  late String _type = widget.record?.kind ?? 'collection';
  List<Item> _matches = [];
  String? _error;
  bool _busy = false;
  int _generation = 0;
  (String, String)? _after;
  final _history = <(String, String)?>[];
  CatalogSearchPage? _matchPage;
  Timer? _searchTimer;
  Future<void> _search({bool reset = true}) async {
    final generation = ++_generation, db = ref.read(appDatabaseProvider);
    if (reset) {
      _after = null;
      _history.clear();
    }
    try {
      final page = await CatalogDiscoveryRepository(db).search(
        _query.text,
        kind: 'lesson',
        libraryId: widget.libraryId,
        byTitle: true,
        after: _after,
      );
      if (mounted && generation == _generation)
        setState(() {
          _matchPage = page;
          _matches = [
            for (final entry in page.entries)
              if (entry.item != null) entry.item!,
          ];
        });
    } catch (_) {
      if (mounted && generation == _generation)
        setState(
          () => _error = 'Member search could not load. Try another query.',
        );
    }
  }

  Future<void> _save({bool remove = false}) async {
    setState(() => _busy = true);
    try {
      final catalog = MediaCatalogRepository(ref.read(appDatabaseProvider));
      if (remove) {
        final record = widget.record!;
        await catalog.save(
          record.id,
          record.kind,
          widget.libraryId,
          record.data,
          deleted: true,
        );
      } else {
        await catalog.saveCollection(
          widget.libraryId,
          _title.text,
          _ids,
          id: widget.record?.id,
          type: _type,
        );
      }
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted)
        setState(
          () => _error =
              'The collection could not be saved. Check its name and selected files, then try again.',
        );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _searchTimer?.cancel();
    _title.dispose();
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppTopBar(
      title: widget.record == null ? 'New collection' : 'Edit collection',
      showBack: true,
    ),
    body: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        if (_error != null) Text(_error!),
        TextField(
          controller: _title,
          maxLength: 200,
          decoration: const InputDecoration(labelText: 'Name'),
          onChanged: (_) => setState(() {}),
        ),
        DropdownButtonFormField<String>(
          initialValue: _type,
          decoration: const InputDecoration(labelText: 'Collection type'),
          items: const [
            DropdownMenuItem(value: 'collection', child: Text('Collection')),
            DropdownMenuItem(value: 'album', child: Text('Ordered album')),
          ],
          onChanged: widget.record != null
              ? null
              : (value) => setState(() => _type = value!),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _query,
          decoration: const InputDecoration(
            labelText: 'Search files in this library',
            prefixIcon: Icon(Icons.search),
          ),
          onChanged: (_) {
            _generation++;
            _searchTimer?.cancel();
            setState(() {
              _matches = [];
              _matchPage = null;
              _history.clear();
              _after = null;
            });
            _searchTimer = Timer(const Duration(milliseconds: 240), () {
              if (mounted) _search();
            });
          },
        ),
        for (final item in _matches)
          ListTile(
            title: Text(item.userTitle ?? item.title),
            trailing: IconButton(
              icon: Icon(_ids.contains(item.id) ? Icons.check : Icons.add),
              onPressed: _ids.contains(item.id) || _ids.length >= 1000
                  ? null
                  : () => setState(() => _ids.add(item.id)),
            ),
          ),
        if (_history.isNotEmpty || _matchPage?.more == true)
          Wrap(
            children: [
              TextButton(
                onPressed: _history.isEmpty
                    ? null
                    : () {
                        _after = _history.removeLast();
                        _search(reset: false);
                      },
                child: const Text('Previous matches'),
              ),
              TextButton(
                onPressed: _matchPage?.more != true
                    ? null
                    : () {
                        _history.add(_after);
                        _after = _matchPage?.cursor;
                        _search(reset: false);
                      },
                child: const Text('More matches'),
              ),
            ],
          ),
        const Divider(),
        Text('${_ids.length} members'),
        ReorderableListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _ids.length,
          onReorder: (a, b) => setState(() {
            if (b > a) b--;
            _ids.insert(b, _ids.removeAt(a));
          }),
          itemBuilder: (context, index) => FutureBuilder<Item?>(
            key: ValueKey(_ids[index]),
            future: ref.read(appDatabaseProvider).getItemById(_ids[index]),
            builder: (context, snapshot) => ListTile(
              title: Text(
                snapshot.data?.userTitle ??
                    snapshot.data?.title ??
                    'Unavailable member',
              ),
              onTap: snapshot.data == null
                  ? null
                  : () => context.push(MediaVisuals.route(snapshot.data!)),
              trailing: IconButton(
                tooltip: 'Remove member',
                icon: const Icon(Icons.remove_circle_outline),
                onPressed: () => setState(() => _ids.removeAt(index)),
              ),
            ),
          ),
        ),
        FilledButton(
          onPressed: _busy || _title.text.trim().isEmpty ? null : () => _save(),
          child: const Text('Save collection'),
        ),
        if (widget.record != null)
          TextButton(
            onPressed: _busy ? null : () => _save(remove: true),
            child: const Text('Delete collection'),
          ),
      ],
    ),
  );
}
