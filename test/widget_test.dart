import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_stream/app.dart';
import 'package:study_stream/core/theme/app_theme.dart';
import 'package:study_stream/data/db/app_database.dart';
import 'package:study_stream/data/providers/app_providers.dart';
import 'package:study_stream/features/home/home_screen.dart';
import 'package:study_stream/features/library/library_screen.dart';
import 'package:study_stream/features/player/media_player_screen.dart';
import 'package:study_stream/features/reader/pdf_reader_screen.dart';
import 'package:study_stream/features/search/search_screen.dart';
import 'package:study_stream/features/settings/settings_screen.dart';
import 'package:study_stream/features/study/study_screen.dart';

void main() {
  testWidgets('main app router presents the redesigned empty Home state', (
    tester,
  ) async {
    final database = _database();
    addTearDown(database.close);

    await _pumpApp(
      tester,
      database: database,
      home: const StudyMediaPlayerApp(),
      size: const Size(1280, 900),
      wrapsMaterialApp: false,
    );

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Build your first learning library'), findsOneWidget);
    expect(find.text('Choose your first folder'), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.text('Libraries'), findsOneWidget);
    await _disposeTree(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shell adapts between mobile bottom navigation and tablet rail', (
    tester,
  ) async {
    final database = _database();
    addTearDown(database.close);

    await _pumpApp(
      tester,
      database: database,
      home: const HomeScreen(),
      size: const Size(390, 844),
    );
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
    expect(find.text('Libraries'), findsOneWidget);

    await _disposeTree(tester);
    await _pumpApp(
      tester,
      database: database,
      home: const HomeScreen(),
      size: const Size(768, 900),
    );
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    await _disposeTree(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Home and Libraries show populated continue, grid, and list UI', (
    tester,
  ) async {
    final database = _database();
    addTearDown(database.close);
    await tester.runAsync(() => _seed(database));

    await _pumpApp(
      tester,
      database: database,
      home: const HomeScreen(),
      size: const Size(1280, 900),
    );

    expect(find.text('Continue learning').hitTestable(), findsOneWidget);
    expect(find.text('Welcome to Dart'), findsWidgets);
    expect(find.text('Demo Course'), findsWidgets);

    await tester.tap(find.text('Libraries').hitTestable().first);
    await _settleUi(tester);
    expect(find.byType(TextField).hitTestable(), findsOneWidget);
    expect(find.byTooltip('Grid view').hitTestable(), findsOneWidget);
    await tester.tap(find.byTooltip('List view').hitTestable());
    await _settleUi(tester);
    expect(find.text('Demo Course').hitTestable(), findsOneWidget);
    await _disposeTree(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('library detail switches sections and renders lesson states', (
    tester,
  ) async {
    final database = _database();
    addTearDown(database.close);
    await tester.runAsync(() => _seed(database));

    await _pumpApp(
      tester,
      database: database,
      home: const LibraryScreen(libraryId: 'library'),
      size: const Size(1024, 900),
    );
    await _settleUi(tester);

    expect(find.text('Sections'), findsOneWidget);
    expect(find.text('Welcome to Dart'), findsOneWidget);
    expect(find.text('In progress'), findsOneWidget);
    await tester.tap(find.text('Reference').hitTestable());
    await _settleUi(tester);
    expect(find.text('Dart Handbook'), findsOneWidget);
    expect(find.text('Not started'), findsOneWidget);
    await _disposeTree(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'global Search exposes result type, context, and keyboard focus',
    (tester) async {
      final database = _database();
      addTearDown(database.close);
      await tester.runAsync(() => _seed(database));

      await _pumpApp(
        tester,
        database: database,
        home: const SearchScreen(),
        size: const Size(900, 820),
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.slash);
      await tester.pump();
      final searchField = tester.widget<TextField>(
        find.byType(TextField).hitTestable().first,
      );
      expect(searchField.focusNode?.hasFocus, isTrue);
      await tester.enterText(
        find.byType(TextField).hitTestable().first,
        'remember',
      );
      await tester.pump(const Duration(milliseconds: 300));
      await _settleUi(tester);

      expect(find.text('Remember null safety').hitTestable(), findsOneWidget);
      expect(find.text('Note').hitTestable(), findsOneWidget);
      expect(find.textContaining('Demo Course').hitTestable(), findsWidgets);
      await _disposeTree(tester);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Study tabs filter and display editable notes and bookmarks', (
    tester,
  ) async {
    final database = _database();
    addTearDown(database.close);
    await tester.runAsync(() => _seed(database));

    await _pumpApp(
      tester,
      database: database,
      home: const StudyScreen(),
      size: const Size(1024, 900),
    );

    expect(find.text('Remember null safety'), findsOneWidget);
    expect(find.textContaining('00:42'), findsOneWidget);
    await tester.tap(find.text('Bookmarks').hitTestable());
    await _settleUi(tester);
    expect(find.text('Key example'), findsOneWidget);
    expect(find.text('Bookmark'), findsOneWidget);
    expect(find.byTooltip('Bookmark actions'), findsOneWidget);
    await _disposeTree(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Settings presents grouped appearance, playback, backup, and sync',
    (tester) async {
      final database = _database();
      addTearDown(database.close);

      await _pumpApp(
        tester,
        database: database,
        home: const SettingsScreen(),
        size: const Size(1180, 1000),
      );

      expect(find.text('Appearance'), findsOneWidget);
      expect(find.text('Playback'), findsOneWidget);
      expect(find.text('Backup & restore'), findsOneWidget);
      expect(find.text('Local network sync host'), findsOneWidget);
      expect(find.text('Keyboard shortcuts'), findsOneWidget);
      expect(
        find.textContaining('does not include a companion client'),
        findsOneWidget,
      );
      await _disposeTree(tester);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('mobile library removal uses an adaptive confirmation sheet', (
    tester,
  ) async {
    final database = _database();
    addTearDown(database.close);
    await tester.runAsync(() => _seed(database));

    await _pumpApp(
      tester,
      database: database,
      home: const HomeScreen(),
      size: const Size(390, 844),
    );
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Libraries'),
      ),
    );
    await _settleUi(tester);
    await tester.tap(find.byTooltip('Library actions').hitTestable().first);
    await _settleUi(tester);
    await tester.tap(find.text('Remove library').hitTestable());
    await _settleUi(tester);

    expect(find.byType(BottomSheet), findsWidgets);
    expect(find.text('Remove this library?'), findsOneWidget);
    expect(
      find.textContaining('source files will stay untouched'),
      findsOneWidget,
    );
    await tester.tap(find.text('Cancel').hitTestable());
    await _settleUi(tester);
    await _disposeTree(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'player and PDF reader expose deliberate loading and missing states',
    (tester) async {
      final database = _database();
      addTearDown(database.close);
      await tester.runAsync(() => _seed(database));

      await _pumpApp(
        tester,
        database: database,
        home: const MediaPlayerScreen(itemId: 'video'),
        size: const Size(900, 700),
      );
      expect(find.text('Preparing your lesson'), findsOneWidget);
      await _settleUi(tester);
      expect(find.text('This lesson cannot be played'), findsOneWidget);
      expect(find.textContaining('missing or has moved'), findsOneWidget);

      await _disposeTree(tester);
      await _pumpApp(
        tester,
        database: database,
        home: const PdfReaderScreen(itemId: 'pdf'),
        size: const Size(430, 800),
      );
      expect(find.text('Preparing your document'), findsOneWidget);
      await _settleUi(tester);
      expect(find.text('This PDF cannot be opened'), findsOneWidget);
      expect(find.textContaining('missing or has moved'), findsOneWidget);
      await _disposeTree(tester);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('supported width matrix and large text do not overflow', (
    tester,
  ) async {
    final database = _database();
    addTearDown(database.close);
    tester.platformDispatcher.textScaleFactorTestValue = 1.7;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    for (final width in <double>[320, 375, 430, 768, 1024, 1280, 1440]) {
      await _disposeTree(tester);
      await _pumpApp(
        tester,
        database: database,
        home: const HomeScreen(),
        size: Size(width, 1000),
      );
      expect(
        tester.takeException(),
        isNull,
        reason: 'Unexpected layout exception at $width px',
      );
    }
    await _disposeTree(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('dark theme retains semantics and desktop pointer states', (
    tester,
  ) async {
    final database = _database();
    addTearDown(database.close);
    final semantics = tester.ensureSemantics();

    await _pumpApp(
      tester,
      database: database,
      home: const HomeScreen(),
      size: const Size(1280, 900),
      themeMode: ThemeMode.dark,
    );

    final scaffoldContext = tester.element(find.byType(Scaffold).first);
    expect(Theme.of(scaffoldContext).brightness, Brightness.dark);
    expect(find.bySemanticsLabel('StudyStream'), findsOneWidget);
    expect(find.bySemanticsLabel('Choose your first folder'), findsOneWidget);

    final pointer = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await pointer.addPointer();
    await pointer.moveTo(
      tester.getCenter(find.text('Choose your first folder').hitTestable()),
    );
    await tester.pump();
    await pointer.removePointer();

    await _disposeTree(tester);
    semantics.dispose();
    expect(tester.takeException(), isNull);
  });
}

AppDatabase _database() => AppDatabase.forTesting(NativeDatabase.memory());

Future<void> _pumpApp(
  WidgetTester tester, {
  required AppDatabase database,
  required Widget home,
  required Size size,
  bool wrapsMaterialApp = true,
  ThemeMode themeMode = ThemeMode.system,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  final child = wrapsMaterialApp
      ? MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: themeMode,
          home: home,
        )
      : home;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [appDatabaseProvider.overrideWithValue(database)],
      child: child,
    ),
  );
  await tester.pump();
  for (var turn = 0; turn < 3; turn++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 40)),
    );
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<void> _disposeTree(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(seconds: 1));
  await tester.pump();
}

Future<void> _settleUi(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 40)),
  );
  for (var frame = 0; frame < 12; frame++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<void> _seed(AppDatabase database) async {
  final now = DateTime.now().millisecondsSinceEpoch;
  await database.upsertLibrary(
    LibrariesCompanion.insert(
      id: 'library',
      title: 'Demo Course',
      description: const Value('A practical Dart learning path.'),
      rootFolderPath: '/missing/demo-course',
      createdAt: now - 10000,
      updatedAt: now,
      lastScannedAt: Value(now),
    ),
  );
  await database.upsertSection(
    SectionsCompanion.insert(
      id: 'section-1',
      libraryId: 'library',
      title: 'Getting Started',
      orderIndex: 0,
      folderPath: '/missing/demo-course/getting-started',
    ),
  );
  await database.upsertSection(
    SectionsCompanion.insert(
      id: 'section-2',
      libraryId: 'library',
      title: 'Reference',
      orderIndex: 1,
      folderPath: '/missing/demo-course/reference',
    ),
  );
  await database.upsertItem(
    ItemsCompanion.insert(
      id: 'video',
      libraryId: 'library',
      sectionId: 'section-1',
      title: 'Welcome to Dart',
      filename: 'welcome.mp4',
      filePath: '/missing/demo-course/getting-started/welcome.mp4',
      relativePath: 'getting-started/welcome.mp4',
      itemType: 'video',
      orderIndex: 0,
      durationSeconds: const Value(600),
      createdAt: Value(now - 9000),
      updatedAt: Value(now),
    ),
  );
  await database.upsertItem(
    ItemsCompanion.insert(
      id: 'pdf',
      libraryId: 'library',
      sectionId: 'section-2',
      title: 'Dart Handbook',
      filename: 'handbook.pdf',
      filePath: '/missing/demo-course/reference/handbook.pdf',
      relativePath: 'reference/handbook.pdf',
      itemType: 'pdf',
      orderIndex: 0,
      pageCount: const Value(120),
      createdAt: Value(now - 8000),
      updatedAt: Value(now - 1000),
    ),
  );
  await database.upsertPlayback(
    PlaybackProgressCompanion.insert(
      itemId: 'video',
      lastPositionSeconds: const Value(42),
      resumePositionSeconds: const Value(32),
      durationSeconds: const Value(600),
      percentWatched: const Value(35),
      completed: const Value(false),
      lastOpenedAt: Value(now),
      lastEventAt: Value(now),
      deviceId: 'test',
    ),
  );
  await database.upsertNote(
    NotesCompanion.insert(
      id: 'note',
      libraryId: 'library',
      itemId: const Value('video'),
      content: 'Remember null safety',
      positionSeconds: const Value(42),
      createdAt: now - 2000,
      updatedAt: now,
      deviceId: 'test',
    ),
  );
  await database.upsertBookmark(
    BookmarksCompanion.insert(
      id: 'bookmark',
      libraryId: 'library',
      itemId: 'video',
      title: 'Key example',
      description: const Value('Revisit the type-system explanation.'),
      positionSeconds: const Value(42),
      createdAt: now - 1000,
      updatedAt: now,
      deviceId: 'test',
    ),
  );
}
