import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;

import '../../core/utils/id_utils.dart';
import '../../data/db/app_database.dart';
import 'media_record_contract.dart';
import 'catalog_hints.dart';
import 'technical_media.dart';
import '../reader/reader_contract.dart';

/// Descriptive identities never replace Items or carry exact playback positions.
class CatalogIdentityStore {
  const CatalogIdentityStore(this.db);
  final AppDatabase db;
  static const tables = {
    'catalog_works',
    'provider_snapshots',
    'match_decisions',
    'catalog_overrides',
    'catalog_editions',
    'playable_representations',
    'media_parts',
    'media_extras',
    'technical_media',
    'embedded_tags',
    'catalog_memberships',
    'study_anchors',
  };
  Future<void> createTables() async {
    const definitions = {
      'embedded_tags':
          'id TEXT PRIMARY KEY,library_id TEXT NOT NULL REFERENCES libraries(id) ON DELETE CASCADE,item_id TEXT NOT NULL UNIQUE REFERENCES items(id) ON DELETE CASCADE,content_revision TEXT NOT NULL,payload TEXT NOT NULL,updated_at INTEGER NOT NULL',
      'study_anchors':
          'id TEXT PRIMARY KEY,library_id TEXT NOT NULL REFERENCES libraries(id) ON DELETE CASCADE,item_id TEXT NOT NULL REFERENCES items(id) ON DELETE CASCADE,note_id TEXT REFERENCES notes(id) ON DELETE CASCADE,bookmark_id TEXT REFERENCES bookmarks(id) ON DELETE CASCADE,payload TEXT NOT NULL,updated_at INTEGER NOT NULL',
      'catalog_works':
          'id TEXT PRIMARY KEY, library_id TEXT NOT NULL REFERENCES libraries(id) ON DELETE CASCADE, type TEXT NOT NULL, title TEXT NOT NULL, parent_id TEXT, payload TEXT NOT NULL, updated_at INTEGER NOT NULL',
      'provider_snapshots':
          'id TEXT PRIMARY KEY, library_id TEXT NOT NULL REFERENCES libraries(id) ON DELETE CASCADE, work_id TEXT NOT NULL REFERENCES catalog_works(id) ON DELETE CASCADE, provider_id TEXT NOT NULL, remote_id TEXT NOT NULL, payload TEXT NOT NULL, updated_at INTEGER NOT NULL',
      'match_decisions':
          'id TEXT PRIMARY KEY, library_id TEXT NOT NULL REFERENCES libraries(id) ON DELETE CASCADE, item_id TEXT NOT NULL UNIQUE REFERENCES items(id) ON DELETE CASCADE, work_id TEXT REFERENCES catalog_works(id), state TEXT NOT NULL, provider_id TEXT, remote_id TEXT, revision INTEGER NOT NULL, origin TEXT NOT NULL, payload TEXT NOT NULL, updated_at INTEGER NOT NULL',
      'catalog_overrides':
          'id TEXT PRIMARY KEY, library_id TEXT NOT NULL REFERENCES libraries(id) ON DELETE CASCADE, item_id TEXT NOT NULL REFERENCES items(id) ON DELETE CASCADE, field TEXT NOT NULL, value TEXT, removed INTEGER NOT NULL, locked INTEGER NOT NULL, revision INTEGER NOT NULL, updated_at INTEGER NOT NULL, UNIQUE(item_id,field)',
      'catalog_editions':
          'id TEXT PRIMARY KEY, library_id TEXT NOT NULL REFERENCES libraries(id) ON DELETE CASCADE, work_id TEXT NOT NULL REFERENCES catalog_works(id) ON DELETE CASCADE, title TEXT NOT NULL, payload TEXT NOT NULL, updated_at INTEGER NOT NULL',
      'playable_representations':
          'id TEXT PRIMARY KEY, library_id TEXT NOT NULL REFERENCES libraries(id) ON DELETE CASCADE, item_id TEXT NOT NULL UNIQUE REFERENCES items(id) ON DELETE CASCADE, edition_id TEXT NOT NULL REFERENCES catalog_editions(id) ON DELETE CASCADE, payload TEXT NOT NULL, updated_at INTEGER NOT NULL',
      'media_parts':
          'id TEXT PRIMARY KEY, library_id TEXT NOT NULL REFERENCES libraries(id) ON DELETE CASCADE, representation_id TEXT NOT NULL REFERENCES playable_representations(id) ON DELETE CASCADE, item_id TEXT NOT NULL REFERENCES items(id) ON DELETE CASCADE, position INTEGER NOT NULL, duration_seconds REAL, offset_seconds REAL, deleted INTEGER NOT NULL DEFAULT 0, updated_at INTEGER NOT NULL',
      'media_extras':
          'id TEXT PRIMARY KEY,library_id TEXT NOT NULL REFERENCES libraries(id) ON DELETE CASCADE,representation_id TEXT NOT NULL REFERENCES playable_representations(id) ON DELETE CASCADE,item_id TEXT NOT NULL REFERENCES items(id) ON DELETE CASCADE,kind TEXT NOT NULL,position INTEGER NOT NULL,deleted INTEGER NOT NULL DEFAULT 0,updated_at INTEGER NOT NULL',
      'technical_media':
          'id TEXT PRIMARY KEY, library_id TEXT NOT NULL REFERENCES libraries(id) ON DELETE CASCADE, item_id TEXT NOT NULL UNIQUE REFERENCES items(id) ON DELETE CASCADE, content_revision TEXT NOT NULL, analysis_version INTEGER NOT NULL, payload TEXT NOT NULL, updated_at INTEGER NOT NULL',
      'catalog_memberships':
          'id TEXT PRIMARY KEY, library_id TEXT NOT NULL REFERENCES libraries(id) ON DELETE CASCADE, collection_id TEXT NOT NULL, kind TEXT NOT NULL, item_id TEXT NOT NULL REFERENCES items(id) ON DELETE CASCADE, position INTEGER NOT NULL, deleted INTEGER NOT NULL DEFAULT 0, updated_at INTEGER NOT NULL',
    };
    for (final entry in definitions.entries)
      await db.customStatement(
        'CREATE TABLE IF NOT EXISTS ${entry.key} (${entry.value})',
      );
    final partColumns = await db
        .customSelect('PRAGMA table_info(media_parts)')
        .get();
    if (!partColumns.any((row) => row.data['name'] == 'deleted')) {
      await db.customStatement(
        'ALTER TABLE media_parts ADD COLUMN deleted INTEGER NOT NULL DEFAULT 0',
      );
    }
    await db.customStatement(
      'CREATE TABLE IF NOT EXISTS catalog_facets(item_id TEXT NOT NULL REFERENCES items(id) ON DELETE CASCADE,library_id TEXT NOT NULL,field TEXT NOT NULL,value TEXT NOT NULL,number INTEGER NOT NULL DEFAULT 0,PRIMARY KEY(item_id,field))',
    );
    await db.customStatement(
      'CREATE INDEX IF NOT EXISTS idx_catalog_facets ON catalog_facets(library_id,field,value,item_id)',
    );
    await db.customStatement(
      'CREATE INDEX IF NOT EXISTS idx_catalog_category ON catalog_facets(field,value,library_id,item_id)',
    );
    await db.customStatement(
      'CREATE INDEX IF NOT EXISTS idx_catalog_work_library ON catalog_works(library_id,type,title,id)',
    );
    await db.customStatement(
      'CREATE INDEX IF NOT EXISTS idx_catalog_decision_item ON match_decisions(library_id,item_id,revision)',
    );
    await db.customStatement(
      'CREATE INDEX IF NOT EXISTS idx_media_parts_representation ON media_parts(representation_id,position,id)',
    );
    await db.customStatement(
      'CREATE INDEX IF NOT EXISTS idx_media_extras_representation ON media_extras(representation_id,deleted,position,id)',
    );
    await db.customStatement(
      'CREATE INDEX IF NOT EXISTS idx_catalog_members ON catalog_memberships(library_id,collection_id,position,item_id)',
    );
    await db.customStatement(
      '''CREATE VIRTUAL TABLE IF NOT EXISTS catalog_search USING fts5(item_id UNINDEXED,library_id UNINDEXED,title,creator,tags)''',
    );
  }

