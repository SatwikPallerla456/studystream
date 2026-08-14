import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

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
  });

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
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
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
      await customStatement('PRAGMA foreign_keys = ON');
      await _createIndexes();
    },
  );

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

      for (final sectionId in seenSectionIds) {
        await refreshSectionCounts(sectionId);
      }

      await (update(libraries)..where((t) => t.id.equals(libraryId))).write(
        LibrariesCompanion(
          lastScannedAt: Value(DateTime.now().millisecondsSinceEpoch),
          updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
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
          ..where((t) => t.libraryId.equals(libraryId) & t.unavailable.not())
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

  Stream<List<ContinueEntry>> watchRecentPlaybackEntries({int limit = 8}) {
    final query =
        select(playbackProgress).join([
            innerJoin(items, items.id.equalsExp(playbackProgress.itemId)),
          ])
          ..where(items.unavailable.not() & playbackProgress.completed.not())
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

  Future<List<SearchEntry>> searchItems(String rawQuery) async {
    final queryText = rawQuery.trim().toLowerCase();
    if (queryText.isEmpty) return [];
    final rows = await select(items).join([
      innerJoin(libraries, libraries.id.equalsExp(items.libraryId)),
      innerJoin(sections, sections.id.equalsExp(items.sectionId)),
    ]).get();
    final matches = <SearchEntry>[];
    for (final row in rows) {
      final item = row.readTable(items);
      final library = row.readTable(libraries);
      final section = row.readTable(sections);
      final haystack = [
        item.title,
        item.userTitle ?? '',
        item.filename,
        library.title,
        section.title,
      ].join(' ').toLowerCase();
      if (!haystack.contains(queryText)) continue;
      final progress = await getMergedProgressForItem(item.id);
      matches.add(
        SearchEntry(
          item: item,
          libraryTitle: library.title,
          sectionTitle: section.title,
          progressPercent: progress.$1,
          completed: progress.$2,
        ),
      );
    }
    return matches;
  }

  Future<List<GlobalSearchEntry>> searchAll(String rawQuery) async {
    final queryText = rawQuery.trim().toLowerCase();
    if (queryText.isEmpty) return [];
    final itemRows = await select(items).join([
      innerJoin(libraries, libraries.id.equalsExp(items.libraryId)),
      innerJoin(sections, sections.id.equalsExp(items.sectionId)),
    ]).get();
    final playbackByItem = {
      for (final value in await select(playbackProgress).get())
        value.itemId: value,
    };
    final readingByItem = {
      for (final value in await select(readingProgress).get())
        value.itemId: value,
    };
    (double, bool) progressFor(String itemId) {
      final playback = playbackByItem[itemId];
      if (playback != null) {
        return (playback.percentWatched, playback.completed);
      }
      final reading = readingByItem[itemId];
      return (reading?.percentRead ?? 0, reading?.completed ?? false);
    }

    final contexts = <String, (Item, Library, Section)>{};
    final results = <GlobalSearchEntry>[];
    for (final row in itemRows) {
      final item = row.readTable(items);
      final library = row.readTable(libraries);
      final section = row.readTable(sections);
      contexts[item.id] = (item, library, section);
      final haystack = [
        item.title,
        item.userTitle ?? '',
        item.filename,
        library.title,
        section.title,
      ].join(' ').toLowerCase();
      if (!haystack.contains(queryText)) continue;
      final progress = progressFor(item.id);
      results.add(
        GlobalSearchEntry(
          kind: 'lesson',
          title: item.userTitle ?? item.title,
          libraryTitle: library.title,
          sectionTitle: section.title,
          item: item,
          progressPercent: progress.$1,
          completed: progress.$2,
          updatedAt: item.updatedAt,
        ),
      );
    }

    final noteRows = await (select(
      notes,
    )..where((table) => table.deleted.not())).get();
    for (final note in noteRows) {
      final context = note.itemId == null ? null : contexts[note.itemId];
      final library = context?.$2 ?? await getLibraryById(note.libraryId);
      final haystack = [
        note.content,
        context?.$1.userTitle ?? context?.$1.title ?? '',
        context?.$3.title ?? '',
        library?.title ?? '',
      ].join(' ').toLowerCase();
      if (!haystack.contains(queryText)) continue;
      final progress = context == null
          ? (0.0, false)
          : progressFor(context.$1.id);
      results.add(
        GlobalSearchEntry(
          kind: 'note',
          title: note.content,
          libraryTitle: library?.title ?? 'Library',
          sectionTitle: context?.$3.title ?? 'General note',
          item: context?.$1,
          progressPercent: progress.$1,
          completed: progress.$2,
          updatedAt: note.updatedAt,
          positionSeconds: note.positionSeconds,
          pageNumber: note.pageNumber,
        ),
      );
    }

    final bookmarkRows = await (select(
      bookmarks,
    )..where((table) => table.deleted.not())).get();
    for (final bookmark in bookmarkRows) {
      final context = contexts[bookmark.itemId];
      final haystack = [
        bookmark.title,
        bookmark.description ?? '',
        context?.$1.userTitle ?? context?.$1.title ?? '',
        context?.$3.title ?? '',
        context?.$2.title ?? '',
      ].join(' ').toLowerCase();
      if (!haystack.contains(queryText)) continue;
      final progress = context == null
          ? (0.0, false)
          : progressFor(context.$1.id);
      results.add(
        GlobalSearchEntry(
          kind: 'bookmark',
          title: bookmark.title,
          libraryTitle: context?.$2.title ?? 'Library',
          sectionTitle: context?.$3.title ?? 'Bookmark',
          item: context?.$1,
          progressPercent: progress.$1,
          completed: progress.$2,
          updatedAt: bookmark.updatedAt,
          positionSeconds: bookmark.positionSeconds,
          pageNumber: bookmark.pageNumber,
        ),
      );
    }
    results.sort((a, b) {
      final kind = a.kind.compareTo(b.kind);
      if (kind != 0) return kind;
      return b.updatedAt.compareTo(a.updatedAt);
    });
    return results;
  }

  Future<void> setItemCompletion({
    required Item item,
    required bool completed,
    String deviceId = 'local',
  }) async {
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

  Future<Map<String, Object?>> exportData() async => {
    'schemaVersion': schemaVersion,
    'exportedAt': DateTime.now().toUtc().toIso8601String(),
    'libraries': (await select(
      libraries,
    ).get()).map((e) => e.toJson()).toList(),
    'sections': (await select(sections).get()).map((e) => e.toJson()).toList(),
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
    'settings': (await select(
      appSettings,
    ).get()).map((e) => e.toJson()).toList(),
  };

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
    return {
      ...snapshot,
      'protocolVersion': 1,
      'libraries': libraryRows,
      'sections': sectionRows,
      'items': itemRows,
    }..remove('settings');
  }

  Future<void> importData(Map<String, Object?> snapshot) async {
    final backupVersion = snapshot['schemaVersion'];
    if (backupVersion is! int ||
        backupVersion < 1 ||
        backupVersion > schemaVersion) {
      throw const FormatException('This is not a valid StudyStream backup.');
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

    await transaction(() async {
      for (final row in rows('libraries')) {
        await into(libraries).insertOnConflictUpdate(Library.fromJson(row));
      }
      for (final row in rows('sections')) {
        await into(sections).insertOnConflictUpdate(Section.fromJson(row));
      }
      for (final row in rows('items')) {
        await into(items).insertOnConflictUpdate(Item.fromJson(row));
      }
      for (final row in rows('playback')) {
        await into(
          playbackProgress,
        ).insertOnConflictUpdate(PlaybackProgressData.fromJson(row));
      }
      for (final row in rows('reading')) {
        await into(
          readingProgress,
        ).insertOnConflictUpdate(ReadingProgressData.fromJson(row));
      }
      for (final row in rows('notes')) {
        await into(notes).insertOnConflictUpdate(Note.fromJson(row));
      }
      for (final row in rows('bookmarks')) {
        await into(bookmarks).insertOnConflictUpdate(Bookmark.fromJson(row));
      }
      for (final row in rows('settings')) {
        await into(
          appSettings,
        ).insertOnConflictUpdate(AppSetting.fromJson(row));
      }
    });
  }

  Future<void> deleteLibraryCascade(String libraryId) async {
    await transaction(() async {
      final itemRows = await getItemsForLibrary(libraryId);
      final ids = itemRows.map((e) => e.id).toList();
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
    final dir = await getApplicationDocumentsDirectory();
    return NativeDatabase.createInBackground(
      File(p.join(dir.path, 'study_stream.sqlite')),
    );
  });
}
