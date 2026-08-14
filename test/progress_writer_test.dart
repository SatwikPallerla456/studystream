import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_stream/data/db/app_database.dart';
import 'package:study_stream/domain/services/progress_writer.dart';

void main() {
  late AppDatabase database;
  late Item media;
  late Item document;

  setUp(() async {
    database = AppDatabase.forTesting(NativeDatabase.memory());
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
    for (final value in const [('media', 'video'), ('document', 'pdf')]) {
      await database.upsertItem(
        ItemsCompanion.insert(
          id: value.$1,
          libraryId: 'library',
          sectionId: 'section',
          title: value.$1,
          filename: '${value.$1}.${value.$2 == 'video' ? 'mp4' : 'pdf'}',
          filePath: '/course/module/${value.$1}',
          relativePath: 'module/${value.$1}',
          itemType: value.$2,
          orderIndex: value.$1 == 'media' ? 0 : 1,
        ),
      );
    }
    media = (await database.getItemById('media'))!;
    document = (await database.getItemById('document'))!;
  });

  tearDown(() => database.close());

  test('manual incomplete survives automatic media completion', () async {
    await database.setItemCompletion(item: media, completed: false);
    final writer = MediaProgressWriter(database: database, item: media)
      ..seed(
        position: const Duration(seconds: 99),
        duration: const Duration(seconds: 100),
        speed: 1,
      );

    await writer.flush(forceComplete: true);
    final progress = await database.getPlaybackByItemId(media.id);
    expect(progress?.manualCompletion, isFalse);
    expect(progress?.completed, isFalse);
    expect(progress?.percentWatched, 99);
  });

  test('manual complete stays complete as playback position changes', () async {
    await database.setItemCompletion(item: media, completed: true);
    final writer = MediaProgressWriter(database: database, item: media)
      ..seed(
        position: const Duration(seconds: 20),
        duration: const Duration(seconds: 100),
        speed: 1.25,
      );

    await writer.flush();
    final progress = await database.getPlaybackByItemId(media.id);
    expect(progress?.manualCompletion, isTrue);
    expect(progress?.completed, isTrue);
    expect(progress?.percentWatched, 100);
    expect(progress?.playbackSpeed, 1.25);
  });

  test('manual incomplete survives reaching the end of a document', () async {
    await database.setItemCompletion(item: document, completed: false);
    final writer = ReadingProgressWriter(database: database, item: document)
      ..currentPage = 10
      ..totalPages = 10
      ..pagesVisited = 5;

    await writer.save(forceComplete: true);
    final progress = await database.getReadingByItemId(document.id);
    expect(progress?.manualCompletion, isFalse);
    expect(progress?.completed, isFalse);
    expect(progress?.percentRead, 100);
  });
}