  Future<void> backfill() async {
    final missing = await db
        .customSelect(
          'SELECT i.id FROM items i LEFT JOIN playable_representations r ON r.item_id=i.id WHERE r.id IS NULL',
        )
        .get();
    for (final row in missing) {
      final item = (await db.getItemById(row.data['id'] as String))!;
      final hints = localHints(item),
          now = DateTime.now().millisecondsSinceEpoch;
      final work = 'local:${item.id}', edition = 'edition:${item.id}';
      await db.customStatement(
        'INSERT OR IGNORE INTO catalog_works(id,library_id,type,title,payload,updated_at) VALUES(?,?,?,?,?,?)',
        [
          work,
          item.libraryId,
          item.itemType == 'audio'
              ? 'track'
              : item.itemType == 'video'
              ? 'movie'
              : 'book',
          item.title,
          '{}',
          now,
        ],
      );
      await db.customStatement(
        'INSERT OR IGNORE INTO catalog_editions(id,library_id,work_id,title,payload,updated_at) VALUES(?,?,?,?,?,?)',
        [
          edition,
          item.libraryId,
          work,
          hints['edition'] ?? 'Original',
          '{}',
          now,
        ],
      );
      await db.customStatement(
        'INSERT OR IGNORE INTO playable_representations(id,library_id,item_id,edition_id,payload,updated_at) VALUES(?,?,?,?,?,?)',
        [item.id, item.libraryId, item.id, edition, jsonEncode(hints), now],
      );
      await db.customStatement(
        'INSERT OR IGNORE INTO technical_media(id,library_id,item_id,content_revision,analysis_version,payload,updated_at) VALUES(?,?,?,?,?,?,?)',
        [
          item.id,
          item.libraryId,
          item.id,
          item.fingerprint ?? 'legacy:${item.fileSize}:${item.modifiedAt}',
          1,
          jsonEncode({
            'durationSeconds': item.durationSeconds,
            'pageCount': item.pageCount,
            'container': item.filename.split('.').last,
            'analysisState': 'indexed',
          }),
          now,
        ],
      );
      await reindex(item);
    }
    if (await db.getSetting('catalog.localHints.version') != '3') {
      var cursor = '';
      while (true) {
        final rows = await db
            .customSelect(
              'SELECT id FROM items WHERE id>? ORDER BY id LIMIT 200',
              variables: [Variable(cursor)],
            )
            .get();
        if (rows.isEmpty) break;
        await db.transaction(() async {
          for (final row in rows) {
            final item = await db.getItemById(row.data['id'] as String);
            if (item != null) {
              await _upgradeAutomaticEdition(item);
              await reindex(item);
            }
          }
        });
        cursor = rows.last.data['id'] as String;
      }
      await db.setSetting('catalog.localHints.version', '3');
    }
    final unindexed = await db
        .customSelect(
          'SELECT i.id FROM items i LEFT JOIN catalog_facets f ON f.item_id=i.id WHERE f.item_id IS NULL',
        )
        .get();
    for (final row in unindexed) {
      final item = await db.getItemById(row.data['id'] as String);
      if (item != null) await reindex(item);
    }
  }

