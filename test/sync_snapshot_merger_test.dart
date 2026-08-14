import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_stream/data/db/app_database.dart';
import 'package:study_stream/data/sync/sync_snapshot_merger.dart';

void main() {
  test('remote metadata cannot replace local library or item paths', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    await _seed(database);
    final snapshot = await database.exportData();
    final library =
        Map<String, dynamic>.of(
            (snapshot['libraries']! as List).single as Map<String, dynamic>,
          )
          ..['rootFolderPath'] = '/outside'
          ..['title'] = 'Remote title'
          ..['updatedAt'] = 50
          ..['version'] = 2;
    final item =
        Map<String, dynamic>.of(
            (snapshot['items']! as List).single as Map<String, dynamic>,
          )
          ..['filePath'] = '/outside/file.mp4'
          ..['relativePath'] = '../file.mp4'
          ..['userTitle'] = 'Remote lesson title'
          ..['updatedAt'] = 50
          ..['version'] = 2;

    await SyncSnapshotMerger(database).merge({
      ...snapshot,
      'libraries': [library],
      'items': [item],
    });

    final mergedLibrary = await database.getLibraryById('library');
    final mergedItem = await database.getItemById('item');
    expect(mergedLibrary?.rootFolderPath, '/approved');
    expect(mergedLibrary?.title, 'Remote title');
    expect(mergedItem?.filePath, '/approved/file.mp4');
    expect(mergedItem?.relativePath, 'file.mp4');
    expect(mergedItem?.userTitle, 'Remote lesson title');
  });

  test('ignores progress for unknown items', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    await _seed(database);
    final snapshot = await database.exportData();
    final progress = {
      'itemId': 'unknown',
      'lastPositionSeconds': 50.0,
      'resumePositionSeconds': 40.0,
      'durationSeconds': 100.0,
      'percentWatched': 50.0,
      'completed': false,
      'manualCompletion': null,
      'playbackSpeed': 1.0,
      'lastOpenedAt': 1,
      'lastEventAt': 1,
      'deviceId': 'remote',
      'version': 1,
    };

    await SyncSnapshotMerger(database).merge({
      ...snapshot,
      'playback': [progress],
    });

    expect(await database.getPlaybackByItemId('unknown'), isNull);
  });
}

Future<void> _seed(AppDatabase database) async {
  await database.upsertLibrary(
    LibrariesCompanion.insert(
      id: 'library',
      title: 'Course',
      rootFolderPath: '/approved',
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
      folderPath: '/approved',
    ),
  );
  await database.upsertItem(
    ItemsCompanion.insert(
      id: 'item',
      libraryId: 'library',
      sectionId: 'section',
      title: 'Lesson',
      filename: 'file.mp4',
      filePath: '/approved/file.mp4',
      relativePath: 'file.mp4',
      itemType: 'video',
      orderIndex: 0,
    ),
  );
}
