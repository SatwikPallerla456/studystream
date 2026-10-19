import 'dart:io';

import 'package:drift/native.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_stream/data/db/app_database.dart';
import 'package:study_stream/data/indexer/library_indexer.dart';
import 'package:study_stream/domain/services/media_import_service.dart';

void main() {
  late Directory root;
  late Directory managed;
  late AppDatabase database;
  late MediaImportService service;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('myvlc-import-');
    managed = Directory('${root.path}/managed');
    database = AppDatabase.forTesting(NativeDatabase.memory());
    service = MediaImportService(LibraryIndexer(database), directory: managed);
  });
  tearDown(() async {
    await database.close();
    await root.delete(recursive: true);
  });

  test('concurrent imports do not replace files with the same name', () async {
    await Future.wait([
      service.importFiles([
        PlatformFile(
          name: 'Same.mp3',
          size: 2,
          readStream: Stream.value([1, 2]),
        ),
      ]),
      service.importFiles([
        PlatformFile(
          name: 'Same.mp3',
          size: 3,
          readStream: Stream.value([3, 4, 5]),
        ),
      ]),
    ]);
    expect(await File('${managed.path}/Same.mp3').readAsBytes(), [1, 2]);
    expect(await File('${managed.path}/Same (2).mp3').readAsBytes(), [3, 4, 5]);
    expect((await database.watchLibraries().first), hasLength(1));
  });

  test(
    'picker cache files become durable media without changing originals',
    () async {
      final source = await File(
        '${root.path}/source.wav',
      ).writeAsBytes([1, 2, 3, 4]);
      final result = await service.importFiles([
        PlatformFile(name: 'Lesson.wav', size: 4, path: source.path),
      ]);
      final item = (await database.getItemsForLibrary(result.libraryId)).single;
      expect(item.filePath, '${managed.path}/Lesson.wav');
      expect(await File(item.filePath).readAsBytes(), [1, 2, 3, 4]);
      await source.delete();
      expect(await File(item.filePath).exists(), isTrue);
    },
  );

  test(
    'same-name imports retain both files and earlier progress identities',
    () async {
      final result = await service.importFiles([
        PlatformFile(
          name: 'Lesson.mp3',
          size: 2,
          readStream: Stream.value([1, 2]),
        ),
      ]);
      final original = (await database.getItemsForLibrary(
        result.libraryId,
      )).single;
      await database.setItemCompletion(item: original, completed: true);
      await service.importFiles([
        PlatformFile(
          name: 'Lesson.mp3',
          size: 3,
          readStream: Stream.value([3, 4, 5]),
        ),
      ]);
      final items = await database.getItemsForLibrary(result.libraryId);
      expect(items, hasLength(2));
      expect(
        items.map((item) => item.filename),
        containsAll(['Lesson.mp3', 'Lesson (2).mp3']),
      );
      expect(
        (await database.getPlaybackByItemId(original.id))!.completed,
        isTrue,
      );
    },
  );

  test(
    'incomplete copies leave no playable partial file or database entry',
    () async {
      await expectLater(
        service.importFiles([
          PlatformFile(
            name: 'Broken.mp4',
            size: 10,
            readStream: Stream.value([1, 2]),
          ),
        ]),
        throwsA(isA<FileSystemException>()),
      );
      expect(await managed.list().toList(), isEmpty);
      expect(await database.watchLibraries().first, isEmpty);
    },
  );
}