  Future<void> _upgradeAutomaticEdition(Item item) async {
    final hints = localHints(item), title = hints['edition'];
    if (title is! String || title.isEmpty) return;
    final row = await db
        .customSelect(
          'SELECT r.payload,r.updated_at,e.work_id,e.title,e.payload AS edition_payload FROM playable_representations r JOIN catalog_editions e ON e.id=r.edition_id WHERE r.item_id=?',
          variables: [Variable(item.id)],
        )
        .getSingleOrNull();
    if (row == null ||
        row.data['title'] != 'Original' ||
        row.data['edition_payload'] != '{}')
      return;
    final old = Map<String, dynamic>.from(
      jsonDecode(row.data['payload'] as String) as Map,
    );
    if (old['edition'] != null) return;
    // Detach only this automatic representation: an Original edition may be
    // shared by other files, and saved user cuts have their own edition payload.
    final id = stableId('${row.data['work_id']}:$title');
    final now = DateTime.now().millisecondsSinceEpoch;
    final updated = now > (row.data['updated_at'] as int)
        ? now
        : (row.data['updated_at'] as int) + 1;
    await db.customStatement(
      'INSERT OR IGNORE INTO catalog_editions(id,library_id,work_id,title,payload,updated_at) VALUES(?,?,?,?,?,?)',
      [id, item.libraryId, row.data['work_id'], title, '{}', updated],
    );
    await db.customStatement(
      'UPDATE playable_representations SET edition_id=?,payload=?,updated_at=? WHERE item_id=?',
      [
        id,
        jsonEncode({...old, 'edition': title}),
        updated,
        item.id,
      ],
    );
  }

  Future<Map<String, dynamic>?> decision(String itemId) async =>
      (await db
              .customSelect(
                'SELECT * FROM match_decisions WHERE item_id=?',
                variables: [Variable(itemId)],
              )
              .getSingleOrNull())
          ?.data;
  Future<int> _revision(String table, String id) async =>
      ((await db
                      .customSelect(
                        'SELECT revision FROM $table WHERE id=?',
                        variables: [Variable(id)],
                      )
                      .getSingleOrNull())
                  ?.data['revision']
              as int? ??
          0) +
      1;
  Future<void> _expected(String itemId, int? expected) async {
    final current = (await decision(itemId))?['revision'] as int? ?? 0;
    if (expected != null && current != expected)
      throw const FormatException(
        'This match changed on another screen or device. Reload before saving.',
      );
  }

