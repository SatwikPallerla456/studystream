import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../db/app_database.dart';

/// Local source ownership is separate from descriptive catalog identities.
class LibrarySourceStore {
  const LibrarySourceStore(this.db);
  final AppDatabase db;

  Future<void> createTables() async {
    await db.customStatement('''CREATE TABLE IF NOT EXISTS item_assets (
      item_id TEXT PRIMARY KEY REFERENCES items(id) ON DELETE CASCADE,
      source_id TEXT NOT NULL REFERENCES library_sources(id) ON DELETE CASCADE,
      relative_path TEXT NOT NULL, content_revision TEXT NOT NULL,
      updated_at INTEGER NOT NULL)''');
    await db.customStatement('CREATE INDEX IF NOT EXISTS idx_assets_source ON item_assets(source_id,relative_path)');
    await db.customStatement('''CREATE TABLE IF NOT EXISTS source_scan_sessions (
      id TEXT PRIMARY KEY, source_id TEXT NOT NULL, generation INTEGER NOT NULL,
      root_path TEXT NOT NULL, outcome TEXT NOT NULL, started_at INTEGER NOT NULL,
      finished_at INTEGER, discovered INTEGER NOT NULL DEFAULT 0,
      processed INTEGER NOT NULL DEFAULT 0, errors TEXT NOT NULL DEFAULT '[]',
      UNIQUE(source_id,generation))''');
    await db.customStatement('''CREATE TABLE IF NOT EXISTS source_scan_discoveries (
      session_id TEXT NOT NULL REFERENCES source_scan_sessions(id) ON DELETE CASCADE,
      relative_path TEXT NOT NULL, item_id TEXT NOT NULL,
      PRIMARY KEY(session_id,relative_path))''');
    await db.customStatement('CREATE INDEX IF NOT EXISTS idx_scans_source ON source_scan_sessions(source_id,generation DESC)');
  }

  /// Ambiguous or out-of-root legacy data stays unbound and requires relinking.
  Future<void> backfill() async {
    final rows = await db.customSelect('''SELECT i.* FROM items i
      LEFT JOIN item_assets a ON a.item_id=i.id WHERE a.item_id IS NULL''').get();
    for (final row in rows) {
      final item = await db.getItemById(row.data['id'] as String);
      if (item == null || !p.isAbsolute(item.filePath)) continue;
      final relative = p.normalize(item.relativePath);
      if (p.isAbsolute(relative) || p.split(relative).contains('..')) continue;
      final secondary = relative.startsWith('@sources${p.separator}');
      final sources = await db.customSelect('SELECT * FROM library_sources WHERE library_id = ?', variables: [Variable(item.libraryId)]).get();
      final candidates = sources.where((source) {
        final namespace = source.data['namespace'] as String;
        final root = source.data['root_path'] as String;
        return (secondary ? namespace.isNotEmpty && p.isWithin(namespace, relative) : namespace.isEmpty) &&
          p.isWithin(p.normalize(root), p.normalize(item.filePath));
      }).toList();
      if (candidates.length != 1) continue;
      await bind(item, candidates.single.data['id'] as String,
        p.relative(item.filePath, from: candidates.single.data['root_path'] as String));
    }
  }

  Future<void> bind(Item item, String sourceId, String relative) async {
    if (p.isAbsolute(relative) || p.split(relative).contains('..')) throw const FormatException('Invalid source-relative path');
    final source = await db.customSelect('SELECT library_id FROM library_sources WHERE id = ?', variables: [Variable(sourceId)]).getSingleOrNull();
    if (source?.data['library_id'] != item.libraryId) throw const FormatException('Source is outside this library');
    final old = await db.customSelect('SELECT source_id FROM item_assets WHERE item_id = ?', variables: [Variable(item.id)]).getSingleOrNull();
    if (old != null && old.data['source_id'] != sourceId) throw const FormatException('Cross-source moves require an explicit relink');
    await db.customStatement('''INSERT INTO item_assets(item_id,source_id,relative_path,content_revision,updated_at)
      VALUES(?,?,?,?,?) ON CONFLICT(item_id) DO UPDATE SET relative_path=excluded.relative_path,
      content_revision=excluded.content_revision,updated_at=excluded.updated_at''',
      [item.id,sourceId,p.normalize(relative),item.fingerprint ?? 'legacy:${item.fileSize}:${item.modifiedAt}', DateTime.now().millisecondsSinceEpoch]);
  }

  Future<String> begin(String sourceId, String root) => db.transaction(() async {
    final row = await db.customSelect('SELECT COALESCE(MAX(generation),0)+1 AS generation FROM source_scan_sessions WHERE source_id = ?',variables:[Variable(sourceId)]).getSingle();
    final id = const Uuid().v4();
    await db.customStatement('INSERT INTO source_scan_sessions(id,source_id,generation,root_path,outcome,started_at) VALUES(?,?,?,?,?,?)',
      [id,sourceId,row.data['generation'],root,'running',DateTime.now().millisecondsSinceEpoch]);
    return id;
  });
  Future<void> finish(String id, String outcome, {int discovered=0,int processed=0,String errors='[]'}) =>
    db.customStatement('UPDATE source_scan_sessions SET outcome=?,finished_at=?,discovered=?,processed=?,errors=? WHERE id=?',
      [outcome,DateTime.now().millisecondsSinceEpoch,discovered,processed,errors,id]);

  Future<void> stage(String sessionId, List<ItemsCompanion> items) async {
    for (final item in items) {
      await db.customStatement('INSERT OR REPLACE INTO source_scan_discoveries(session_id,relative_path,item_id) VALUES(?,?,?)',
        [sessionId,item.relativePath.value,item.id.value]);
    }
  }
}
