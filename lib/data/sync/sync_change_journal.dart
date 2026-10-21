import 'dart:convert';
import 'package:drift/drift.dart';
import '../../domain/catalog/media_record_contract.dart';
import '../db/app_database.dart';
import '../../domain/catalog/catalog_identity_store.dart';

/// A monotonic host cursor, independent of wall clocks and local schema version.
/// The journal stores identifiers only. Tombstones survive parent deletion for
/// 90 days; expired cursors explicitly require a scoped snapshot refresh.
class SyncChangeJournal {
  const SyncChangeJournal(this.db);
  final AppDatabase db;
  static const retention = Duration(days: 90);
  Future<void> createTables() async {
    await db.customStatement('''CREATE TABLE IF NOT EXISTS sync_change_journal(
      sequence INTEGER PRIMARY KEY AUTOINCREMENT,library_id TEXT NOT NULL,
      entity_kind TEXT NOT NULL,entity_id TEXT NOT NULL,deleted INTEGER NOT NULL,
      recorded_at INTEGER NOT NULL)''');
    await db.customStatement(
      'CREATE INDEX IF NOT EXISTS idx_sync_journal_scope ON sync_change_journal(library_id,sequence)',
    );
    final entities = <String, ({String id, String library, String? deleted})>{
      'libraries': (id: 'id', library: 'id', deleted: null),
      'sections': (id: 'id', library: 'library_id', deleted: null),
      'items': (id: 'id', library: 'library_id', deleted: null),
      'notes': (id: 'id', library: 'library_id', deleted: 'deleted'),
      'bookmarks': (id: 'id', library: 'library_id', deleted: 'deleted'),
      'playback_progress': (id: 'item_id', library: '@item', deleted: null),
      'reading_progress': (id: 'item_id', library: '@item', deleted: null),
      'media_records': (id: 'id', library: 'library_id', deleted: 'deleted'),
      for (final table in CatalogIdentityStore.tables)
        table: (
          id: 'id',
          library: 'library_id',
          deleted:
              {
                'catalog_memberships',
                'media_parts',
                'media_extras',
              }.contains(table)
              ? 'deleted'
              : null,
        ),
    };
    for (final action in ['insert', 'update', 'delete']) {
      await db.customStatement(
        'DROP TRIGGER IF EXISTS sync_media_parts_$action',
      );
    }
    for (final entry in entities.entries) {
      for (final action in ['INSERT', 'UPDATE', 'DELETE']) {
        final row = action == 'DELETE' ? 'OLD' : 'NEW';
        final library = entry.value.library == '@item'
            ? '(SELECT library_id FROM items WHERE id=$row.item_id)'
            : '$row.${entry.value.library}';
        final deleted = action == 'DELETE'
            ? '1'
            : entry.value.deleted == null
            ? '0'
            : '$row.${entry.value.deleted}';
        await db.customStatement(
          '''CREATE TRIGGER IF NOT EXISTS sync_${entry.key}_${action.toLowerCase()} AFTER $action ON ${entry.key}
          WHEN $library IS NOT NULL BEGIN INSERT INTO sync_change_journal(library_id,entity_kind,entity_id,deleted,recorded_at)
          VALUES($library,'${entry.key}',$row.${entry.value.id},$deleted,CAST((julianday('now')-2440587.5)*86400000 AS INTEGER)); END''',
        );
      }
    }
  }

  static const legacyKinds = {
    'libraries',
    'sections',
    'items',
    'playback_progress',
    'reading_progress',
    'notes',
    'bookmarks',
    'media_records',
  };
  static List<String> get entityKinds => [
    ...legacyKinds,
    ...CatalogIdentityStore.tables,
  ];
  Future<Map<String, dynamic>?> record(String kind, String id) async {
    if (!entityKinds.contains(kind))
      throw const FormatException('Unknown sync entity');
    final key = {'playback_progress', 'reading_progress'}.contains(kind)
        ? 'item_id'
        : 'id';
    final row = await db
        .customSelect(
          'SELECT * FROM $kind WHERE $key=?',
          variables: [Variable(id)],
        )
        .getSingleOrNull();
    if (row == null) return null;
    return switch (kind) {
      'libraries' => {
        ...db.libraries.map(row.data).toJson(),
        'rootFolderPath': '',
        'coverPath': null,
      },
      'sections' => {...db.sections.map(row.data).toJson(), 'folderPath': ''},
      'items' => {
        ...db.items.map(row.data).toJson(),
        'filePath': '',
        'thumbnailPath': null,
        'fingerprint': null,
      },
      'playback_progress' => db.playbackProgress.map(row.data).toJson(),
      'reading_progress' => db.readingProgress.map(row.data).toJson(),
      'notes' => db.notes.map(row.data).toJson(),
      'bookmarks' => db.bookmarks.map(row.data).toJson(),
      'media_records' => MediaRecordContract.forTransport(row.data),
      _ => CatalogIdentityStore.transportRow(kind, row.data),
    };
  }