  Future<void> select(
    Item item,
    Map<String, dynamic> candidate, {
    required String providerId,
    int? expectedRevision,
    String origin = 'user',
  }) => db.transaction(() async {
    await _expected(item.id, expectedRevision);
    final remoteId = candidate['id'];
    if (remoteId is! String || candidate['title'] is! String)
      throw const FormatException('A match needs an ID and title');
    MediaRecordContract.identity(providerId);
    MediaRecordContract.identity(remoteId);
    final safe = <String, dynamic>{
      for (final key in MediaRecordContract.fields('metadata')!)
        if (candidate.containsKey(key) &&
            !{
              'matchState',
              'source',
              'providerId',
              'providerItemId',
            }.contains(key))
          key: candidate[key],
    };
    MediaRecordContract.validate(
      id: 'metadata:${item.id}',
      kind: 'metadata',
      libraryId: item.libraryId,
      itemId: item.id,
      data: safe,
    );
    final now = DateTime.now().millisecondsSinceEpoch;
    final work = stableId('${item.libraryId}:$providerId:$remoteId');
    final type = item.itemType == 'audio'
        ? 'track'
        : (safe['episode'] != null
              ? 'episode'
              : item.itemType == 'video'
              ? 'movie'
              : 'book');
    await db.customStatement(
      '''INSERT INTO catalog_works(id,library_id,type,title,payload,updated_at) VALUES(?,?,?,?,?,?)
      ON CONFLICT(id) DO UPDATE SET title=excluded.title,payload=excluded.payload,updated_at=excluded.updated_at''',
      [work, item.libraryId, type, safe['title'], jsonEncode(safe), now],
    );
    await db.customStatement(
      '''INSERT INTO provider_snapshots(id,library_id,work_id,provider_id,remote_id,payload,updated_at) VALUES(?,?,?,?,?,?,?)
      ON CONFLICT(id) DO UPDATE SET payload=excluded.payload,updated_at=excluded.updated_at''',
      [work, item.libraryId, work, providerId, remoteId, jsonEncode(safe), now],
    );
    final revision = await _revision('match_decisions', item.id);
    await db.customStatement(
      '''INSERT INTO match_decisions(id,library_id,item_id,work_id,state,provider_id,remote_id,revision,origin,payload,updated_at)
      VALUES(?,?,?,?,?,?,?,?,?,?,?) ON CONFLICT(id) DO UPDATE SET work_id=excluded.work_id,state=excluded.state,provider_id=excluded.provider_id,
      remote_id=excluded.remote_id,revision=excluded.revision,origin=excluded.origin,payload=excluded.payload,updated_at=excluded.updated_at''',
      [
        item.id,
        item.libraryId,
        item.id,
        work,
        'matched',
        providerId,
        remoteId,
        revision,
        origin,
        jsonEncode({
          'provider': providerId,
          'candidate': remoteId,
          'selectedAt': now,
          'method': 'explicit',
        }),
        now,
      ],
    );
    final hints = localHints(item);
    final edition = stableId('$work:${hints['edition'] ?? 'Original'}');
    await db.customStatement(
      'INSERT OR IGNORE INTO catalog_editions(id,library_id,work_id,title,payload,updated_at) VALUES(?,?,?,?,?,?)',
      [
        edition,
        item.libraryId,
        work,
        hints['edition'] ?? 'Original',
        '{}',
        now,
      ],
    );
    await db.customStatement(
      '''INSERT INTO playable_representations(id,library_id,item_id,edition_id,payload,updated_at) VALUES(?,?,?,?,?,?)
      ON CONFLICT(id) DO UPDATE SET edition_id=excluded.edition_id,payload=excluded.payload,updated_at=excluded.updated_at''',
      [item.id, item.libraryId, item.id, edition, jsonEncode(hints), now],
    );
    // A refresh can replace unlocked values; locked edits and explicit removals survive.
    await db.customStatement(
      'UPDATE catalog_overrides SET value=NULL,removed=0,revision=revision+1,updated_at=? WHERE item_id=? AND locked=0',
      [now, item.id],
    );
    await reindex(item);
  });
  Future<void> clear(
    Item item, {
    int? expectedRevision,
  }) => db.transaction(() async {
    await _expected(item.id, expectedRevision);
    final revision = await _revision('match_decisions', item.id),
        now = DateTime.now().millisecondsSinceEpoch;
    await db.customStatement(
      '''INSERT INTO match_decisions(id,library_id,item_id,state,revision,origin,payload,updated_at) VALUES(?,?,?,?,?,?,?,?)
      ON CONFLICT(id) DO UPDATE SET work_id=NULL,state=excluded.state,provider_id=NULL,remote_id=NULL,revision=excluded.revision,origin=excluded.origin,payload=excluded.payload,updated_at=excluded.updated_at''',
      [
        item.id,
        item.libraryId,
        item.id,
        'cleared',
        revision,
        'user',
        '{"explicitClear":true}',
        now,
      ],
    );
    final work = 'local:${item.id}', edition = 'edition:${item.id}';
    await db.customStatement(
      'INSERT OR IGNORE INTO catalog_works(id,library_id,type,title,payload,updated_at) VALUES(?,?,?,?,?,?)',
      [
        work,
        item.libraryId,
        item.itemType == 'video'
            ? 'movie'
            : item.itemType == 'audio'
            ? 'track'
            : 'book',
        item.title,
        '{}',
        now,
      ],
    );
    await db.customStatement(
      'INSERT OR IGNORE INTO catalog_editions(id,library_id,work_id,title,payload,updated_at) VALUES(?,?,?,?,?,?)',
      [
        edition,
        item.libraryId,
        work,
        localHints(item)['edition'] ?? 'Original',
        '{}',
        now,
      ],
    );
    await db.customStatement(
      'UPDATE playable_representations SET edition_id=?,updated_at=? WHERE item_id=?',
      [edition, now, item.id],
    );
    await reindex(item);
  });
  Future<void> override(
    Item item,
    String field,
    Object? value, {
    bool remove = false,
    bool locked = true,
    bool reset = false,
  }) => db.transaction(() async {
    if (!MediaRecordContract.fields('metadata')!.contains(field) ||
        [
          'matchState',
          'source',
          'providerId',
          'providerItemId',
        ].contains(field))
      throw const FormatException('This field is owned by matching');
    MediaRecordContract.validate(
      id: 'metadata:${item.id}',
      kind: 'metadata',
      libraryId: item.libraryId,
      itemId: item.id,
      data: {field: value},
    );
    final id = stableId('${item.id}:$field');
    final revision = await _revision('catalog_overrides', id);
    await db.customStatement(
      '''INSERT INTO catalog_overrides(id,library_id,item_id,field,value,removed,locked,revision,updated_at) VALUES(?,?,?,?,?,?,?,?,?)
      ON CONFLICT(id) DO UPDATE SET value=excluded.value,removed=excluded.removed,locked=excluded.locked,revision=excluded.revision,updated_at=excluded.updated_at''',
      [
        id,
        item.libraryId,
        item.id,
        field,
        reset ? null : jsonEncode(value),
        remove ? 1 : 0,
        reset
            ? 0
            : locked
            ? 1
            : 0,
        revision,
        DateTime.now().millisecondsSinceEpoch,
      ],
    );
    await reindex(item);
  });
  Map<String, dynamic> localHints(Item item) {
    final file = filenameHints(item.filename);
    final extraType = CatalogHints.extraKind(item.relativePath);
    var folder = p.posix.dirname(item.relativePath.replaceAll('\\', '/'));
    if (RegExp(
      r'^(season|series|s)[ -]?\d+$',
      caseSensitive: false,
    ).hasMatch(p.posix.basename(folder)))
      folder = p.posix.dirname(folder);
    final folderName = p.posix.basename(folder);
    final parent = folder == '.' || folderName == '@sources'
        ? <String, dynamic>{}
        : filenameHints('$folderName.folder');
    final title = file['title'] as String;
    final useFolder =
        title.isEmpty ||
        RegExp(
          r'^(?:\d+|episode[ -]?\d+)$',
          caseSensitive: false,
        ).hasMatch(title);
    final result = <String, dynamic>{
      ...file,
      'category': CatalogHints.category(item.itemType, file),
      if (extraType != null) ...{'extra': true, 'extraType': extraType},
      if (useFolder && parent['title'] != null) 'title': parent['title'],
      if (file['edition'] == null && parent['edition'] != null)
        'edition': parent['edition'],
      if (file['year'] == null && parent['year'] != null)
        'year': parent['year'],
      if (file['explicitId'] == null && parent['explicitId'] != null) ...{
        'explicitId': parent['explicitId'],
        'explicitProvider': parent['explicitProvider'],
      },
      'hintProvenance': {
        'title': useFolder ? 'folder' : 'filename',
        'year': file['year'] == null ? 'folder' : 'filename',
        'explicitId': file['explicitId'] == null ? 'folder' : 'filename',
      },
    };
    if (file['episode'] != null) result['show'] = result['title'];
    return result;
  }

