import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_stream/core/theme/app_theme.dart';
import 'package:study_stream/data/db/app_database.dart';
import 'package:study_stream/shared/widgets/lesson_tools_sheet.dart';

void main() {
  testWidgets(
    'saving nested note and bookmark editors survives the closing animation',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      await tester.runAsync(() async {
        await db.upsertLibrary(
          LibrariesCompanion.insert(
            id: 'l',
            title: 'Course',
            rootFolderPath: '/fixture',
            createdAt: 1,
            updatedAt: 1,
          ),
        );
        await db.upsertSection(
          SectionsCompanion.insert(
            id: 's',
            libraryId: 'l',
            title: 'Module',
            orderIndex: 0,
            folderPath: '/fixture',
          ),
        );
        await db.upsertItem(
          ItemsCompanion.insert(
            id: 'i',
            libraryId: 'l',
            sectionId: 's',
            title: 'Lesson',
            filename: 'lesson.wav',
            filePath: '/fixture/lesson.wav',
            relativePath: 'lesson.wav',
            itemType: 'audio',
            orderIndex: 0,
          ),
        );
      });
      final item = (await tester.runAsync(() => db.getItemById('i')))!;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: LessonToolsSheet(
              database: db,
              item: item,
              currentPositionSeconds: 12,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add note'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextField),
        'A note at twelve seconds',
      );
      await tester.pump();
      await tester.tap(find.text('Save note'));
      await tester.pump(const Duration(milliseconds: 16));
      expect(tester.takeException(), isNull);
      await tester.pumpAndSettle();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 40)),
      );
      await tester.pumpAndSettle();
      expect(
        (await tester.runAsync(
          () => db.watchNotes().first,
        ))!.single.positionSeconds,
        12,
      );
      expect(find.text('A note at twelve seconds'), findsOneWidget);
      await tester.tap(find.text('Bookmarks'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Add bookmark'));
      await tester.tap(find.text('Add bookmark'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save bookmark'));
      await tester.pump(const Duration(milliseconds: 16));
      expect(tester.takeException(), isNull);
      await tester.pumpAndSettle();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 40)),
      );
      await tester.pumpAndSettle();
      expect(
        await tester.runAsync(() => db.watchBookmarks().first),
        hasLength(1),
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}