  Future<Map<String, Object?>> bootstrap(
    Set<String> libraries, {
    String? cursor,
    int limit = 100,
  }) => db.transaction(() async {
    if (limit < 1 || limit > 100)
      throw const FormatException('Invalid bootstrap limit');
    var table = 0;
    String after = '';
    if (cursor != null) {
      if (cursor.length > 4096)
        throw const FormatException('Invalid bootstrap cursor');
      final data = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(cursor))),
      );
      if (data is! Map || data['table'] is! int || data['after'] is! String)
        throw const FormatException('Invalid bootstrap cursor');
      table = data['table'];
      after = data['after'];
      if (table < 0 || table >= entityKinds.length)
        throw const FormatException('Invalid bootstrap table');
    }
    final events = <Map<String, dynamic>>[];
    var eventBytes = 0;
    if (libraries.isEmpty)
      return {'events': events, 'next': null, 'head': await head()};
    for (; table < entityKinds.length; table++, after = '') {
      final kind = entityKinds[table],
          progress = {
            'playback_progress',
            'reading_progress',
          }.contains(entityKinds[table]);
      final key = progress ? 'item_id' : 'id';
      final library = kind == 'libraries'
          ? 'id'
          : progress
          ? '(SELECT library_id FROM items WHERE items.id=$kind.item_id)'
          : 'library_id';
      final rows = await db
          .customSelect(
            'SELECT $key AS id FROM $kind WHERE $library IN (${libraries.map((_) => '?').join(',')}) AND $key>? ORDER BY $key LIMIT ?',
            variables: [
              ...libraries.map(Variable.new),
              Variable(after),
              Variable(limit - events.length + 1),
            ],
          )
          .get();
      for (final row in rows.take(limit - events.length)) {
        final id = row.data['id'] as String,
            safe = await record(kind, row.data['id'] as String);
        if (safe != null) {
          final bytes = utf8.encode(jsonEncode(safe)).length;
          if (bytes > 4 * 1024 * 1024)
            throw const FormatException(
              'A catalog record exceeds the transfer limit',
            );
          if (eventBytes + bytes > 4 * 1024 * 1024) {
            final next = base64UrlEncode(
              utf8.encode(jsonEncode({'table': table, 'after': after})),
            );
            return {'events': events, 'next': next, 'head': await head()};
          }
          eventBytes += bytes;
          events.add({'entity_kind': kind, 'entity_id': id, 'record': safe});
        }
        after = id;
      }
      if (rows.length > limit - events.length || events.length == limit) {
        final next = base64UrlEncode(
          utf8.encode(jsonEncode({'table': table, 'after': after})),
        );
        return {'events': events, 'next': next, 'head': await head()};
      }
    }
    return {'events': events, 'next': null, 'head': await head()};
  });
  Future<int> head() async =>
      (await db
                  .customSelect(
                    "SELECT COALESCE((SELECT seq FROM sqlite_sequence WHERE name='sync_change_journal'),0) AS head",
                  )
                  .getSingle())
              .data['head']
          as int;
  Future<void> trim() async {
    final cutoff = DateTime.now().subtract(retention).millisecondsSinceEpoch;
    await db.transaction(() async {
      final last =
          (await db
                      .customSelect(
                        'SELECT MAX(sequence) AS sequence FROM sync_change_journal WHERE recorded_at<?',
                        variables: [Variable(cutoff)],
                      )
                      .getSingle())
                  .data['sequence']
              as int?;
      if (last == null) return;
      final old =
          int.tryParse(await db.getSetting('sync.journalFloor') ?? '0') ?? 0;
      if (last > old) await db.setSetting('sync.journalFloor', '$last');
      await db.customStatement(
        'DELETE FROM sync_change_journal WHERE sequence<=?',
        [last],
      );
    });
  }

  Future<Map<String, Object?>> page(
    int since,
    Set<String> libraries, {
    int limit = 100,
  }) => db.transaction(() async {
    if (since < 0 || since > 9007199254740991 || limit < 1 || limit > 100)
      throw const FormatException('Invalid change cursor');
    final floor =
        int.tryParse(await db.getSetting('sync.journalFloor') ?? '0') ?? 0;
    if (since < floor || since > await head())
      return {
        'resetRequired': true,
        'retentionDays': 90,
        'cursor': await head(),
        'events': [],
      };
    if (libraries.isEmpty)
      return {
        'resetRequired': false,
        'cursor': await head(),
        'events': [],
        'hasMore': false,
      };
    final rows = await db
        .customSelect(
          'SELECT sequence,library_id,entity_kind,entity_id,deleted FROM sync_change_journal WHERE sequence>? AND library_id IN (${libraries.map((_) => '?').join(',')}) ORDER BY sequence LIMIT ?',
          variables: [
            Variable(since),
            ...libraries.map(Variable.new),
            Variable(limit + 1),
          ],
        )
        .get();
    final events = <Map<String, dynamic>>[];
    var eventBytes = 0, truncated = false;
    for (final row in rows.take(limit)) {
      final safe = await record(
        row.data['entity_kind'] as String,
        row.data['entity_id'] as String,
      );
      final bytes = safe == null ? 0 : utf8.encode(jsonEncode(safe)).length;
      if (bytes > 4 * 1024 * 1024)
        throw const FormatException(
          'A changed record exceeds the transfer limit',
        );
      if (eventBytes + bytes > 4 * 1024 * 1024) {
        truncated = true;
        break;
      }
      eventBytes += bytes;
      events.add({
        ...row.data,
        'deleted': row.data['deleted'] == 1 || safe == null,
        'record': safe,
      });
    }
    return {
      'resetRequired': false,
      'retentionDays': 90,
      'events': events,
      'hasMore': truncated || rows.length > limit,
      'cursor': truncated || rows.length > limit
          ? events.last['sequence']
          : await head(),
    };
  });
}