  Future<Map<String, dynamic>> resolve(
    Item item,
    Map<String, dynamic> local, {
    bool strictRanges = false,
  }) async {
    final choice = await decision(item.id);
    final embedded = await db
        .customSelect(
          'SELECT payload FROM embedded_tags WHERE item_id=?',
          variables: [Variable(item.id)],
        )
        .getSingleOrNull();
    final inherited = Map<String, dynamic>.from(local);
    if (choice?['state'] == 'cleared' &&
        !{null, 'manual', 'filename', 'user'}.contains(inherited['source']))
      inherited.clear();
    final libraryRecord = await db
        .customSelect(
          "SELECT payload FROM media_records WHERE id=? AND deleted=0",
          variables: [Variable('library:${item.libraryId}')],
        )
        .getSingleOrNull();
    final declared = libraryRecord == null
        ? null
        : (jsonDecode(libraryRecord.data['payload'] as String) as Map)['type'];
    final result = <String, dynamic>{
      ...localHints(item),
      if (declared != null &&
          declared != 'mixed' &&
          MediaRecordContract.libraryKinds.contains(declared))
        'category': declared,
      if (embedded != null)
        ...Map<String, dynamic>.from(
          jsonDecode(embedded.data['payload'] as String) as Map,
        ),
      ...inherited,
    };
    if (choice?['state'] == 'matched') {
      final row = await db
          .customSelect(
            'SELECT payload FROM provider_snapshots WHERE work_id=?',
            variables: [Variable(choice!['work_id'] as String)],
          )
          .getSingleOrNull();
      if (row != null) {
        final snapshot = Map<String, dynamic>.from(
          jsonDecode(row.data['payload'] as String) as Map,
        );
        if (snapshot['episode'] != null && !snapshot.containsKey('episodeEnd'))
          result.remove('episodeEnd');
        result.addAll(snapshot);
      }
    }
    if (choice != null)
      result.addAll({
        'matchState': choice['state'],
        'source': choice['provider_id'] ?? 'filename',
      });
    final overrides = await db
        .customSelect(
          'SELECT * FROM catalog_overrides WHERE item_id=?',
          variables: [Variable(item.id)],
        )
        .get();
    for (final row in overrides) {
      if (row.data['removed'] == 1)
        result.remove(row.data['field']);
      else if (row.data['value'] != null)
        result[row.data['field'] as String] = jsonDecode(
          row.data['value'] as String,
        );
    }
    final first = result['episode'], last = result['episodeEnd'];
    if (last != null &&
        (first is! int ||
            last is! int ||
            last < first ||
            last - first >= CatalogHints.maxEpisodes)) {
      if (strictRanges)
        throw const FormatException(
          'A shared episode file needs an ordered range of at most 32 episodes.',
        );
      result.remove('episodeEnd');
    }
    return result;
  }

