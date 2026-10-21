import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../data/db/app_database.dart';
import '../../data/providers/app_providers.dart';
import '../../domain/catalog/media_catalog_repository.dart';
import '../../shared/widgets/app_top_bar.dart';
import '../../shared/widgets/cinematic_media.dart';

class CollectionsScreen extends ConsumerStatefulWidget {
  const CollectionsScreen({super.key, required this.libraryId, this.item});
  final String libraryId;
  final Item? item;
  @override
  ConsumerState<CollectionsScreen> createState() => _CollectionsState();
}

class _CollectionsState extends ConsumerState<CollectionsScreen> {
  String? _after;
  final _history = <String?>[];
  late Future<List<drift.QueryRow>> _rows = _load();
  Future<List<drift.QueryRow>> _load() => ref
      .read(appDatabaseProvider)
      .customSelect(
        "SELECT * FROM media_records WHERE library_id=? AND kind IN ('collection','album') AND deleted=0 ${_after == null ? '' : 'AND id>?'} ORDER BY id LIMIT 61",
        variables: [
          drift.Variable(widget.libraryId),
          if (_after != null) drift.Variable(_after!),
        ],
      )
      .get();
  Future<void> _edit([MediaRecord? record]) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _CollectionEditor(
          libraryId: widget.libraryId,
          record: record,
          initial: widget.item,
        ),
      ),
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
          tooltip: 'New collection',
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
                  const Text('Create a collection from files in this library.'),
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
                      '${(record.data['items'] as List).length} items · ${record.kind}',
                    ),
                    trailing: const Icon(Icons.edit_outlined),
                    onTap: () => _edit(record),
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
                            _after = rows.last.data['id'] as String;
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
  Future<void> _search() async {
    final generation = ++_generation, db = ref.read(appDatabaseProvider);
    final rows =
        await (db.select(db.items)
              ..where(
                (i) =>
                    i.libraryId.equals(widget.libraryId) &
                    i.title.contains(_query.text.trim()),
              )
              ..orderBy([
                (i) => drift.OrderingTerm.asc(i.title),
                (i) => drift.OrderingTerm.asc(i.id),
              ])
              ..limit(60))
            .get();
    if (mounted && generation == _generation) setState(() => _matches = rows);
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
          onChanged: (_) => _search(),
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
