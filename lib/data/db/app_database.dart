import '../../domain/catalog/library_processing.dart';
import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../domain/catalog/media_record_contract.dart';
import '../../domain/catalog/catalog_identity_store.dart';
import '../indexer/library_source_store.dart';
import '../sync/library_access_store.dart';
import '../sync/sync_change_journal.dart';
import '../../domain/services/sync_conflict_resolver.dart';

part 'app_database.g.dart';

class Libraries extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get description => text().withDefault(const Constant(''))();
  TextColumn get rootFolderPath => text()();
  TextColumn get coverPath => text().nullable()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  IntColumn get lastScannedAt => integer().nullable()();
  BoolColumn get unavailable => boolean().withDefault(const Constant(false))();
  IntColumn get version => integer().withDefault(const Constant(1))();
  TextColumn get updatedByDevice =>
      text().withDefault(const Constant('local'))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class Sections extends Table {
  TextColumn get id => text()();
  TextColumn get libraryId => text().references(Libraries, #id)();
  TextColumn get title => text()();
  TextColumn get relativePath => text().withDefault(const Constant(''))();
  TextColumn get parentSectionId => text().nullable()();
  IntColumn get orderIndex => integer()();
  TextColumn get folderPath => text()();
  IntColumn get itemCount => integer().withDefault(const Constant(0))();
  IntColumn get completedCount => integer().withDefault(const Constant(0))();
  BoolColumn get unavailable => boolean().withDefault(const Constant(false))();
  IntColumn get updatedAt => integer().withDefault(const Constant(0))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class Items extends Table {
  TextColumn get id => text()();
  TextColumn get libraryId => text().references(Libraries, #id)();
  TextColumn get sectionId => text().references(Sections, #id)();
  TextColumn get title => text()();
  TextColumn get userTitle => text().nullable()();
  TextColumn get filename => text()();
  TextColumn get filePath => text()();
  TextColumn get relativePath => text()();
  TextColumn get itemType => text()();
  IntColumn get orderIndex => integer()();
  RealColumn get durationSeconds => real().nullable()();
  IntColumn get pageCount => integer().nullable()();
  TextColumn get thumbnailPath => text().nullable()();
  IntColumn get modifiedAt => integer().nullable()();
  IntColumn get fileSize => integer().nullable()();
  TextColumn get fingerprint => text().nullable()();
  BoolColumn get unavailable => boolean().withDefault(const Constant(false))();
  IntColumn get createdAt => integer().withDefault(const Constant(0))();
  IntColumn get updatedAt => integer().withDefault(const Constant(0))();
  IntColumn get version => integer().withDefault(const Constant(1))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class PlaybackProgress extends Table {
  TextColumn get itemId => text().references(Items, #id)();
  RealColumn get lastPositionSeconds => real().withDefault(const Constant(0))();
  RealColumn get resumePositionSeconds =>
      real().withDefault(const Constant(0))();
  RealColumn get durationSeconds => real().withDefault(const Constant(0))();
  RealColumn get percentWatched => real().withDefault(const Constant(0))();
  BoolColumn get completed => boolean().withDefault(const Constant(false))();
  BoolColumn get manualCompletion => boolean().nullable()();
  RealColumn get playbackSpeed => real().withDefault(const Constant(1))();
  IntColumn get lastOpenedAt => integer().withDefault(const Constant(0))();
  IntColumn get lastEventAt => integer().withDefault(const Constant(0))();
  TextColumn get deviceId => text()();
  IntColumn get version => integer().withDefault(const Constant(1))();

  @override
  Set<Column<Object>> get primaryKey => {itemId};
}

class ReadingProgress extends Table {
  TextColumn get itemId => text().references(Items, #id)();
  IntColumn get lastPage => integer().withDefault(const Constant(1))();
  RealColumn get lastScrollOffset => real().withDefault(const Constant(0))();
  IntColumn get resumePage => integer().withDefault(const Constant(1))();
  RealColumn get resumeScrollOffset => real().withDefault(const Constant(0))();
  RealColumn get percentRead => real().withDefault(const Constant(0))();
  BoolColumn get completed => boolean().withDefault(const Constant(false))();
  BoolColumn get manualCompletion => boolean().nullable()();
  RealColumn get zoom => real().withDefault(const Constant(1))();
  TextColumn get readingMode =>
      text().withDefault(const Constant('fitWidth'))();
  IntColumn get lastOpenedAt => integer().withDefault(const Constant(0))();
  IntColumn get lastEventAt => integer().withDefault(const Constant(0))();
  TextColumn get deviceId => text()();
  IntColumn get version => integer().withDefault(const Constant(1))();

  @override
  Set<Column<Object>> get primaryKey => {itemId};
}

class Notes extends Table {
  TextColumn get id => text()();
  TextColumn get libraryId => text().references(Libraries, #id)();
  TextColumn get itemId => text().nullable().references(Items, #id)();
  TextColumn get content => text()();
  RealColumn get positionSeconds => real().nullable()();
  IntColumn get pageNumber => integer().nullable()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  TextColumn get deviceId => text()();
  IntColumn get version => integer().withDefault(const Constant(1))();
  BoolColumn get deleted => boolean().withDefault(const Constant(false))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class Bookmarks extends Table {
  TextColumn get id => text()();
  TextColumn get libraryId => text().references(Libraries, #id)();
  TextColumn get itemId => text().references(Items, #id)();
  TextColumn get title => text()();
  TextColumn get description => text().nullable()();
  RealColumn get positionSeconds => real().nullable()();
  IntColumn get pageNumber => integer().nullable()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  TextColumn get deviceId => text()();
  IntColumn get version => integer().withDefault(const Constant(1))();
  BoolColumn get deleted => boolean().withDefault(const Constant(false))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class KnownDevices extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get tokenHash => text()();
  BoolColumn get approved => boolean().withDefault(const Constant(false))();
  IntColumn get createdAt => integer()();
  IntColumn get lastSeenAt => integer().nullable()();
  IntColumn get lastSyncAt => integer().nullable()();
  TextColumn get lastAddress => text().nullable()();
  BoolColumn get revoked => boolean().withDefault(const Constant(false))();
  IntColumn get version => integer().withDefault(const Constant(1))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class SyncChanges extends Table {
  TextColumn get id => text()();
  TextColumn get entityType => text()();
  TextColumn get entityId => text()();
  TextColumn get operation => text()();
  TextColumn get payload => text()();
  IntColumn get version => integer()();
  TextColumn get deviceId => text()();
  IntColumn get createdAt => integer()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class AppSettings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}

class SectionProgressEntry {
  const SectionProgressEntry({
    required this.section,
    required this.totalItems,
    required this.completedItems,
    required this.progressPercent,
  });

  final Section section;
  final int totalItems;
  final int completedItems;
  final double progressPercent;
}

class ItemProgressEntry {
  const ItemProgressEntry({
    required this.item,
    required this.progressPercent,
    required this.completed,
    required this.status,
  });

  final Item item;
  final double progressPercent;
  final bool completed;
  final String status;
}

class ContinueEntry {
  const ContinueEntry({
    required this.item,
    required this.progressPercent,
    required this.completed,
    required this.lastOpenedAt,
    required this.kind,
  });

  final Item item;
  final double progressPercent;
  final bool completed;
  final int lastOpenedAt;
  final String kind;
}

class SearchEntry {
  const SearchEntry({
    required this.item,
    required this.libraryTitle,
    required this.sectionTitle,
    required this.progressPercent,
    required this.completed,
  });

  final Item item;
  final String libraryTitle;
  final String sectionTitle;
  final double progressPercent;
  final bool completed;
}

class GlobalSearchEntry {
  const GlobalSearchEntry({
    required this.kind,
    required this.title,
    required this.libraryTitle,
    required this.sectionTitle,
    required this.item,
    required this.progressPercent,
    required this.completed,
    required this.updatedAt,
    this.positionSeconds,
    this.pageNumber,
    this.libraryId,
    this.referenceId,
  });

  final String? libraryId, referenceId;
  final String kind;
  final String title;
  final String libraryTitle;
  final String sectionTitle;
  final Item? item;
  final double progressPercent;
  final bool completed;
  final int updatedAt;
  final double? positionSeconds;
  final int? pageNumber;
}

class LibraryStats {
  const LibraryStats({
    required this.totalItems,
    required this.completedItems,
    required this.inProgressItems,
    required this.lastActivityAt,
  });

  final int totalItems;
  final int completedItems;
  final int inProgressItems;
  final int? lastActivityAt;

  double get percent => totalItems == 0 ? 0 : completedItems * 100 / totalItems;
}

@DriftDatabase(
  tables: [
    Libraries,
    Sections,
    Items,
    PlaybackProgress,
    ReadingProgress,
    Notes,
    Bookmarks,
    KnownDevices,
    SyncChanges,
    AppSettings,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 5;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await _createMediaTables();
    },
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.addColumn(libraries, libraries.description);
        await m.addColumn(libraries, libraries.coverPath);
        await m.addColumn(libraries, libraries.lastScannedAt);
        await m.addColumn(libraries, libraries.unavailable);
        await m.addColumn(libraries, libraries.version);
        await m.addColumn(libraries, libraries.updatedByDevice);
        await m.addColumn(sections, sections.relativePath);
        await m.addColumn(sections, sections.parentSectionId);
        await m.addColumn(sections, sections.unavailable);
        await m.addColumn(sections, sections.updatedAt);
        await m.addColumn(items, items.userTitle);
        await m.addColumn(items, items.fileSize);
        await m.addColumn(items, items.fingerprint);
        await m.addColumn(items, items.createdAt);
        await m.addColumn(items, items.updatedAt);
        await m.addColumn(items, items.version);
        await m.addColumn(playbackProgress, playbackProgress.durationSeconds);
        await m.addColumn(playbackProgress, playbackProgress.manualCompletion);
        await m.addColumn(playbackProgress, playbackProgress.playbackSpeed);
        await m.addColumn(playbackProgress, playbackProgress.version);
        await m.addColumn(readingProgress, readingProgress.manualCompletion);
        await m.addColumn(readingProgress, readingProgress.zoom);
        await m.addColumn(readingProgress, readingProgress.readingMode);
        await m.addColumn(readingProgress, readingProgress.version);
        await m.createTable(notes);
        await m.createTable(bookmarks);
        await m.createTable(knownDevices);
        await m.createTable(syncChanges);
        await m.createTable(appSettings);
      }
    },
    beforeOpen: (_) async {
      await customStatement('PRAGMA busy_timeout=5000');
      await customStatement('PRAGMA journal_mode=WAL');
      await _createMediaTables();
      await _backfillSources();
      await LibrarySourceStore(this).createTables();
      await LibrarySourceStore(this).backfill();
      await CatalogIdentityStore(this).createTables();
      await LibraryProcessingStore.createTables(this);
      await CatalogIdentityStore(this).backfill();
      await LibraryAccessStore(this).createTables();
      await SyncChangeJournal(this).createTables();
      await customStatement('PRAGMA foreign_keys = ON');
      await _createIndexes();
    },
  );

  // Additive extension tables deliberately keep the original item schema/IDs.
  Future<void> _createMediaTables() async {
    await customStatement(
      'CREATE TABLE IF NOT EXISTS library_sources (id TEXT PRIMARY KEY, library_id TEXT NOT NULL REFERENCES libraries(id) ON DELETE CASCADE, root_path TEXT NOT NULL, namespace TEXT NOT NULL, unavailable INTEGER NOT NULL DEFAULT 0, updated_at INTEGER NOT NULL)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_sources_library ON library_sources(library_id)',
    );
    await customStatement(
      'CREATE TABLE IF NOT EXISTS media_records (id TEXT PRIMARY KEY, kind TEXT NOT NULL, library_id TEXT NOT NULL REFERENCES libraries(id) ON DELETE CASCADE, item_id TEXT REFERENCES items(id) ON DELETE CASCADE, payload TEXT NOT NULL, updated_at INTEGER NOT NULL, device_id TEXT NOT NULL, deleted INTEGER NOT NULL DEFAULT 0)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_media_kind_library ON media_records(kind, library_id, item_id)',
    );
  }

  Future<void> _backfillSources() async {
    await customStatement(
      "INSERT OR IGNORE INTO library_sources(id, library_id, root_path, namespace, unavailable, updated_at) SELECT 'legacy:' || id, id, root_folder_path, '', unavailable, updated_at FROM libraries WHERE root_folder_path NOT LIKE 'remote:%' AND root_folder_path NOT LIKE 'import:%'",
    );
  }

  Future<List<Map<String, dynamic>>> exportMediaRows(String table) async {
    if (table != 'media_records' && table != 'library_sources') {
      throw ArgumentError('Invalid media table');
    }
    return (await customSelect(
      'SELECT * FROM $table',
    ).get()).map((row) => row.data).toList();
  }

  Future<void> importMediaRows(
    Map<String, dynamic> snapshot, {
    bool includeSources = false,
    Set<String>? allowedLibraryIds,
  }) => transaction(() async {
    var discoveryChanged = false;
    for (final table in [
      'media_records',
      if (includeSources) 'library_sources',
    ]) {
      final input =
          snapshot[table == 'media_records' ? 'mediaRecords' : 'sources'];
      if (input == null) continue;
      if (input is! List || input.length > 100000) {
        throw const FormatException('Invalid media records');
      }
      for (final value in input) {
        if (value is! Map<String, dynamic>) {
          throw const FormatException('Invalid media record');
        }
        final row = Map<String, dynamic>.of(value);
        final id = row['id'], libraryId = row['library_id'];
        if (id is! String || libraryId is! String) {
          throw const FormatException('Invalid media identity');
        }
        MediaRecordContract.identity(id);
        MediaRecordContract.identity(libraryId);
        MediaRecordContract.revision(row['updated_at']);
        if (allowedLibraryIds != null &&
            !allowedLibraryIds.contains(libraryId)) {
          continue;
        }
        final existing = await customSelect(
          'SELECT * FROM $table WHERE id = ?',
          variables: [Variable(id)],
        ).getSingleOrNull();
        if (existing != null && existing.data['library_id'] != libraryId) {
          throw const FormatException('Media record ownership cannot change');
        }
        final library = await getLibraryById(libraryId);
        if (library == null) continue;
        if (table == 'media_records') {
          final kind = row['kind'], itemId = row['item_id'];
          final payload = row['payload'], deviceId = row['device_id'];
          if (kind is! String ||
              itemId != null && itemId is! String ||
              payload is! String ||
              deviceId is! String ||
              row['deleted'] is! int ||
              ![0, 1].contains(row['deleted'])) {
            throw const FormatException('Invalid media record fields');
          }
          if (kind != 'reader') discoveryChanged = true;
          MediaRecordContract.identity(deviceId);
          if (utf8.encode(payload).length >
              MediaRecordContract.maxPayloadBytes) {
            throw const FormatException('Metadata is too large');
          }
          final decoded = jsonDecode(payload);
          if (decoded is! Map<String, dynamic>) {
            throw const FormatException('Metadata must be an object');
          }
          MediaRecordContract.validate(
            id: id,
            kind: kind,
            libraryId: libraryId,
            itemId: itemId as String?,
            data: decoded,
            allowUnknownKind: includeSources,
          );
          if (existing != null &&
              (existing.data['kind'] != kind ||
                  existing.data['item_id'] != itemId)) {
            throw const FormatException('Media record ownership cannot change');
          }
          if (itemId != null) {
            final item = await getItemById(itemId);
            if (item == null) continue;
            if (item.libraryId != libraryId) {
              throw const FormatException('Item is outside this library');
            }
          }
          if (['collection', 'playlist', 'album'].contains(kind)) {
            for (final member in (decoded['items'] as List).cast<String>()) {
              if ((await getItemById(member))?.libraryId != libraryId) {
                throw const FormatException(
                  'Collection item is outside this library',
                );
              }
            }
          }
        } else {
          final root = row['root_path'], namespace = row['namespace'];
          if (root is! String ||
              root.length > 32768 ||
              !p.isAbsolute(root) ||
              root.contains('\x00') ||
              namespace is! String ||
              p.basename(id) != id ||
              id == '.' ||
              id == '..' ||
              (namespace.isEmpty
                  ? id != 'legacy:$libraryId'
                  : namespace != p.join('@sources', id)) ||
              row['unavailable'] is! int ||
              ![0, 1].contains(row['unavailable'])) {
            throw const FormatException('Invalid library source');
          }
          if (existing != null && existing.data['namespace'] != namespace) {
            throw const FormatException('Source namespace cannot change');
          }
        }
        final columns = table == 'media_records'
            ? [
                'id',
                'kind',
                'library_id',
                'item_id',
                'payload',
                'updated_at',
                'device_id',
                'deleted',
              ]
            : [
                'id',
                'library_id',
                'root_path',
                'namespace',
                'unavailable',
                'updated_at',
              ];
        await customStatement(
          'INSERT INTO $table (${columns.join(',')}) VALUES (${columns.map((_) => '?').join(',')}) '
          'ON CONFLICT(id) DO UPDATE SET ${columns.skip(1).map((c) => '$c = excluded.$c').join(',')} '
          'WHERE excluded.updated_at > $table.updated_at',
          columns.map((c) => row[c]).toList(),
        );
      }
    }
    if (discoveryChanged) notifyUpdates({TableUpdate.onTable(appSettings)});
  });

  Future<void> _createIndexes() async {
    const statements = [
      'CREATE INDEX IF NOT EXISTS idx_sections_library_order ON sections (library_id, order_index)',
      'CREATE INDEX IF NOT EXISTS idx_items_library ON items (library_id)',
      'CREATE INDEX IF NOT EXISTS idx_items_section_order ON items (section_id, order_index)',
      'CREATE INDEX IF NOT EXISTS idx_items_relative_path ON items (library_id, relative_path)',
      'CREATE INDEX IF NOT EXISTS idx_items_fingerprint ON items (library_id, fingerprint)',
      'CREATE INDEX IF NOT EXISTS idx_playback_recent ON playback_progress (last_opened_at)',
      'CREATE INDEX IF NOT EXISTS idx_reading_recent ON reading_progress (last_opened_at)',
      'CREATE INDEX IF NOT EXISTS idx_notes_item ON notes (item_id, updated_at)',
      'CREATE INDEX IF NOT EXISTS idx_notes_page ON notes (library_id,item_id,deleted,updated_at DESC,id DESC)',
      'CREATE INDEX IF NOT EXISTS idx_bookmarks_page ON bookmarks (library_id,item_id,deleted,updated_at DESC,id DESC)',
      'CREATE INDEX IF NOT EXISTS idx_bookmarks_item ON bookmarks (item_id, updated_at)',
      'CREATE INDEX IF NOT EXISTS idx_sync_changes_created ON sync_changes (created_at)',
    ];
    for (final statement in statements) {
      await customStatement(statement);
    }
  }

  Future<void> upsertLibrary(LibrariesCompanion data) =>
      into(libraries).insertOnConflictUpdate(data);

  Future<void> updateLibraryMetadata({
    required String id,
    required String title,
    required String description,
    String? coverPath,
  }) async {
    final existing = await getLibraryById(id);
    if (existing == null) return;
    await (update(libraries)..where((t) => t.id.equals(id))).write(
      LibrariesCompanion(
        title: Value(title.trim()),
        description: Value(description.trim()),
        coverPath: Value(coverPath),
        updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
        version: Value(existing.version + 1),
      ),
    );
  }

  Future<void> upsertSection(SectionsCompanion data) async {
    await into(sections).insertOnConflictUpdate(data);
    await refreshSectionCounts(data.id.value);
  }

  Future<void> upsertItem(ItemsCompanion data) async {
    await into(items).insertOnConflictUpdate(data);
    await refreshSectionCounts(data.sectionId.value);
  }

  Future<void> applyScan({
    required String libraryId,
    required List<SectionsCompanion> scannedSections,
    required List<ItemsCompanion> scannedItems,
    required Set<String> seenSectionIds,
    required Set<String> seenItemIds,
  }) async {
    await transaction(() async {
      for (final section in scannedSections) {
        await into(sections).insertOnConflictUpdate(section);
      }
      for (final item in scannedItems) {
        await into(items).insertOnConflictUpdate(item);
      }

      final existingItems = await getItemsForLibrary(libraryId);
      for (final item in existingItems) {
        if (!seenItemIds.contains(item.id) && !item.unavailable) {
          await (update(items)..where((t) => t.id.equals(item.id))).write(
            ItemsCompanion(
              unavailable: const Value(true),
              updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
            ),
          );
        }
      }

      final existingSections = await getSectionsForLibrary(libraryId);
      for (final section in existingSections) {
        if (!seenSectionIds.contains(section.id) && !section.unavailable) {
          await (update(sections)..where((t) => t.id.equals(section.id))).write(
            const SectionsCompanion(unavailable: Value(true)),
          );
        }
      }

      for (final section in await getSectionsForLibrary(libraryId)) {
        await refreshSectionCounts(section.id);
      }

      await (update(libraries)..where((t) => t.id.equals(libraryId))).write(
        LibrariesCompanion(
          lastScannedAt: Value(DateTime.now().millisecondsSinceEpoch),
          unavailable: const Value(false),
        ),
      );
    });
  }

  Future<void> markLibraryUnavailable(String libraryId, bool value) =>
      (update(libraries)..where((t) => t.id.equals(libraryId))).write(
        LibrariesCompanion(unavailable: Value(value)),
      );

  Future<void> upsertPlayback(PlaybackProgressCompanion data) async {
    await into(playbackProgress).insertOnConflictUpdate(data);
    final sectionId = await _sectionIdForItem(data.itemId.value);
    if (sectionId != null) await refreshSectionCounts(sectionId);
  }

  Future<void> upsertReading(ReadingProgressCompanion data) async {
    await into(readingProgress).insertOnConflictUpdate(data);
    final sectionId = await _sectionIdForItem(data.itemId.value);
    if (sectionId != null) await refreshSectionCounts(sectionId);
  }

  Future<Library?> getLibraryById(String libraryId) => (select(
    libraries,
  )..where((t) => t.id.equals(libraryId))).getSingleOrNull();

  Future<Item?> getItemById(String itemId) =>
      (select(items)..where((t) => t.id.equals(itemId))).getSingleOrNull();

  Future<List<Item>> getItemsForLibrary(String libraryId) =>
      (select(items)..where((t) => t.libraryId.equals(libraryId))).get();

  Future<List<Section>> getSectionsForLibrary(String libraryId) =>
      (select(sections)..where((t) => t.libraryId.equals(libraryId))).get();

  Future<void> relinkItem({
    required String itemId,
    required String filePath,
    required String filename,
    required String relativePath,
    required int modifiedAt,
    required int fileSize,
    required String fingerprint,
  }) => (update(items)..where((t) => t.id.equals(itemId))).write(
    ItemsCompanion(
      filePath: Value(filePath),
      filename: Value(filename),
      relativePath: Value(relativePath),
      modifiedAt: Value(modifiedAt),
      fileSize: Value(fileSize),
      fingerprint: Value(fingerprint),
      unavailable: const Value(false),
      updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
    ),
  );

  Future<void> updateItemTitle(String itemId, String? userTitle) async {
    final existing = await getItemById(itemId);
    if (existing == null) return;
    final value = userTitle?.trim();
    await (update(items)..where((t) => t.id.equals(itemId))).write(
      ItemsCompanion(
        userTitle: Value(value == null || value.isEmpty ? null : value),
        updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
        version: Value(existing.version + 1),
      ),
    );
  }

  Future<PlaybackProgressData?> getPlaybackByItemId(String itemId) => (select(
    playbackProgress,
  )..where((t) => t.itemId.equals(itemId))).getSingleOrNull();

  Future<ReadingProgressData?> getReadingByItemId(String itemId) => (select(
    readingProgress,
  )..where((t) => t.itemId.equals(itemId))).getSingleOrNull();

  Stream<List<Library>> watchLibraries() =>
      (select(libraries)..orderBy([(t) => OrderingTerm.asc(t.title)])).watch();

  Stream<List<SectionProgressEntry>> watchSectionProgressForLibrary(
    String libraryId,
  ) {
    return (select(sections)
          ..where((t) => t.libraryId.equals(libraryId))
          ..orderBy([
            (t) => OrderingTerm.asc(t.orderIndex),
            (t) => OrderingTerm.asc(t.title),
          ]))
        .watch()
        .map(
          (rows) => rows
              .map(
                (section) => SectionProgressEntry(
                  section: section,
                  totalItems: section.itemCount,
                  completedItems: section.completedCount,
                  progressPercent: section.itemCount == 0
                      ? 0
                      : section.completedCount * 100 / section.itemCount,
                ),
              )
              .toList(),
        );
  }

  Stream<List<ItemProgressEntry>> watchItemProgressForSection(
    String sectionId,
  ) {
    final query =
        select(items).join([
            leftOuterJoin(
              playbackProgress,
              playbackProgress.itemId.equalsExp(items.id),
            ),
            leftOuterJoin(
              readingProgress,
              readingProgress.itemId.equalsExp(items.id),
            ),
          ])
          ..where(items.sectionId.equals(sectionId))
          ..orderBy([
            OrderingTerm.asc(items.orderIndex),
            OrderingTerm.asc(items.title),
          ]);
    return query.watch().map(
      (rows) => rows.map((row) {
        final item = row.readTable(items);
        final playback = row.readTableOrNull(playbackProgress);
        final reading = row.readTableOrNull(readingProgress);
        final percent = playback?.percentWatched ?? reading?.percentRead ?? 0;
        final completed = playback?.completed ?? reading?.completed ?? false;
        return ItemProgressEntry(
          item: item,
          progressPercent: percent,
          completed: completed,
          status: item.unavailable
              ? 'Missing'
              : completed
              ? 'Completed'
              : percent > 0
              ? 'In progress'
              : 'Not started',
        );
      }).toList(),
    );
  }

  Future<(double, bool)> getMergedProgressForItem(String itemId) async {
    final playback = await getPlaybackByItemId(itemId);
    if (playback != null) return (playback.percentWatched, playback.completed);
    final reading = await getReadingByItemId(itemId);
    if (reading != null) return (reading.percentRead, reading.completed);
    return (0.0, false);
  }

  Future<Item?> getNextSequentialItem(String currentItemId) =>
      _getAdjacentItem(currentItemId, forward: true);

  Future<Item?> getPreviousSequentialItem(String currentItemId) =>
      _getAdjacentItem(currentItemId, forward: false);

  Future<Item?> _getAdjacentItem(
    String currentItemId, {
    required bool forward,
  }) async {
    final current = await getItemById(currentItemId);
    if (current == null) return null;
    final orderedSections =
        await (select(sections)
              ..where(
                (t) =>
                    t.libraryId.equals(current.libraryId) & t.unavailable.not(),
              )
              ..orderBy([(t) => OrderingTerm.asc(t.orderIndex)]))
            .get();
    final orderedItems = <Item>[];
    for (final section in orderedSections) {
      orderedItems.addAll(
        await (select(items)
              ..where(
                (t) => t.sectionId.equals(section.id) & t.unavailable.not(),
              )
              ..orderBy([(t) => OrderingTerm.asc(t.orderIndex)]))
            .get(),
      );
    }
    final index = orderedItems.indexWhere((item) => item.id == current.id);
    final adjacent = forward ? index + 1 : index - 1;
    if (index < 0 || adjacent < 0 || adjacent >= orderedItems.length) {
      return null;
    }
    return orderedItems[adjacent];
  }

  Stream<List<ContinueEntry>> watchRecentPlaybackEntries({
    int limit = 8,
    String? itemType,
  }) {
    final query =
        select(playbackProgress).join([
            innerJoin(items, items.id.equalsExp(playbackProgress.itemId)),
          ])
          ..where(
            items.unavailable.not() &
                playbackProgress.completed.not() &
                items.itemType.isIn(
                  itemType == null ? ['video', 'audio'] : [itemType],
                ),
          )
          ..orderBy([OrderingTerm.desc(playbackProgress.lastOpenedAt)])
          ..limit(limit);
    return query.watch().map(
      (rows) => rows
          .map(
            (row) => ContinueEntry(
              item: row.readTable(items),
              progressPercent: row.readTable(playbackProgress).percentWatched,
              completed: row.readTable(playbackProgress).completed,
              lastOpenedAt: row.readTable(playbackProgress).lastOpenedAt,
              kind: 'media',
            ),
          )
          .toList(),
    );
  }

  Stream<List<ContinueEntry>> watchRecentReadingEntries({int limit = 8}) {
    final query =
        select(
            readingProgress,
          ).join([innerJoin(items, items.id.equalsExp(readingProgress.itemId))])
          ..where(items.unavailable.not() & readingProgress.completed.not())
          ..orderBy([OrderingTerm.desc(readingProgress.lastOpenedAt)])
          ..limit(limit);
    return query.watch().map(
      (rows) => rows
          .map(
            (row) => ContinueEntry(
              item: row.readTable(items),
              progressPercent: row.readTable(readingProgress).percentRead,
              completed: row.readTable(readingProgress).completed,
              lastOpenedAt: row.readTable(readingProgress).lastOpenedAt,
              kind: 'reading',
            ),
          )
          .toList(),
    );
  }

  Future<LibraryStats> getLibraryStats(String libraryId) async {
    final rows =
        await (select(items).join([
              leftOuterJoin(
                playbackProgress,
                playbackProgress.itemId.equalsExp(items.id),
              ),
              leftOuterJoin(
                readingProgress,
                readingProgress.itemId.equalsExp(items.id),
              ),
            ])..where(
              items.libraryId.equals(libraryId) & items.unavailable.not(),
            ))
            .get();
    var completed = 0;
    var inProgress = 0;
    int? lastActivity;
    for (final row in rows) {
      final playback = row.readTableOrNull(playbackProgress);
      final reading = row.readTableOrNull(readingProgress);
      final isCompleted = playback?.completed ?? reading?.completed ?? false;
      final percent = playback?.percentWatched ?? reading?.percentRead ?? 0;
      if (isCompleted) {
        completed++;
      } else if (percent > 0) {
        inProgress++;
      }
      final opened = playback?.lastOpenedAt ?? reading?.lastOpenedAt;
      if (opened != null && (lastActivity == null || opened > lastActivity)) {
        lastActivity = opened;
      }
    }
    return LibraryStats(
      totalItems: rows.length,
      completedItems: completed,
      inProgressItems: inProgress,
      lastActivityAt: lastActivity,
    );
  }

  Future<List<SearchEntry>> searchItems(String rawQuery) async =>
      (await searchAll(rawQuery))
          .where((entry) => entry.kind == 'lesson' && entry.item != null)
          .map(
            (entry) => SearchEntry(
              item: entry.item!,
              libraryTitle: entry.libraryTitle,
              sectionTitle: entry.sectionTitle,
              progressPercent: entry.progressPercent,
              completed: entry.completed,
            ),
          )
          .toList();

  /// Matching and limits run in SQLite rather than materializing the full library.
  Future<List<GlobalSearchEntry>> searchAll(
    String rawQuery, {
    int limit = 200,
  }) async {
    final text = rawQuery.trim().toLowerCase();
    if (text.isEmpty) return [];
    final maximum = limit.clamp(1, 500);
    final results = <GlobalSearchEntry>[];
    final itemMatch =
        items.title.lower().contains(text) |
        items.userTitle.lower().contains(text) |
        items.filename.lower().contains(text) |
        items.relativePath.lower().contains(text);
    final contextMatch =
        libraries.title.lower().contains(text) |
        sections.title.lower().contains(text);
    final joins = [
      leftOuterJoin(items, items.id.equalsExp(notes.itemId)),
      innerJoin(libraries, libraries.id.equalsExp(notes.libraryId)),
      leftOuterJoin(sections, sections.id.equalsExp(items.sectionId)),
      leftOuterJoin(
        playbackProgress,
        playbackProgress.itemId.equalsExp(items.id),
      ),
      leftOuterJoin(
        readingProgress,
        readingProgress.itemId.equalsExp(items.id),
      ),
    ];
    GlobalSearchEntry entry(
      TypedResult row,
      String kind,
      String title,
      int updatedAt, {
      double? position,
      int? page,
    }) {
      final item = row.readTableOrNull(items);
      final library = row.readTable(libraries);
      final section = row.readTableOrNull(sections);
      final playback = row.readTableOrNull(playbackProgress);
      final reading = row.readTableOrNull(readingProgress);
      return GlobalSearchEntry(
        kind: kind,
        title: title,
        libraryTitle: library.title,
        sectionTitle: section?.title ?? 'General note',
        item: item,
        libraryId: library.id,
        progressPercent: playback?.percentWatched ?? reading?.percentRead ?? 0,
        completed: playback?.completed ?? reading?.completed ?? false,
        updatedAt: updatedAt,
        positionSeconds: position,
        pageNumber: page,
      );
    }

    final lessons =
        await (select(items).join([
                innerJoin(libraries, libraries.id.equalsExp(items.libraryId)),
                innerJoin(sections, sections.id.equalsExp(items.sectionId)),
                leftOuterJoin(
                  playbackProgress,
                  playbackProgress.itemId.equalsExp(items.id),
                ),
                leftOuterJoin(
                  readingProgress,
                  readingProgress.itemId.equalsExp(items.id),
                ),
              ])
              ..where(itemMatch | contextMatch)
              ..orderBy([OrderingTerm.desc(items.updatedAt)])
              ..limit(maximum))
            .get();
    for (final row in lessons) {
      final item = row.readTable(items);
      results.add(
        entry(row, 'lesson', item.userTitle ?? item.title, item.updatedAt),
      );
    }
    final noteRows =
        await (select(notes).join(joins)
              ..where(
                notes.deleted.not() &
                    (notes.content.lower().contains(text) |
                        itemMatch |
                        contextMatch),
              )
              ..orderBy([OrderingTerm.desc(notes.updatedAt)])
              ..limit(maximum))
            .get();
    for (final row in noteRows) {
      final note = row.readTable(notes);
      results.add(
        entry(
          row,
          'note',
          note.content,
          note.updatedAt,
          position: note.positionSeconds,
          page: note.pageNumber,
        ),
      );
    }
    final bookmarkRows =
        await (select(bookmarks).join([
                innerJoin(items, items.id.equalsExp(bookmarks.itemId)),
                innerJoin(
                  libraries,
                  libraries.id.equalsExp(bookmarks.libraryId),
                ),
                innerJoin(sections, sections.id.equalsExp(items.sectionId)),
                leftOuterJoin(
                  playbackProgress,
                  playbackProgress.itemId.equalsExp(items.id),
                ),
                leftOuterJoin(
                  readingProgress,
                  readingProgress.itemId.equalsExp(items.id),
                ),
              ])
              ..where(
                bookmarks.deleted.not() &
                    (bookmarks.title.lower().contains(text) |
                        bookmarks.description.lower().contains(text) |
                        itemMatch |
                        contextMatch),
              )
              ..orderBy([OrderingTerm.desc(bookmarks.updatedAt)])
              ..limit(maximum))
            .get();
    for (final row in bookmarkRows) {
      final bookmark = row.readTable(bookmarks);
      results.add(
        entry(
          row,
          'bookmark',
          bookmark.title,
          bookmark.updatedAt,
          position: bookmark.positionSeconds,
          page: bookmark.pageNumber,
        ),
      );
    }
    for (final library
        in await (select(libraries)
              ..where(
                (t) =>
                    t.title.lower().contains(text) |
                    t.description.lower().contains(text),
              )
              ..limit(30))
            .get()) {
      results.add(
        GlobalSearchEntry(
          kind: 'library',
          title: library.title,
          libraryTitle: library.title,
          sectionTitle: 'Library',
          item: null,
          libraryId: library.id,
          progressPercent: 0,
          completed: false,
          updatedAt: library.updatedAt,
        ),
      );
    }
    for (final row
        in await (select(sections).join([
                innerJoin(
                  libraries,
                  libraries.id.equalsExp(sections.libraryId),
                ),
              ])
              ..where(sections.title.lower().contains(text))
              ..limit(50))
            .get()) {
      final section = row.readTable(sections);
      results.add(
        GlobalSearchEntry(
          kind: 'section',
          title: section.title,
          libraryTitle: row.readTable(libraries).title,
          sectionTitle: 'Section',
          item: null,
          libraryId: section.libraryId,
          progressPercent: 0,
          completed: false,
          updatedAt: section.updatedAt,
        ),
      );
    }
    results.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return results.take(maximum).toList();
  }

  Future<void> setItemCompletion({
    required Item item,
    required bool completed,
    String deviceId = 'local',
  }) async {
    await transaction(() async {
      deviceId = deviceId == 'local' ? await getDeviceId() : deviceId;
      final now = DateTime.now().millisecondsSinceEpoch;
      if (item.itemType == 'video' || item.itemType == 'audio') {
        final old = await getPlaybackByItemId(item.id);
        await upsertPlayback(
          PlaybackProgressCompanion(
            itemId: Value(item.id),
            lastPositionSeconds: Value(old?.lastPositionSeconds ?? 0),
            resumePositionSeconds: Value(old?.resumePositionSeconds ?? 0),
            durationSeconds: Value(
              old?.durationSeconds ?? item.durationSeconds ?? 0,
            ),
            percentWatched: Value(completed ? 100 : old?.percentWatched ?? 0),
            completed: Value(completed),
            manualCompletion: Value(completed),
            playbackSpeed: Value(old?.playbackSpeed ?? 1),
            lastOpenedAt: Value(old?.lastOpenedAt ?? now),
            lastEventAt: Value(now),
            deviceId: Value(deviceId),
            version: Value((old?.version ?? 0) + 1),
          ),
        );
      } else {
        final old = await getReadingByItemId(item.id);
        await upsertReading(
          ReadingProgressCompanion(
            itemId: Value(item.id),
            lastPage: Value(old?.lastPage ?? 1),
            lastScrollOffset: Value(old?.lastScrollOffset ?? 0),
            resumePage: Value(old?.resumePage ?? 1),
            resumeScrollOffset: Value(old?.resumeScrollOffset ?? 0),
            percentRead: Value(completed ? 100 : old?.percentRead ?? 0),
            completed: Value(completed),
            manualCompletion: Value(completed),
            zoom: Value(old?.zoom ?? 1),
            readingMode: Value(old?.readingMode ?? 'fitWidth'),
            lastOpenedAt: Value(old?.lastOpenedAt ?? now),
            lastEventAt: Value(now),
            deviceId: Value(deviceId),
            version: Value((old?.version ?? 0) + 1),
          ),
        );
      }
    });
  }

  Stream<List<Note>> watchNotes({String? itemId, String? libraryId}) {
    final query = select(notes)
      ..where((t) {
        var expression = t.deleted.not();
        if (itemId != null) expression = expression & t.itemId.equals(itemId);
        if (libraryId != null) {
          expression = expression & t.libraryId.equals(libraryId);
        }
        return expression;
      })
      ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]);
    return query.watch();
  }

  Stream<List<Bookmark>> watchBookmarks({String? itemId, String? libraryId}) {
    final query = select(bookmarks)
      ..where((t) {
        var expression = t.deleted.not();
        if (itemId != null) expression = expression & t.itemId.equals(itemId);
        if (libraryId != null) {
          expression = expression & t.libraryId.equals(libraryId);
        }
        return expression;
      })
      ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]);
    return query.watch();
  }

  Future<void> upsertNote(NotesCompanion data) =>
      into(notes).insertOnConflictUpdate(data);

  Future<void> upsertBookmark(BookmarksCompanion data) =>
      into(bookmarks).insertOnConflictUpdate(data);

  Future<void> deleteNoteSoft(String id) =>
      (update(notes)..where((t) => t.id.equals(id))).write(
        NotesCompanion(
          deleted: const Value(true),
          updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
        ),
      );

  Future<void> deleteBookmarkSoft(String id) =>
      (update(bookmarks)..where((t) => t.id.equals(id))).write(
        BookmarksCompanion(
          deleted: const Value(true),
          updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
        ),
      );

  Future<void> upsertKnownDevice(KnownDevicesCompanion data) =>
      into(knownDevices).insertOnConflictUpdate(data);

  Future<KnownDevice?> getDeviceByTokenHash(String hash) =>
      (select(knownDevices)..where(
            (t) => t.tokenHash.equals(hash) & t.approved & t.revoked.not(),
          ))
          .getSingleOrNull();

  Stream<List<KnownDevice>> watchKnownDevices() => (select(
    knownDevices,
  )..orderBy([(t) => OrderingTerm.desc(t.lastSeenAt)])).watch();

  Future<void> revokeDevice(String id) =>
      (update(knownDevices)..where((t) => t.id.equals(id))).write(
        const KnownDevicesCompanion(revoked: Value(true)),
      );

  Future<void> markDeviceSynced(String id, {String? address}) =>
      (update(knownDevices)..where((t) => t.id.equals(id))).write(
        KnownDevicesCompanion(
          lastSeenAt: Value(DateTime.now().millisecondsSinceEpoch),
          lastSyncAt: Value(DateTime.now().millisecondsSinceEpoch),
          lastAddress: address == null ? const Value.absent() : Value(address),
        ),
      );

  Future<void> setSetting(String key, String value) =>
      into(appSettings).insertOnConflictUpdate(
        AppSettingsCompanion.insert(
          key: key,
          value: value,
          updatedAt: DateTime.now().millisecondsSinceEpoch,
        ),
      );

  Future<String?> getSetting(String key) async => (await (select(
    appSettings,
  )..where((t) => t.key.equals(key))).getSingleOrNull())?.value;

  Future<String> getDeviceId() => transaction(() async {
    final existing = await getSetting('deviceId');
    if (existing != null) return existing;
    final id = const Uuid().v4();
    await setSetting('deviceId', id);
    return id;
  });

  Future<Map<String, Object?>> exportData() => transaction(
    () async => {
      'schemaVersion': schemaVersion,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'libraries': (await select(
        libraries,
      ).get()).map((e) => e.toJson()).toList(),
      'sections': (await select(
        sections,
      ).get()).map((e) => e.toJson()).toList(),
      'items': (await select(items).get()).map((e) => e.toJson()).toList(),
      'playback': (await select(
        playbackProgress,
      ).get()).map((e) => e.toJson()).toList(),
      'reading': (await select(
        readingProgress,
      ).get()).map((e) => e.toJson()).toList(),
      'notes': (await select(notes).get()).map((e) => e.toJson()).toList(),
      'bookmarks': (await select(
        bookmarks,
      ).get()).map((e) => e.toJson()).toList(),
      'sources': await exportMediaRows('library_sources'),
      'itemAssets': (await customSelect(
        'SELECT * FROM item_assets',
      ).get()).map((r) => r.data).toList(),
      'mediaRecords': await exportMediaRows('media_records'),
      'catalogRows': await CatalogIdentityStore(this).exportRows(),
      'settings': (await select(
        appSettings,
      ).get()).map((e) => e.toJson()).toList(),
    },
  );

  Future<Map<String, Object?>> exportSyncData() async {
    final snapshot = await exportData();
    final libraryRows = (snapshot['libraries']! as List<Object?>)
        .whereType<Map<String, dynamic>>()
        .map((row) {
          final safe = Map<String, dynamic>.of(row);
          safe['rootFolderPath'] = '';
          safe['coverPath'] = null;
          return safe;
        })
        .toList();
    final itemRows = (snapshot['items']! as List<Object?>)
        .whereType<Map<String, dynamic>>()
        .map((row) {
          final safe = Map<String, dynamic>.of(row);
          safe['filePath'] = '';
          safe['thumbnailPath'] = null;
          safe['fingerprint'] = null;
          return safe;
        })
        .toList();
    final sectionRows = (snapshot['sections']! as List<Object?>)
        .whereType<Map<String, dynamic>>()
        .map((row) {
          final safe = Map<String, dynamic>.of(row);
          safe['folderPath'] = '';
          return safe;
        })
        .toList();
    final mediaRows = (snapshot['mediaRecords']! as List)
        .cast<Map<String, dynamic>>()
        .map(MediaRecordContract.forTransport)
        .whereType<Map<String, dynamic>>()
        .toList();
    return {
      'schemaVersion':
          3, // Legacy transport adapter; independent of local schema.
      'exportedAt': snapshot['exportedAt'],
      'protocolVersion': 2,
      'capabilities': [
        'catalog-v2',
        'reader-locator-v1',
        'field-overrides-v1',
        'library-grants-v1',
      ],
      'catalogRows': await CatalogIdentityStore(this).transportRows(),
      'libraries': libraryRows,
      'sections': sectionRows,
      'items': itemRows,
      for (final key in ['playback', 'reading', 'notes', 'bookmarks'])
        key: snapshot[key],
      'mediaRecords': mediaRows,
    };
  }

  Future<void> importData(Map<String, Object?> snapshot) async {
    final backupVersion = snapshot['schemaVersion'];
    if (backupVersion is! int ||
        backupVersion < 1 ||
        backupVersion > schemaVersion) {
      throw const FormatException('This is not a valid Tangerine backup.');
    }
    List<Map<String, dynamic>> rows(String key) {
      final value = snapshot[key];
      if (value == null) return const [];
      if (value is! List<Object?> ||
          value.any((row) => row is! Map<String, dynamic>)) {
        throw const FormatException('This backup contains invalid records.');
      }
      return value.cast<Map<String, dynamic>>();
    }

    try {
      await transaction(() async {
        for (final row in rows('libraries')) {
          final remote = Library.fromJson(row);
          final local = await getLibraryById(remote.id);
          final selected = local == null
              ? remote
              : Library.fromJson(
                  SyncConflictResolver.mergeMetadata(
                    local.toJson(),
                    remote.toJson(),
                  ),
                ).copyWith(
                  rootFolderPath: local.rootFolderPath,
                  coverPath: Value(local.coverPath),
                );
          await into(libraries).insertOnConflictUpdate(selected);
        }
        for (final row in rows('sections')) {
          final remote = Section.fromJson(row);
          final local = await (select(
            sections,
          )..where((t) => t.id.equals(remote.id))).getSingleOrNull();
          if (local == null || remote.updatedAt > local.updatedAt) {
            await into(sections).insertOnConflictUpdate(
              local == null
                  ? remote
                  : remote.copyWith(
                      folderPath: local.folderPath,
                      libraryId: local.libraryId,
                    ),
            );
          }
        }
        for (final row in rows('items')) {
          final remote = Item.fromJson(row);
          final local = await getItemById(remote.id);
          if (local == null || remote.updatedAt > local.updatedAt) {
            await into(items).insertOnConflictUpdate(
              local == null
                  ? remote
                  : remote.copyWith(
                      filePath: local.filePath,
                      libraryId: local.libraryId,
                      sectionId: local.sectionId,
                      unavailable: local.unavailable,
                    ),
            );
          }
        }
        for (final row in rows('playback')) {
          final remote = PlaybackProgressData.fromJson(row);
          final local = await getPlaybackByItemId(remote.itemId);
          if (local == null || remote.lastEventAt > local.lastEventAt) {
            await into(playbackProgress).insertOnConflictUpdate(remote);
          }
        }
        for (final row in rows('reading')) {
          final remote = ReadingProgressData.fromJson(row);
          final local = await getReadingByItemId(remote.itemId);
          if (local == null || remote.lastEventAt > local.lastEventAt) {
            await into(readingProgress).insertOnConflictUpdate(remote);
          }
        }
        for (final row in rows('notes')) {
          final remote = Note.fromJson(row);
          final local = await (select(
            notes,
          )..where((t) => t.id.equals(remote.id))).getSingleOrNull();
          final selected = local == null
              ? [remote]
              : SyncConflictResolver.preserveUserContentConflict(
                  local.toJson(),
                  remote.toJson(),
                ).map(Note.fromJson);
          for (final value in selected) {
            await into(notes).insertOnConflictUpdate(value);
          }
        }
        for (final row in rows('bookmarks')) {
          final remote = Bookmark.fromJson(row);
          final local = await (select(
            bookmarks,
          )..where((t) => t.id.equals(remote.id))).getSingleOrNull();
          final selected = local == null
              ? [remote]
              : SyncConflictResolver.preserveUserContentConflict(
                  local.toJson(),
                  remote.toJson(),
                ).map(Bookmark.fromJson);
          for (final value in selected) {
            await into(bookmarks).insertOnConflictUpdate(value);
          }
        }
        await importMediaRows(snapshot, includeSources: true);
        await _backfillSources();
        for (final row in rows('itemAssets')) {
          final itemId = row['item_id'],
              sourceId = row['source_id'],
              relative = row['relative_path'];
          if (itemId is! String || sourceId is! String || relative is! String)
            throw const FormatException('Invalid asset binding');
          final item = await getItemById(itemId);
          if (item != null)
            await LibrarySourceStore(this).bind(item, sourceId, relative);
        }
        await LibrarySourceStore(this).backfill();
        await CatalogIdentityStore(this).importRows(snapshot['catalogRows']);
        await CatalogIdentityStore(this).backfill();
        for (final row in rows('settings')) {
          final remote = AppSetting.fromJson(row);
          if (remote.key == 'deviceId' || remote.key.startsWith('sync.')) {
            continue;
          }
          final local = await (select(
            appSettings,
          )..where((t) => t.key.equals(remote.key))).getSingleOrNull();
          if (local == null || remote.updatedAt > local.updatedAt) {
            await into(appSettings).insertOnConflictUpdate(remote);
          }
        }
        for (final section in await select(sections).get()) {
          await refreshSectionCounts(section.id);
        }
      });
    } on TypeError {
      throw const FormatException(
        'This backup contains incomplete or invalid records.',
      );
    }
  }

  Future<void> deleteLibraryCascade(String libraryId) async {
    await transaction(() async {
      await customStatement(
        'DELETE FROM library_sources WHERE library_id = ?',
        [libraryId],
      );
      await customStatement('DELETE FROM media_records WHERE library_id = ?', [
        libraryId,
      ]);
      final itemRows = await getItemsForLibrary(libraryId);
      final ids = itemRows.map((e) => e.id).toList();
      await (delete(notes)..where((t) => t.libraryId.equals(libraryId))).go();
      if (ids.isNotEmpty) {
        await (delete(notes)..where((t) => t.itemId.isIn(ids))).go();
        await (delete(bookmarks)..where((t) => t.itemId.isIn(ids))).go();
        await (delete(playbackProgress)..where((t) => t.itemId.isIn(ids))).go();
        await (delete(readingProgress)..where((t) => t.itemId.isIn(ids))).go();
      }
      await (delete(items)..where((t) => t.libraryId.equals(libraryId))).go();
      await (delete(
        sections,
      )..where((t) => t.libraryId.equals(libraryId))).go();
      await (delete(libraries)..where((t) => t.id.equals(libraryId))).go();
    });
  }

  Future<void> refreshSectionCounts(String sectionId) async {
    final rows =
        await (select(items).join([
              leftOuterJoin(
                playbackProgress,
                playbackProgress.itemId.equalsExp(items.id),
              ),
              leftOuterJoin(
                readingProgress,
                readingProgress.itemId.equalsExp(items.id),
              ),
            ])..where(
              items.sectionId.equals(sectionId) & items.unavailable.not(),
            ))
            .get();
    final completed = rows.where((row) {
      final playback = row.readTableOrNull(playbackProgress);
      final reading = row.readTableOrNull(readingProgress);
      return playback?.completed ?? reading?.completed ?? false;
    }).length;
    await (update(sections)..where((t) => t.id.equals(sectionId))).write(
      SectionsCompanion(
        itemCount: Value(rows.length),
        completedCount: Value(completed),
      ),
    );
  }

  Future<String?> _sectionIdForItem(String itemId) async =>
      (await getItemById(itemId))?.sectionId;
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    const dataDirectory = String.fromEnvironment('STUDYSTREAM_DATA_DIR');
    final dir = dataDirectory.isEmpty
        ? await getApplicationDocumentsDirectory()
        : await Directory(
            p.isAbsolute(dataDirectory)
                ? dataDirectory
                : p.join(Directory.systemTemp.path, dataDirectory),
          ).create(recursive: true);
    return NativeDatabase.createInBackground(
      File(p.join(dir.path, 'study_stream.sqlite')),
    );
  });
}