  Future<void> reindex(Item item) async {
    final legacy = await db
        .customSelect(
          'SELECT payload FROM media_records WHERE id=? AND deleted=0',
          variables: [Variable('metadata:${item.id}')],
        )
        .getSingleOrNull();
    final metadata = await resolve(
      item,
      legacy == null
          ? {}
          : Map<String, dynamic>.from(
              jsonDecode(legacy.data['payload'] as String) as Map,
            ),
    );
    final organization = await db
        .customSelect(
          'SELECT payload FROM media_records WHERE id=? AND deleted=0',
          variables: [Variable('organization:${item.id}')],
        )
        .getSingleOrNull();
    final tags = organization == null
        ? ''
        : ((jsonDecode(organization.data['payload'] as String) as Map)['tags']
                      as List? ??
                  [])
              .join(' ');
    await db.customStatement('DELETE FROM catalog_search WHERE item_id=?', [
      item.id,
    ]);
    await db.customStatement(
      'INSERT INTO catalog_search(item_id,library_id,title,creator,tags) VALUES(?,?,?,?,?)',
      [
        item.id,
        item.libraryId,
        item.userTitle ?? metadata['title'] ?? item.title,
        '${metadata['author'] ?? ''} ${metadata['artist'] ?? ''} ${metadata['credits'] ?? ''} ${metadata['album'] ?? ''} ${metadata['series'] ?? ''} ${metadata['show'] ?? ''}',
        tags,
      ],
    );
    await db.customStatement('DELETE FROM catalog_facets WHERE item_id=?', [
      item.id,
    ]);
    for (final field in [
      'show',
      'season',
      'episode',
      'episodeEnd',
      'category',
      'artist',
      'album',
      'author',
      'series',
      'disc',
      'track',
      'airDate',
      'extra',
      'extraType',
    ]) {
      final value = metadata[field];
      if (value == null) continue;
      await db.customStatement(
        'INSERT INTO catalog_facets(item_id,library_id,field,value,number) VALUES(?,?,?,?,?)',
        [item.id, item.libraryId, field, '$value', value is int ? value : 0],
      );
    }
    final date = DateTime.fromMillisecondsSinceEpoch(
      item.modifiedAt ?? item.createdAt,
    );
    await db.customStatement(
      'INSERT INTO catalog_facets(item_id,library_id,field,value,number) VALUES(?,?,?,?,?)',
      [
        item.id,
        item.libraryId,
        'month',
        '${date.year}-${date.month.toString().padLeft(2, '0')}',
        0,
      ],
    );
    await db.customStatement(
      'INSERT INTO catalog_facets(item_id,library_id,field,value,number) VALUES(?,?,?,?,?)',
      [item.id, item.libraryId, 'indexed', '1', 0],
    );
    db.notifyUpdates({TableUpdate.onTable(db.items)});
  }

  Future<Map<String, List<Map<String, dynamic>>>> exportRows() async => {
    for (final table in tables)
      table: (await db.customSelect('SELECT * FROM $table').get())
          .map((r) => r.data)
          .toList(),
  };
  Future<String> contentRevision(Item item) async =>
      (await db
                  .customSelect(
                    'SELECT content_revision FROM technical_media WHERE item_id=?',
                    variables: [Variable(item.id)],
                  )
                  .getSingleOrNull())
              ?.data['content_revision']
          as String? ??
      item.fingerprint ??
      'legacy:${item.fileSize}:${item.modifiedAt}';

  static const _transportPayloads = {
    'embedded_tags': {'title', 'artist', 'album', 'year', 'track', 'disc'},
    'study_anchors': {'locator', 'kind', 'text', 'offset', 'textRange'},
    'catalog_works': {
      'title',
      'year',
      'synopsis',
      'credits',
      'genres',
      'rating',
      'ratingLabel',
      'show',
      'season',
      'episode',
      'episodeEnd',
      'category',
      'artist',
      'album',
      'author',
      'series',
      'edition',
      'track',
      'disc',
      'airDate',
      'extra',
      'extraType',
    },
    'provider_snapshots': {
      'title',
      'year',
      'synopsis',
      'credits',
      'genres',
      'rating',
      'ratingLabel',
      'show',
      'season',
      'episode',
      'episodeEnd',
      'category',
      'artist',
      'album',
      'author',
      'series',
      'edition',
      'track',
      'disc',
      'airDate',
      'extra',
      'extraType',
    },
    'match_decisions': {
      'provider',
      'candidate',
      'selectedAt',
      'method',
      'explicitClear',
    },
    'catalog_editions': {'edition'},
    'playable_representations': {
      'season',
      'episode',
      'episodeEnd',
      'category',
      'edition',
      'representation',
      'airDate',
      'part',
      'extra',
      'extraType',
    },
    'technical_media': {
      'durationSeconds',
      'pageCount',
      'container',
      'analysisState',
      'width',
      'height',
      'codec',
      'bitrate',
      'channels',
      'sampleRate',
      'videoOrientation',
      'analysisError',
      'streams',
    },
  };
  static Map<String, dynamic> transportRow(
    String table,
    Map<String, dynamic> row,
  ) {
    final safe = Map<String, dynamic>.from(row);
    if (row['payload'] is String) {
      final payload = Map<String, dynamic>.from(
        jsonDecode(row['payload'] as String) as Map,
      );
      final projected = <String, dynamic>{
        for (final key in _transportPayloads[table] ?? <String>{})
          if (payload.containsKey(key)) key: payload[key],
      };
      if (table == 'technical_media') {
        final technical = TechnicalMediaContract.project(projected);
        projected
          ..clear()
          ..addAll(technical);
      }
      if (table == 'study_anchors') {
        final locator = ReaderLocator.decode(projected['locator'] as String?);
        if (locator == null ||
            locator.resourceId != row['item_id'] ||
            locator.pageKey.startsWith('/') ||
            locator.pageKey.contains('\\') ||
            locator.pageKey.split('/').contains('..'))
          throw const FormatException('Invalid Study anchor');
        final textRange = payload['textRange'];
        if (textRange != null) {
          final anchor = ReaderTextAnchor.decode(textRange);
          if (anchor == null ||
              !anchor.compatible(locator.resourceId, locator.revision))
            throw const FormatException('Invalid Study passage');
          projected['textRange'] = anchor.toJson();
        }
        projected['locator'] = ReaderLocator(
          resourceId: locator.resourceId,
          revision: locator.revision,
          pageKey: locator.pageKey,
          page: locator.page,
          point: locator.point,
          fit: locator.fit,
          zoom: locator.zoom,
          textOffset: locator.textOffset,
        ).encode();
      }
      safe['payload'] = jsonEncode(projected);
    }
    return safe;
  }

