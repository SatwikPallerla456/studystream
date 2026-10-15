import 'dart:io';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_stream/data/db/app_database.dart';
import 'package:study_stream/data/indexer/library_indexer.dart';
import 'package:study_stream/domain/services/progress_writer.dart';
import 'package:study_stream/domain/services/sync_conflict_resolver.dart';

void main() {
  late Directory root;
  late AppDatabase db;
  late LibraryIndexer indexer;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('studystream-regression-');
    db = AppDatabase.forTesting(NativeDatabase.memory());
    indexer = LibraryIndexer(db);
  });
  tearDown(() async {
    await db.close();
    await root.delete(recursive: true);
  });
  Future<String> scan() async => (await indexer.scanRootFolder(
    rootFolderPath: root.path,
    title: 'Course',
  )).libraryId;
  Future<Item> lesson() async {
    await File('${root.path}/lesson.wav').writeAsBytes([1, 2, 3]);
    return (await db.getItemsForLibrary(await scan())).single;
  }

  test(
    'relinking a moved root preserves the library and lesson identity',
    () async {
      final item = await lesson();
      await db.setItemCompletion(item: item, completed: true);
      root = await root.rename('${root.path}-moved');
      final result = await indexer.scanRootFolder(
        rootFolderPath: root.path,
        title: 'Course',
        existingLibraryId: item.libraryId,
      );
      expect(result.libraryId, item.libraryId);
      final relinked = (await db.getItemsForLibrary(item.libraryId)).single;
      expect(relinked.id, item.id);
      expect(relinked.filePath, startsWith(root.path));
      expect((await db.getPlaybackByItemId(item.id))!.completed, isTrue);
    },
  );

  test(
    'missing sections stay navigable so their lessons can be relinked',
    () async {
      final folder = await Directory('${root.path}/Module').create();
      final file = await File(
        '${folder.path}/lesson.txt',
      ).writeAsString('content');
      final library = await scan();
      await file.delete();
      await scan();
      expect(
        await db.watchSectionProgressForLibrary(library).first,
        hasLength(1),
      );
      expect((await db.getItemsForLibrary(library)).single.unavailable, isTrue);
    },
  );

  test('nested-only folders retain their parent section', () async {
    final nested = await Directory(
      '${root.path}/Parent/Child',
    ).create(recursive: true);
    await File('${nested.path}/lesson.txt').writeAsString('content');
    final sections = await db.getSectionsForLibrary(await scan());
    final child = sections.singleWhere((s) => s.title == 'Child');
    expect(
      child.parentSectionId,
      sections.singleWhere((s) => s.title == 'Parent').id,
    );
  });

  test('new identical copy cannot steal an existing file identity', () async {
    final file = await File(
      '${root.path}/2 Original.wav',
    ).writeAsBytes([1, 2, 3]);
    final id = await scan();
    final original = (await db.getItemsForLibrary(id)).single;
    await file.copy('${root.path}/1 Copy.wav');
    await scan();
    final rows = await db.getItemsForLibrary(id);
    expect(rows, hasLength(2));
    expect(
      rows.singleWhere((i) => i.filename == '2 Original.wav').id,
      original.id,
    );
    expect(rows.map((i) => i.id).toSet(), hasLength(2));
  });

  test(
    'equal sampled edges cannot transfer identity to different contents',
    () async {
      final first = List<int>.filled(200000, 1)..[100000] = 2;
      final file = await File('${root.path}/lesson.wav').writeAsBytes(first);
      final id = await scan();
      final original = (await db.getItemsForLibrary(id)).single;
      first[100000] = 3;
      await file.writeAsBytes(first);
      await scan();
      expect((await db.getItemById(original.id))!.unavailable, isTrue);
      expect(
        (await db.getItemsForLibrary(
          id,
        )).where((i) => !i.unavailable).single.id,
        isNot(original.id),
      );
    },
  );

  test('mid-scan cancellation commits no partial library', () async {
    await File('${root.path}/lesson.txt').writeAsString('content');
    final token = ScanCancellationToken();
    await expectLater(
      indexer.scanRootFolder(
        rootFolderPath: root.path,
        title: 'Cancelled',
        cancellationToken: token,
        onProgress: (p) {
          if (p.processedFiles > 0) token.cancel();
        },
      ),
      throwsA(isA<ScanCancelledException>()),
    );
    expect(await db.watchLibraries().first, isEmpty);
  });

  test('library removal also removes general library notes', () async {
    final item = await lesson();
    await db.upsertNote(
      NotesCompanion.insert(
        id: 'general',
        libraryId: item.libraryId,
        content: 'General note',
        createdAt: 1,
        updatedAt: 1,
        deviceId: 'test',
      ),
    );
    await db.deleteLibraryCascade(item.libraryId);
    expect(await db.watchLibraries().first, isEmpty);
    expect(await db.watchNotes().first, isEmpty);
    expect(await File(item.filePath).exists(), isTrue);
  });

  test(
    'automatic completion stays complete when a lesson is replayed',
    () async {
      final item = await lesson();
      final first = MediaProgressWriter(database: db, item: item)
        ..seed(
          position: const Duration(seconds: 99),
          duration: const Duration(seconds: 100),
          speed: 1,
        );
      await first.dispose();
      final replay = MediaProgressWriter(database: db, item: item)
        ..seed(
          position: Duration.zero,
          duration: const Duration(seconds: 100),
          speed: 1,
        );
      await replay.dispose();
      expect((await db.getPlaybackByItemId(item.id))!.completed, isTrue);
    },
  );

  test(
    'concurrent flushes persist the latest immutable snapshot once',
    () async {
      final item = await lesson();
      final writer = MediaProgressWriter(database: db, item: item)
        ..seed(
          position: const Duration(seconds: 20),
          duration: const Duration(seconds: 100),
          speed: 1,
        );
      final first = writer.flush();
      writer.seed(
        position: const Duration(seconds: 40),
        duration: const Duration(seconds: 100),
        speed: 1.5,
      );
      await Future.wait([first, writer.flush(), writer.flush()]);
      final progress = (await db.getPlaybackByItemId(item.id))!;
      expect(progress.lastPositionSeconds, 40);
      expect(progress.playbackSpeed, 1.5);
      expect(progress.version, 2);
      await writer.dispose();
      expect((await db.getPlaybackByItemId(item.id))!.version, 2);
    },
  );

  test(
    'restore keeps newer local progress and preserves conflicting note content',
    () async {
      final item = await lesson();
      await db.setItemCompletion(item: item, completed: true);
      await db.upsertNote(
        NotesCompanion.insert(
          id: 'note',
          libraryId: item.libraryId,
          itemId: Value(item.id),
          content: 'Old backup note',
          createdAt: 1,
          updatedAt: 1,
          deviceId: 'backup',
        ),
      );
      final backup = await db.exportData();
      await db.setItemCompletion(item: item, completed: false);
      await db.upsertNote(
        NotesCompanion.insert(
          id: 'note',
          libraryId: item.libraryId,
          itemId: Value(item.id),
          content: 'New local note',
          createdAt: 1,
          updatedAt: 9,
          deviceId: 'local-device',
          version: const Value(2),
        ),
      );
      await db.importData(backup);
      expect(
        (await db.getPlaybackByItemId(item.id))!.manualCompletion,
        isFalse,
      );
      expect(
        (await db.watchNotes().first).map((n) => n.content),
        containsAll(['Old backup note', 'New local note']),
      );
      await db.importData(backup);
      expect(await db.watchNotes().first, hasLength(2));
    },
  );

  test('invalid restore rolls back preceding valid rows', () async {
    final item = await lesson();
    final backup = await db.exportData();
    final libraries = backup['libraries'] as List;
    (libraries.single as Map<String, dynamic>)['title'] = 'Should roll back';
    backup['notes'] = [
      {'id': 'broken'},
    ];
    await expectLater(db.importData(backup), throwsFormatException);
    expect((await db.getLibraryById(item.libraryId))!.title, 'Course');
  });

  test(
    'search is bounded and includes general notes and empty section titles',
    () async {
      final item = await lesson();
      await db.upsertNote(
        NotesCompanion.insert(
          id: 'general',
          libraryId: item.libraryId,
          content: 'General searchable thought',
          createdAt: 1,
          updatedAt: 1,
          deviceId: 'test',
        ),
      );
      final results = await db.searchAll('searchable');
      expect(results.single.libraryId, item.libraryId);
      expect(results.single.item, isNull);
      expect(await db.searchAll('Course', limit: 1), hasLength(1));
    },
  );

  test('equal timestamp conflicts converge regardless of merge direction', () {
    final first = {
      'id': 'same',
      'content': 'A',
      'updatedAt': 1,
      'version': 1,
      'deviceId': 'same',
    };
    final second = {...first, 'content': 'B'};
    final left = SyncConflictResolver.preserveUserContentConflict(
      first,
      second,
    );
    final right = SyncConflictResolver.preserveUserContentConflict(
      second,
      first,
    );
    expect(left, right);
    expect(
      SyncConflictResolver.mergeMetadata(first, second),
      SyncConflictResolver.mergeMetadata(second, first),
    );
  });
}
