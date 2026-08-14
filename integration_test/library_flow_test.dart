import 'dart:io';

import 'package:drift/native.dart';
import 'package:integration_test/integration_test.dart';
import 'package:study_stream/data/db/app_database.dart';
import 'package:study_stream/data/indexer/library_indexer.dart';
import 'package:study_stream/domain/services/resume_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('imports nested lessons and restores persisted progress', (
    tester,
  ) async {
    final root = await Directory.systemTemp.createTemp(
      'study-stream-integration-',
    );
    final module = await Directory('${root.path}/01 Module').create();
    await File('${module.path}/01 Lesson.mp4').writeAsBytes([1, 2, 3]);
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(() async {
      await database.close();
      await root.delete(recursive: true);
    });

    final result = await LibraryIndexer(
      database,
    ).scanRootFolder(rootFolderPath: root.path, title: 'Integration course');
    final item = (await database.getItemsForLibrary(result.libraryId)).single;
    await database.setItemCompletion(item: item, completed: true);
    final backup = await database.exportData();
    await database.close();

    final restored = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(restored.close);
    await restored.importData(backup);

    expect((await restored.getPlaybackByItemId(item.id))?.completed, isTrue);
    expect(ResumeService.mediaResumeSeconds(50, durationSeconds: 100), 40);
  });
}
