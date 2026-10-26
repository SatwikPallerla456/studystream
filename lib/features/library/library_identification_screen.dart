import 'dart:async';
import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/db/app_database.dart';
import '../../data/providers/app_providers.dart';
import '../../domain/catalog/catalog_identity_store.dart';
import '../../domain/catalog/catalog_hints.dart';
import '../../domain/catalog/media_catalog_repository.dart';
import '../../shared/widgets/app_top_bar.dart';
import '../../shared/widgets/media_categories.dart';
import '../../shared/widgets/study_ui.dart';
import '../media/catalog_editor_screen.dart';
import 'automatic_identification_controls.dart';

class LibraryIdentificationScreen extends ConsumerStatefulWidget {
  const LibraryIdentificationScreen({super.key, required this.libraryId});
  final String libraryId;
  @override
  ConsumerState<LibraryIdentificationScreen> createState() =>
      _IdentificationState();
}

class _IdentificationState extends ConsumerState<LibraryIdentificationScreen> {
  StreamSubscription<dynamic>? _updates;
  @override
  void initState() {
    super.initState();
    _updates = ref
        .read(libraryProcessingProvider)
        .store
        .watchSummary(widget.libraryId)
        .listen((_) {
          if (mounted) _reload();
        }, onError: (Object _) {});
  }

  final _search = TextEditingController();
  String? _after;
  final _history = <String?>[];
  bool _busy = false;
  String? _message;
  late Future<List<({Item item, Map<String, dynamic> data})>> _page = _load();
  Future<List<({Item item, Map<String, dynamic> data})>> _load() async {
    final db = ref.read(appDatabaseProvider);
    final rows = await db
        .customSelect(
          "SELECT i.*,j.state AS identification_state,j.error_code AS identification_reason,m.origin AS match_origin FROM items i LEFT JOIN library_processing_jobs j ON j.item_id=i.id AND j.kind='identify' LEFT JOIN match_decisions m ON m.item_id=i.id WHERE i.library_id=? AND i.id>? AND (i.filename LIKE ? OR i.title LIKE ?) ORDER BY i.id LIMIT 41",
          variables: [
            drift.Variable(widget.libraryId),
            drift.Variable(_after ?? ''),
            drift.Variable('%${_search.text.trim()}%'),
            drift.Variable('%${_search.text.trim()}%'),
          ],
        )
        .get();
    final catalog = MediaCatalogRepository(db);
    return [
      for (final row in rows)
        (
          item: db.items.map(row.data),
          data: {
            ...await catalog.metadata(db.items.map(row.data)),
            '_identificationState': row.data['identification_state'],
            '_identificationReason': row.data['identification_reason'],
            '_matchOrigin': row.data['match_origin'],
          },
        ),
    ];
  }

