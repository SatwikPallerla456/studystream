import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_stream/data/db/app_database.dart';
import 'package:study_stream/data/indexer/library_indexer.dart';

void main() {
  late Directory root;
  late AppDatabase database;
  late LibraryIndexer indexer;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('study-stream-indexer-');
    database = AppDatabase.forTesting(NativeDatabase.memory());
    indexer = LibraryIndexer(database);
  });

  tearDown(() async {
    await database.close();
    await root.delete(recursive: true);
  });

  test(
    'scans nested sections, skips hidden and unsupported files, and sorts',
    () async {
      final section = await Directory('${root.path}/01 Basics').create();
      final nested = await Directory('${section.path}/02 Deep dive').create();
      await File('${section.path}/10 Advanced.mp4').writeAsBytes([1, 2, 3]);
      await File('${section.path}/2 Setup.mp4').writeAsBytes([4, 5, 6]);
      await File('${section.path}/.hidden.mp4').writeAsBytes([7]);
      await File('${section.path}/ignore.exe').writeAsBytes([8]);
      await File('${nested.path}/1 Notes.pdf').writeAsBytes([9, 10]);

      final result = await indexer.scanRootFolder(
        rootFolderPath: root.path,
        title: 'Course',
      );
      final sections = await database.getSectionsForLibrary(result.libraryId);
      final items = await database.getItemsForLibrary(result.libraryId);

      expect(
        sections.map((value) => value.title),
        containsAll(['01 Basics', '02 Deep dive']),
      );
      expect(items, hasLength(3));
      final basics =
          items.where((item) => item.sectionId == sections.first.id).toList()
            ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
      expect(basics.map((item) => item.filename), [
        '2 Setup.mp4',
        '10 Advanced.mp4',
      ]);
      expect(result.skippedFiles, 2);
    },
  );

  test(
    'rescans without duplicates and preserves identity across rename',
    () async {
      final section = await Directory('${root.path}/Module').create();
      final file = await File(
        '${section.path}/Lesson.mp4',
      ).writeAsBytes([1, 2, 3, 4]);
      final first = await indexer.scanRootFolder(
        rootFolderPath: root.path,
        title: 'Course',
      );
      final original = (await database.getItemsForLibrary(
        first.libraryId,
      )).single;

      await file.rename('${section.path}/Renamed lesson.mp4');
      await indexer.scanRootFolder(rootFolderPath: root.path, title: 'Course');
      final afterRename = await database.getItemsForLibrary(first.libraryId);

      expect(afterRename, hasLength(1));
      expect(afterRename.single.id, original.id);
      expect(afterRename.single.filename, 'Renamed lesson.mp4');
      expect(afterRename.single.unavailable, isFalse);
    },
  );

  test('keeps a missing item visible with its progress identity', () async {
    final section = await Directory('${root.path}/Module').create();
    final file = await File(
      '${section.path}/Lesson.mp4',
    ).writeAsBytes([1, 2, 3]);
    final result = await indexer.scanRootFolder(
      rootFolderPath: root.path,
      title: 'Course',
    );
    final original = (await database.getItemsForLibrary(
      result.libraryId,
    )).single;

    await file.delete();
    await indexer.scanRootFolder(rootFolderPath: root.path, title: 'Course');
    final missing = await database.getItemById(original.id);

    expect(missing, isNotNull);
    expect(missing!.unavailable, isTrue);
  });

  test(
    'detects a replacement at the same path without inheriting identity',
    () async {
      final section = await Directory('${root.path}/Module').create();
      final file = await File(
        '${section.path}/Lesson.mp4',
      ).writeAsBytes([1, 2, 3]);
      final result = await indexer.scanRootFolder(
        rootFolderPath: root.path,
        title: 'Course',
      );
      final original = (await database.getItemsForLibrary(
        result.libraryId,
      )).single;

      await file.writeAsBytes([9, 8, 7, 6], flush: true);
      await indexer.scanRootFolder(rootFolderPath: root.path, title: 'Course');
      await indexer.scanRootFolder(rootFolderPath: root.path, title: 'Course');
      final items = await database.getItemsForLibrary(result.libraryId);
      final available = items.where((item) => !item.unavailable).single;

      expect(items, hasLength(2));
      expect(available.id, isNot(original.id));
      expect((await database.getItemById(original.id))?.unavailable, isTrue);
    },
  );

  test(
    'cancelling before discovery does not create an empty library',
    () async {
      final token = ScanCancellationToken()..cancel();

      await expectLater(
        indexer.scanRootFolder(
          rootFolderPath: root.path,
          title: 'Cancelled',
          cancellationToken: token,
        ),
        throwsA(isA<ScanCancelledException>()),
      );
      expect(await database.watchLibraries().first, isEmpty);
    },
  );
}
