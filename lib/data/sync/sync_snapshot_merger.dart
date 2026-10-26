import 'package:drift/drift.dart';
import 'sync_state_store.dart';
import '../../domain/services/sync_intent.dart';

import '../../domain/services/sync_conflict_resolver.dart';
import '../db/app_database.dart';
import '../../domain/catalog/catalog_identity_store.dart';

class SyncSnapshotMerger {
  const SyncSnapshotMerger(this.database);

  final AppDatabase database;

  Future<void> merge(
    Map<String, dynamic> snapshot, {
    Set<String>? allowedLibraryIds,
  }) async {
    bool allowed(String id) =>
        allowedLibraryIds == null || allowedLibraryIds.contains(id);
    final protocol = snapshot['protocolVersion'] ?? 1;
    if (protocol is! int || protocol < 1 || protocol > 2)
      throw const FormatException(
        'This client uses an unsupported sync protocol. Update Tangerine.',
      );
    final schemaVersion = snapshot['schemaVersion'];
    if (schemaVersion is! int ||
        schemaVersion < 1 ||
        schemaVersion > database.schemaVersion) {
      throw const FormatException('Invalid StudyStream sync snapshot.');
    }
    List<Map<String, dynamic>> rows(String key) {
      final value = snapshot[key];
      if (value == null) return const [];
      if (value is! List<Object?> ||
          value.any((row) => row is! Map<String, dynamic>)) {
        throw const FormatException('Invalid StudyStream sync records.');
      }
      return value.cast<Map<String, dynamic>>();
    }

    await database.transaction(() async {
      final affectedSections = <String>{};
      for (final row in rows('libraries')) {
        final remote = Library.fromJson(row);
        final local = await database.getLibraryById(remote.id);
        if (local == null || !allowed(local.id)) continue;
        final selected =
            Library.fromJson(
              SyncConflictResolver.mergeMetadata(
                local.toJson(),
                remote.toJson(),
              ),
            ).copyWith(
              rootFolderPath: local.rootFolderPath,
              coverPath: Value(local.coverPath),
              createdAt: local.createdAt,
              lastScannedAt: Value(local.lastScannedAt),
              unavailable: local.unavailable,
            );
        if (SyncIntent.canonical(local.toJson()) ==
            SyncIntent.canonical(selected.toJson()))
          continue;
        await database
            .into(database.libraries)
            .insertOnConflictUpdate(selected);
      }

      for (final row in rows('sections')) {
        final remote = Section.fromJson(row);
        final local = await (database.select(
          database.sections,
        )..where((table) => table.id.equals(remote.id))).getSingleOrNull();
        if (local == null ||
            !allowed(local.libraryId) ||
            remote.libraryId != local.libraryId) {
          continue;
        }
        final selected =
            Section.fromJson(
              SyncConflictResolver.mergeMetadata(
                local.toJson(),
                remote.toJson(),
              ),
            ).copyWith(
              libraryId: local.libraryId,
              relativePath: local.relativePath,
              parentSectionId: Value(local.parentSectionId),
              orderIndex: local.orderIndex,
              folderPath: local.folderPath,
              itemCount: local.itemCount,
              completedCount: local.completedCount,
              unavailable: local.unavailable,
            );
        if (SyncIntent.canonical(local.toJson()) !=
            SyncIntent.canonical(selected.toJson()))
          await database
              .into(database.sections)
              .insertOnConflictUpdate(selected);
      }

      for (final row in rows('items')) {
        final remote = Item.fromJson(row);
        final local = await database.getItemById(remote.id);
        if (local == null ||
            !allowed(local.libraryId) ||
            remote.libraryId != local.libraryId) {
          continue;
        }
        final selected =
            Item.fromJson(
              SyncConflictResolver.mergeMetadata(
                local.toJson(),
                remote.toJson(),
              ),
            ).copyWith(
              libraryId: local.libraryId,
              sectionId: local.sectionId,
              filename: local.filename,
              filePath: local.filePath,
              relativePath: local.relativePath,
              itemType: local.itemType,
              orderIndex: local.orderIndex,
              durationSeconds: Value(local.durationSeconds),
              pageCount: Value(local.pageCount),
              thumbnailPath: Value(local.thumbnailPath),
              modifiedAt: Value(local.modifiedAt),
              fileSize: Value(local.fileSize),
              fingerprint: Value(local.fingerprint),
              unavailable: local.unavailable,
              createdAt: local.createdAt,
            );
        if (SyncIntent.canonical(local.toJson()) !=
            SyncIntent.canonical(selected.toJson()))
          await database.into(database.items).insertOnConflictUpdate(selected);
      }

      for (final kind in ['playback', 'reading'])
        for (final row in rows(kind)) {
          final item = await database.getItemById(row['itemId'] as String);
          if (item == null || !allowed(item.libraryId)) continue;
          affectedSections.add(item.sectionId);
          await SyncStateStore(database).merge(kind, row);
        }

      for (final row in rows('notes')) {
        final remote = Note.fromJson(row);
        final library = await database.getLibraryById(remote.libraryId);
        final item = remote.itemId == null
            ? null
            : await database.getItemById(remote.itemId!);
        if (library == null ||
            !allowed(library.id) ||
            (remote.itemId != null &&
                (item == null || item.libraryId != remote.libraryId))) {
          continue;
        }
        final local = await (database.select(
          database.notes,
        )..where((table) => table.id.equals(remote.id))).getSingleOrNull();
        if (local != null &&
            (local.libraryId != remote.libraryId ||
                local.itemId != remote.itemId)) {
          throw const FormatException('Study record ownership cannot change');
        }
        final selected = local == null
            ? [remote]
            : SyncConflictResolver.preserveUserContentConflict(
                local.toJson(),
                remote.toJson(),
              ).map(Note.fromJson);
        for (final note in selected) {
          final previous = await (database.select(
            database.notes,
          )..where((t) => t.id.equals(note.id))).getSingleOrNull();
          if (previous == null ||
              SyncIntent.canonical(previous.toJson()) !=
                  SyncIntent.canonical(note.toJson()))
            await database.into(database.notes).insertOnConflictUpdate(note);
        }
      }

      for (final row in rows('bookmarks')) {
        final remote = Bookmark.fromJson(row);
        final library = await database.getLibraryById(remote.libraryId);
        final item = await database.getItemById(remote.itemId);
        if (library == null ||
            !allowed(library.id) ||
            item == null ||
            item.libraryId != remote.libraryId) {
          continue;
        }
        final local = await (database.select(
          database.bookmarks,
        )..where((table) => table.id.equals(remote.id))).getSingleOrNull();
        if (local != null &&
            (local.libraryId != remote.libraryId ||
                local.itemId != remote.itemId)) {
          throw const FormatException('Study record ownership cannot change');
        }
        final selected = local == null
            ? [remote]
            : SyncConflictResolver.preserveUserContentConflict(
                local.toJson(),
                remote.toJson(),
              ).map(Bookmark.fromJson);
        for (final bookmark in selected) {
          final previous = await (database.select(
            database.bookmarks,
          )..where((t) => t.id.equals(bookmark.id))).getSingleOrNull();
          if (previous == null ||
              SyncIntent.canonical(previous.toJson()) !=
                  SyncIntent.canonical(bookmark.toJson()))
            await database
                .into(database.bookmarks)
                .insertOnConflictUpdate(bookmark);
        }
      }
      await database.importMediaRows(
        snapshot,
        allowedLibraryIds: allowedLibraryIds,
      );
      await CatalogIdentityStore(database).importRows(
        snapshot['catalogRows'],
        allowedLibraryIds: allowedLibraryIds,
        transport: true,
      );
      for (final sectionId in affectedSections) {
        await database.refreshSectionCounts(sectionId);
      }
    });
  }
}