  void _reload() => setState(() {
    _page = _load();
  });
  Future<void> _reidentify() async {
    setState(() {
      _busy = true;
      _message = 'Identifying local filenames and categories…';
    });
    try {
      final db = ref.read(appDatabaseProvider),
          store = CatalogIdentityStore(ref.read(appDatabaseProvider));
      var cursor = '', count = 0;
      while (mounted) {
        final rows = await db
            .customSelect(
              'SELECT * FROM items WHERE library_id=? AND id>? ORDER BY id LIMIT 200',
              variables: [
                drift.Variable(widget.libraryId),
                drift.Variable(cursor),
              ],
            )
            .get();
        if (rows.isEmpty) break;
        await db.transaction(() async {
          for (final row in rows) await store.reindex(db.items.map(row.data));
        });
        cursor = rows.last.data['id'] as String;
        count += rows.length;
        if (mounted)
          setState(() => _message = '$count files identified locally');
      }
      if (mounted)
        setState(() {
          _page = _load();
        });
    } catch (_) {
      if (mounted)
        setState(
          () => _message =
              'Identification could not finish. Your saved corrections were kept.',
        );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _updates?.cancel();
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: const AppTopBar(title: 'Identify titles', showBack: true),
    body: StudyPage(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StudyPageHeader(
            title: 'Identify titles',
            actions: [
              OutlinedButton.icon(
                onPressed: _busy ? null : _reidentify,
                icon: const Icon(Icons.auto_fix_high),
                label: Text(
                  _busy ? 'Identifying…' : 'Refresh local identification',
                ),
              ),
            ],
          ),
          const Text(
            'Confident movie and TV matches receive metadata automatically. Review uncertain titles or use Find match to choose or correct any match.',
          ),
          AutomaticIdentificationControls(
            libraryId: widget.libraryId,
            onQueued: _reload,
          ),
          const SizedBox(height: 16),
          if (_message != null) Text(_message!),
          TextField(
            controller: _search,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Find a filename or title',
            ),
            onChanged: (_) {
              _after = null;
              _history.clear();
              _reload();
            },
          ),
          const SizedBox(height: 16),
          FutureBuilder(
            future: _page,
            builder: (context, snapshot) {
              if (snapshot.hasError)
                return TextButton(
                  onPressed: _reload,
                  child: const Text('Reload titles'),
                );
              if (!snapshot.hasData) return const LinearProgressIndicator();
              final rows = snapshot.data!;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (rows.isEmpty)
                    const Text(
                      'No files to identify. Scan a source folder or change the search.',
                    ),
                  for (final row in rows.take(40))
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${row.data['title'] ?? row.item.title}',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            SelectableText(row.item.filename),
                            Text(
                              [
                                row.data['matchState'] == 'matched'
                                    ? row.data['_matchOrigin'] == 'automatic'
                                          ? 'Automatically matched · TheTVDB'
                                          : 'Catalog matched'
                                    : row.data['_identificationState'] ==
                                          'review'
                                    ? 'Needs review · use Find match'
                                    : row.data['_identificationState'] ==
                                              'queued' ||
                                          row.data['_identificationState'] ==
                                              'running'
                                    ? 'Identification queued'
                                    : 'Local filename hints',
                                if (row.data['year'] != null)
                                  '${row.data['year']}',
                                if (CatalogHints.episodeLabel(row.data)
                                    case final String episode)
                                  episode,
                              ].join(' · '),
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 16,
                              runSpacing: 12,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                SizedBox(
                                  width: 240,
                                  child: DropdownButtonFormField<String>(
                                    key: ValueKey(
                                      '${row.item.id}:${row.data['category']}',
                                    ),
                                    initialValue:
                                        LibraryKind.values.any(
                                          (k) => k.name == row.data['category'],
                                        )
                                        ? row.data['category'] as String
                                        : 'mixed',
                                    decoration: const InputDecoration(
                                      labelText: 'Category',
                                    ),
                                    items: [
                                      for (final kind in LibraryKind.values)
                                        DropdownMenuItem(
                                          value: kind.name,
                                          child: Row(
                                            children: [
                                              Icon(
                                                mediaCategoryIcon(kind),
                                                size: 18,
                                              ),
                                              const SizedBox(width: 8),
                                              Text(kind.label),
                                            ],
                                          ),
                                        ),
                                    ],
                                    onChanged: _busy
                                        ? null
                                        : (value) async {
                                            if (value == null) return;
                                            try {
                                              await CatalogIdentityStore(
                                                ref.read(appDatabaseProvider),
                                              ).override(
                                                row.item,
                                                'category',
                                                value,
                                              );
                                              if (mounted) _reload();
                                            } catch (_) {
                                              if (mounted)
                                                setState(
                                                  () => _message =
                                                      'Category could not be saved. Try again.',
                                                );
                                            }
                                          },
                                  ),
                                ),
                                OutlinedButton.icon(
                                  onPressed: _busy
                                      ? null
                                      : () async {
                                          await Navigator.of(context).push(
                                            MaterialPageRoute<void>(
                                              builder: (_) =>
                                                  CatalogEditorScreen(
                                                    item: row.item,
                                                  ),
                                            ),
                                          );
                                          if (mounted) _reload();
                                        },
                                  icon: const Icon(Icons.manage_search),
                                  label: const Text(
                                    'Find match / edit details',
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  Wrap(
                    spacing: 12,
                    children: [
                      if (_history.isNotEmpty)
                        TextButton(
                          onPressed: () {
                            _after = _history.removeLast();
                            _reload();
                          },
                          child: const Text('Previous'),
                        ),
                      if (rows.length > 40)
                        TextButton(
                          onPressed: () {
                            _history.add(_after);
                            _after = rows[39].item.id;
                            _reload();
                          },
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