  Future<Map<String, List<Map<String, dynamic>>>> transportRows({
    Set<String>? libraries,
    Set<String>? itemIds,
  }) async {
    final rows = await exportRows();
    return {
      for (final entry in rows.entries)
        entry.key: [
          for (final row in entry.value)
            if ((libraries == null || libraries.contains(row['library_id'])) &&
                (itemIds == null ||
                    row['item_id'] == null ||
                    itemIds.contains(row['item_id'])))
              transportRow(entry.key, row),
        ],
    };
  }

  Future<void> importRows(
    Object? input, {
    Set<String>? allowedLibraryIds,
    bool transport = false,
  }) async {
    if (input == null) return;
    if (input is! Map) throw const FormatException('Invalid typed catalog');
    final reindexIds = <String>{}, workIds = <String>{};
    for (final table in tables) {
      final rows = input[table];
      if (rows == null) continue;
      if (rows is! List || rows.length > 100000)
        throw const FormatException('Invalid catalog rows');
      final columns = (await db.customSelect('PRAGMA table_info($table)').get())
          .map((r) => r.data['name'] as String)
          .toList();
      for (final value in rows) {
        if (value is! Map<String, dynamic> ||
            value['id'] is! String ||
            value['library_id'] is! String ||
            value.keys.any((key) => !columns.contains(key)))
          throw const FormatException('Invalid catalog identity');
        final libraryId = value['library_id'] as String;
        MediaRecordContract.identity(value['id'] as String);
        MediaRecordContract.identity(libraryId);
        if (allowedLibraryIds != null && !allowedLibraryIds.contains(libraryId))
          continue;
        if (table == 'study_anchors') {
          final note = value['note_id'], bookmark = value['bookmark_id'];
          if ((note == null) == (bookmark == null))
            throw const FormatException('Study anchor requires one owner');
          final target = await db
              .customSelect(
                'SELECT library_id,item_id FROM ${note != null ? 'notes' : 'bookmarks'} WHERE id=?',
                variables: [Variable((note ?? bookmark) as String)],
              )
              .getSingleOrNull();
          if (target?.data['library_id'] != libraryId ||
              target?.data['item_id'] != value['item_id'])
            throw const FormatException('Study anchor ownership mismatch');
          final payload = jsonDecode(value['payload'] as String) as Map;
          final locator = ReaderLocator.decode(payload['locator'] as String?);
          if (locator == null || locator.resourceId != value['item_id'])
            throw const FormatException('Invalid Study locator');
          if (payload['textRange'] != null) {
            final passage = ReaderTextAnchor.decode(payload['textRange']);
            if (passage == null ||
                !passage.compatible(locator.resourceId, locator.revision))
              throw const FormatException('Invalid Study passage');
          }
        }

        if (table == 'technical_media' && value['payload'] is String) {
          TechnicalMediaContract.project(
            Map<String, dynamic>.from(
              jsonDecode(value['payload'] as String) as Map,
            ),
          );
        }
        if (transport && value['payload'] is String) {
          final payload = jsonDecode(value['payload'] as String);
          if (payload is! Map ||
              payload.keys.any(
                (key) => _transportPayloads[table]?.contains(key) != true,
              ))
            throw const FormatException('Unsupported transport catalog field');
        }
        if ({
              'match_decisions',
              'playable_representations',
              'technical_media',
            }.contains(table) &&
            value['id'] != value['item_id'])
          throw const FormatException(
            'Catalog identity differs from its asset',
          );
        if (table == 'match_decisions' &&
            (!{'matched', 'cleared', 'unmatched'}.contains(value['state']) ||
                value['state'] == 'matched' &&
                    (value['work_id'] == null ||
                        value['provider_id'] == null ||
                        value['remote_id'] == null)))
          throw const FormatException('Invalid match decision');
        if (table == 'catalog_overrides') {
          final field = value['field'];
          if (field is! String ||
              !MediaRecordContract.fields('metadata')!.contains(field) ||
              {
                'source',
                'matchState',
                'providerId',
                'providerItemId',
              }.contains(field) ||
              value['id'] != stableId('${value['item_id']}:$field'))
            throw const FormatException('Invalid metadata override');
          if (!{0, 1}.contains(value['locked']) ||
              !{0, 1}.contains(value['removed']))
            throw const FormatException('Invalid metadata lock');
          final raw = value['value'];
          if (raw != null &&
              (raw is! String ||
                  utf8.encode(raw).length >
                      MediaRecordContract.maxPayloadBytes))
            throw const FormatException('Invalid override value');
          MediaRecordContract.validate(
            id: 'metadata:${value['item_id']}',
            kind: 'metadata',
            libraryId: libraryId,
            itemId: value['item_id'] as String?,
            data: {field: raw == null ? null : jsonDecode(raw as String)},
          );
        }

        if (allowedLibraryIds != null && !allowedLibraryIds.contains(libraryId))
          continue;
        if (await db.getLibraryById(libraryId) == null) continue;
        final itemId = value['item_id'];
        if (itemId != null && itemId is! String)
          throw const FormatException('Invalid catalog asset identity');
        if (itemId != null &&
            (await db.getItemById(itemId as String))?.libraryId != libraryId)
          throw const FormatException('Catalog asset ownership mismatch');
        if (table == 'media_parts' || table == 'media_extras') {
          final rep = value['representation_id'];
          if (rep is! String ||
              value['position'] is! int ||
              (value['position'] as int) < 0 ||
              (value['position'] as int) >= 100 ||
              value['id'] !=
                  stableId(
                    '${table == 'media_extras' ? 'extra:' : ''}$rep:$itemId',
                  )) {
            throw const FormatException('Invalid title file relationship');
          }
          if (table == 'media_extras' &&
              (rep == itemId ||
                  !{0, 1}.contains(value['deleted']) ||
                  !{
                    'extra',
                    'featurette',
                    'scene',
                    'short',
                    'other',
                    'trailer',
                    'interview',
                    'behindScenes',
                    'deletedScene',
                    'booklet',
                  }.contains(value['kind']))) {
            throw const FormatException('Invalid title extra');
          }
          if (table == 'media_parts') {
            if (value['deleted'] != null && !{0, 1}.contains(value['deleted']))
              throw const FormatException('Invalid part removal');
            final duration = value['duration_seconds'],
                offset = value['offset_seconds'];
            if (duration is! num ||
                !duration.isFinite ||
                duration <= 0 ||
                duration > 31536000 ||
                offset is! num ||
                !offset.isFinite ||
                offset < 0 ||
                offset > 3153600000) {
              throw const FormatException('Invalid part timing');
            }
            final owner = await db.getItemById(rep);
            final asset = await db.getItemById(itemId as String);
            if (owner == null ||
                asset == null ||
                !{'audio', 'video'}.contains(owner.itemType) ||
                owner.itemType != asset.itemType) {
              throw const FormatException('Incompatible part media type');
            }
          }
        }
        if (table == 'catalog_memberships') {
          final collection = await db
              .customSelect(
                "SELECT library_id,kind FROM media_records WHERE id=?",
                variables: [Variable(value['collection_id'] as String)],
              )
              .getSingleOrNull();
          if (collection?.data['library_id'] != libraryId ||
              collection?.data['kind'] != value['kind'] ||
              !{0, 1}.contains(value['deleted']))
            throw const FormatException(
              'Invalid collection membership ownership',
            );
        }
        MediaRecordContract.revision(value['updated_at']);
        if (value['revision'] != null)
          MediaRecordContract.revision(value['revision']);
        if (value['payload'] != null) {
          final raw = value['payload'];
          if (raw is! String ||
              utf8.encode(raw).length > MediaRecordContract.maxPayloadBytes ||
              jsonDecode(raw) is! Map)
            throw const FormatException('Invalid catalog payload');
          final payload = Map<String, dynamic>.from(jsonDecode(raw) as Map);
          final owner = itemId is String ? itemId : 'catalog';
          MediaRecordContract.validate(
            id: 'metadata:$owner',
            kind: 'metadata',
            libraryId: libraryId,
            itemId: owner,
            data: payload,
          );
        }
        final old = await db
            .customSelect(
              'SELECT * FROM $table WHERE id=?',
              variables: [Variable(value['id'] as String)],
            )
            .getSingleOrNull();
        if (old != null &&
            (old.data['library_id'] != libraryId ||
                old.data['item_id'] != itemId ||
                old.data['representation_id'] != value['representation_id']))
          throw const FormatException('Catalog ownership cannot change');
        for (final (key, target) in [
          ('work_id', 'catalog_works'),
          ('edition_id', 'catalog_editions'),
          ('representation_id', 'playable_representations'),
        ]) {
          final id = value[key];
          if (id == null) continue;
          final parent = await db
              .customSelect(
                'SELECT library_id FROM $target WHERE id=?',
                variables: [Variable(id as String)],
              )
              .getSingleOrNull();
          if (parent?.data['library_id'] != libraryId)
            throw const FormatException(
              'Catalog relationship is outside this library',
            );
        }
        if (old != null) {
          final current =
              old.data['revision'] as int? ?? old.data['updated_at'] as int;
          final incoming =
              value['revision'] as int? ?? value['updated_at'] as int;
          if (incoming <= current) continue;
        }
        final keys = columns.where(value.containsKey).toList();
        await db.customStatement(
          'INSERT INTO $table(${keys.join(',')}) VALUES(${keys.map((_) => '?').join(',')}) ON CONFLICT(id) DO UPDATE SET ${keys.where((k) => k != 'id').map((k) => '$k=excluded.$k').join(',')}',
          keys.map((key) => value[key]).toList(),
        );
        if (itemId is String) reindexIds.add(itemId);
        if (table == 'catalog_works') workIds.add(value['id'] as String);
        if (table == 'provider_snapshots')
          workIds.add(value['work_id'] as String);
      }
    }
    for (final work in workIds) {
      final assets = await db
          .customSelect(
            'SELECT item_id FROM match_decisions WHERE work_id=?',
            variables: [Variable(work)],
          )
          .get();
      reindexIds.addAll(assets.map((row) => row.data['item_id'] as String));
    }
    for (final id in reindexIds) {
      final item = await db.getItemById(id);
      if (item != null) await reindex(item);
    }
  }

  static Map<String, dynamic> filenameHints(String filename) =>
      CatalogHints.filename(filename);
}
