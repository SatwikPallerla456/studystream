import 'package:drift/drift.dart';
import '../db/app_database.dart';

/// Grants belong to the local host and never arrive in a client snapshot.
class LibraryAccessStore {
  const LibraryAccessStore(this.db);
  final AppDatabase db;
  static const permissions = {'browse', 'stream', 'mutate'};
  Future<void> createTables() async {
    await db.customStatement(
      '''CREATE TABLE IF NOT EXISTS device_library_grants(
      device_id TEXT NOT NULL REFERENCES known_devices(id) ON DELETE CASCADE,
      library_id TEXT NOT NULL REFERENCES libraries(id) ON DELETE CASCADE,
      browse INTEGER NOT NULL DEFAULT 0,stream INTEGER NOT NULL DEFAULT 0,
      mutate INTEGER NOT NULL DEFAULT 0,updated_at INTEGER NOT NULL,
      PRIMARY KEY(device_id,library_id))''',
    );
    // Preserve current approved-device scope once. Newly added libraries are
    // denied until the host explicitly grants them.
    if (await db.getSetting('sync.grantsMigrated') != '1') {
      await db.customStatement(
        '''INSERT OR IGNORE INTO device_library_grants(device_id,library_id,browse,stream,mutate,updated_at)
        SELECT d.id,l.id,1,1,1,0 FROM known_devices d CROSS JOIN libraries l
        WHERE d.approved=1 AND d.revoked=0 AND l.root_folder_path NOT LIKE 'remote:%' AND l.root_folder_path NOT LIKE 'import:%' ''',
      );
      await db.setSetting('sync.grantsMigrated', '1');
    }
  }

  Future<void> approveCurrentLibraries(String deviceId) async {
    await db.customStatement(
      '''INSERT OR IGNORE INTO device_library_grants(device_id,library_id,browse,stream,mutate,updated_at)
      SELECT ?,id,1,1,1,? FROM libraries WHERE root_folder_path NOT LIKE 'remote:%' AND root_folder_path NOT LIKE 'import:%' ''',
      [deviceId, DateTime.now().millisecondsSinceEpoch],
    );
  }

  Future<Set<String>> allowed(String deviceId, String permission) async {
    if (!permissions.contains(permission))
      throw ArgumentError.value(permission);
    final rows = await db
        .customSelect(
          '''SELECT g.library_id FROM device_library_grants g
      JOIN libraries l ON l.id=g.library_id JOIN known_devices d ON d.id=g.device_id
      WHERE g.device_id=? AND g.$permission=1 AND d.approved=1 AND d.revoked=0
      AND l.root_folder_path NOT LIKE 'remote:%' AND l.root_folder_path NOT LIKE 'import:%' ''',
          variables: [Variable(deviceId)],
        )
        .get();
    return rows.map((row) => row.data['library_id'] as String).toSet();
  }

  Future<void> set(
    String deviceId,
    String libraryId, {
    required bool browse,
    required bool stream,
    required bool mutate,
  }) async {
    if (await db.getLibraryById(libraryId) == null)
      throw const FormatException('Library no longer exists');
    await db.customStatement(
      '''INSERT INTO device_library_grants(device_id,library_id,browse,stream,mutate,updated_at) VALUES(?,?,?,?,?,?)
      ON CONFLICT(device_id,library_id) DO UPDATE SET browse=excluded.browse,stream=excluded.stream,mutate=excluded.mutate,updated_at=excluded.updated_at''',
      [
        deviceId,
        libraryId,
        browse ? 1 : 0,
        browse && stream ? 1 : 0,
        browse && mutate ? 1 : 0,
        DateTime.now().millisecondsSinceEpoch,
      ],
    );
    db.notifyUpdates({TableUpdate.onTable(db.knownDevices)});
  }
}
