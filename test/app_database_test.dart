import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:study_stream/data/db/app_database.dart';

void main() {
  test(
    'stores progress, manual completion, notes, bookmarks, and backup data',
    () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      await _seed(database);
      final item = (await database.getItemsForLibrary('library')).single;

      await database.setItemCompletion(item: item, completed: true);
      expect(
        (await database.getPlaybackByItemId(item.id))!.manualCompletion,
        isTrue,
      );

      final now = DateTime.now().millisecondsSinceEpoch;
      await database.upsertNote(
        NotesCompanion.insert(
          id: 'note',
          libraryId: 'library',
          itemId: const Value('item'),
          content: 'Remember this',
          createdAt: now,
          updatedAt: now,
          deviceId: 'test',
        ),
      );
      await database.upsertBookmark(
        BookmarksCompanion.insert(
          id: 'bookmark',
          libraryId: 'library',
          itemId: 'item',
          title: 'Important',
          positionSeconds: const Value(42),
          createdAt: now,
          updatedAt: now,
          deviceId: 'test',
        ),
      );
      expect(await database.watchNotes(itemId: 'item').first, hasLength(1));
      expect(await database.watchBookmarks(itemId: 'item').first, hasLength(1));

      final noteResults = await database.searchAll('remember');
      expect(noteResults.single.kind, 'note');
      expect(noteResults.single.item?.id, 'item');
      final bookmarkResults = await database.searchAll('important');
      expect(bookmarkResults.single.kind, 'bookmark');

      final backup = await database.exportData();
      await database.close();
      final restored = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(restored.close);
      await restored.importData(backup);
      expect((await restored.getLibraryById('library'))?.title, 'Course');
      expect(await restored.watchNotes(itemId: 'item').first, hasLength(1));
      expect((await restored.getPlaybackByItemId('item'))?.completed, isTrue);
    },
  );

  test('migrates schema v1 without deleting existing libraries', () async {
    final sqlite = sqlite3.openInMemory();
    sqlite.execute('''
      CREATE TABLE libraries (id TEXT NOT NULL PRIMARY KEY, title TEXT NOT NULL, root_folder_path TEXT NOT NULL, created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL);
      CREATE TABLE sections (id TEXT NOT NULL PRIMARY KEY, library_id TEXT NOT NULL REFERENCES libraries(id), title TEXT NOT NULL, order_index INTEGER NOT NULL, folder_path TEXT NOT NULL, item_count INTEGER NOT NULL DEFAULT 0, completed_count INTEGER NOT NULL DEFAULT 0);
      CREATE TABLE items (id TEXT NOT NULL PRIMARY KEY, library_id TEXT NOT NULL REFERENCES libraries(id), section_id TEXT NOT NULL REFERENCES sections(id), title TEXT NOT NULL, filename TEXT NOT NULL, file_path TEXT NOT NULL, relative_path TEXT NOT NULL, item_type TEXT NOT NULL, order_index INTEGER NOT NULL, duration_seconds REAL, page_count INTEGER, thumbnail_path TEXT, modified_at INTEGER, unavailable INTEGER NOT NULL DEFAULT 0 CHECK (unavailable IN (0, 1)));
      CREATE TABLE playback_progress (item_id TEXT NOT NULL PRIMARY KEY REFERENCES items(id), last_position_seconds REAL NOT NULL DEFAULT 0, resume_position_seconds REAL NOT NULL DEFAULT 0, percent_watched REAL NOT NULL DEFAULT 0, completed INTEGER NOT NULL DEFAULT 0 CHECK (completed IN (0, 1)), last_opened_at INTEGER NOT NULL DEFAULT 0, last_event_at INTEGER NOT NULL DEFAULT 0, device_id TEXT NOT NULL);
      CREATE TABLE reading_progress (item_id TEXT NOT NULL PRIMARY KEY REFERENCES items(id), last_page INTEGER NOT NULL DEFAULT 1, last_scroll_offset REAL NOT NULL DEFAULT 0, resume_page INTEGER NOT NULL DEFAULT 1, resume_scroll_offset REAL NOT NULL DEFAULT 0, percent_read REAL NOT NULL DEFAULT 0, completed INTEGER NOT NULL DEFAULT 0 CHECK (completed IN (0, 1)), last_opened_at INTEGER NOT NULL DEFAULT 0, last_event_at INTEGER NOT NULL DEFAULT 0, device_id TEXT NOT NULL);
      INSERT INTO libraries VALUES ('old', 'Existing course', '/course', 1, 1);
      PRAGMA user_version = 1;
    ''');
    final database = AppDatabase.forTesting(NativeDatabase.opened(sqlite));
    addTearDown(database.close);

    final library = await database.getLibraryById('old');
    expect(library?.title, 'Existing course');
    expect(library?.description, '');
    expect(database.schemaVersion, 2);
  });

  test('rejects malformed and future backup data', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);

    await expectLater(
      database.importData({'schemaVersion': database.schemaVersion + 1}),
      throwsFormatException,
    );
    await expectLater(
      database.importData({
        'schemaVersion': database.schemaVersion,
        'libraries': ['not a record'],
      }),
      throwsFormatException,
    );
  });
}

Future<void> _seed(AppDatabase database) async {
  await database.upsertLibrary(
    LibrariesCompanion.insert(
      id: 'library',
      title: 'Course',
      rootFolderPath: '/course',
      createdAt: 1,
      updatedAt: 1,
    ),
  );
  await database.upsertSection(
    SectionsCompanion.insert(
      id: 'section',
      libraryId: 'library',
      title: 'Module',
      orderIndex: 0,
      folderPath: '/course/module',
    ),
  );
  await database.upsertItem(
    ItemsCompanion.insert(
      id: 'item',
      libraryId: 'library',
      sectionId: 'section',
      title: 'Lesson',
      filename: 'lesson.mp4',
      filePath: '/course/module/lesson.mp4',
      relativePath: 'module/lesson.mp4',
      itemType: 'video',
      orderIndex: 0,
    ),
  );
}
