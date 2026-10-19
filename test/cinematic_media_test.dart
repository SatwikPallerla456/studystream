import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:study_stream/core/theme/app_theme.dart';
import 'package:study_stream/data/db/app_database.dart';
import 'package:study_stream/data/providers/app_providers.dart';
import 'package:study_stream/features/media/cinematic_home_section.dart';
import 'package:study_stream/features/media/media_browser_section.dart';
import 'package:study_stream/features/media/media_details_screen.dart';
import 'package:study_stream/shared/widgets/cinematic_media.dart';

void main() {
  test(
    'keyset browsing visits more than 120 equal-title items exactly once',
    () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      await _seed(db, count: 135);
      final container = ProviderContainer(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
      );
      addTearDown(container.dispose);
      String? afterTitle, afterId;
      final visited = <String>[];
      while (true) {
        final page = await _readPage(container, (
          kind: 'all',
          query: '',
          afterTitle: afterTitle,
          afterId: afterId,
        ));
        final visible = page.take(60).toList();
        visited.addAll(visible.map((item) => item.id));
        if (page.length <= 60) break;
        afterTitle = visible.last.title;
        afterId = visible.last.id;
      }
      expect(visited, hasLength(135));
      expect(visited.toSet(), hasLength(135));
      expect(
        visited,
        List.generate(135, (i) => 'item-${i.toString().padLeft(3, '0')}'),
      );
    },
  );

  test('paging keeps its boundary when an earlier item is deleted', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await _seed(db, count: 75);
    final container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);
    final first = await _readPage(container, (
      kind: 'all',
      query: '',
      afterTitle: null,
      afterId: null,
    ));
    final boundary = first[59];
    await (db.delete(db.items)..where((t) => t.id.equals('item-000'))).go();
    final second = await _readPage(container, (
      kind: 'all',
      query: '',
      afterTitle: boundary.title,
      afterId: boundary.id,
    ));
    expect(
      second.map((item) => item.id),
      List.generate(15, (i) => 'item-${(i + 60).toString().padLeft(3, '0')}'),
    );
  });

  testWidgets(
    'cinematic Home opens details, Study, playback and returns to the same row',
    (tester) async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      await tester.runAsync(() => _seed(db, count: 12));
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => Scaffold(
              body: SingleChildScrollView(
                child: CinematicHomeSection(onOpen: (item) {}),
              ),
            ),
          ),
          GoRoute(
            path: '/details/:itemId',
            builder: (_, state) =>
                MediaDetailsScreen(itemId: state.pathParameters['itemId']!),
          ),
          GoRoute(
            path: '/player/:itemId',
            builder: (context, _) => Scaffold(
              appBar: AppBar(title: const Text('Fixture player')),
              body: const Text('Playback route'),
            ),
          ),
          GoRoute(
            path: '/library/:id',
            builder: (_, _) => const Scaffold(body: Text('Library route')),
          ),
        ],
      );
      addTearDown(router.dispose);
      tester.view.physicalSize = const Size(1100, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [appDatabaseProvider.overrideWithValue(db)],
          child: MaterialApp.router(
            theme: AppTheme.dark(),
            routerConfig: router,
          ),
        ),
      );
      await _settle(tester);
      expect(find.text('FROM YOUR LIBRARY'), findsOneWidget);
      expect(find.text('Recently Added'), findsOneWidget);
      final list = find.descendant(
        of: find.byType(CinematicMediaRow).first,
        matching: find.byType(ListView),
      );
      await tester.drag(list, const Offset(-600, 0));
      await tester.pumpAndSettle();
      final before = tester.widget<ListView>(list).controller!.offset;
      expect(before, greaterThan(0));
      await tester.tap(find.text('Details').first);
      await _settle(tester);
      expect(find.text('About this title'), findsOneWidget);
      await tester.tap(find.text('Study'));
      await _settle(tester);
      expect(find.text('Notes'), findsWidgets);
      router.pop();
      await _settle(tester);
      await tester.tap(find.text('Play').first);
      await _settle(tester);
      expect(find.text('Playback route'), findsOneWidget);
      router.pop();
      await _settle(tester);
      router.pop();
      await _settle(tester);
      final returned = find.descendant(
        of: find.byType(CinematicMediaRow).first,
        matching: find.byType(ListView),
      );
      expect(tester.widget<ListView>(returned).controller!.offset, before);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 1));
    },
  );

  testWidgets(
    'cinematic cards tolerate long titles, missing art and large text at compact widths',
    (tester) async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      await tester.runAsync(() => _seed(db, count: 2));
      final item = (await tester.runAsync(() => db.getItemById('item-000')))!;
      final long = item.copyWith(
        title: List.filled(20, 'Long title').join(' '),
      );
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final theme in [AppTheme.light(), AppTheme.dark()]) {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [appDatabaseProvider.overrideWithValue(db)],
            child: MaterialApp(
              theme: theme,
              home: MediaQuery(
                data: const MediaQueryData(
                  size: Size(320, 900),
                  textScaler: TextScaler.linear(1.8),
                  disableAnimations: true,
                ),
                child: Scaffold(
                  body: SingleChildScrollView(
                    child: Column(
                      children: [
                        FeaturedMedia(
                          item: long,
                          onOpen: () {},
                          onDetails: () {},
                        ),
                        CinematicMediaRow(
                          title: 'Recently Added',
                          items: [long],
                          onDetails: (_) {},
                          onOpen: (_) {},
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await _settle(tester);
        expect(tester.takeException(), isNull);
        expect(find.byTooltip('Play ${long.title}'), findsOneWidget);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(seconds: 1));
      }
    },
  );
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 30)),
    );
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _seed(AppDatabase db, {required int count}) async {
  await db.upsertLibrary(
    LibrariesCompanion.insert(
      id: 'library',
      title: 'Movie library',
      rootFolderPath: '/fixture/not-present',
      createdAt: 1,
      updatedAt: 1,
    ),
  );
  await db.upsertSection(
    SectionsCompanion.insert(
      id: 'section',
      libraryId: 'library',
      title: 'Movies',
      orderIndex: 0,
      folderPath: '/fixture/not-present',
    ),
  );
  for (var i = 0; i < count; i++) {
    await db.upsertItem(
      ItemsCompanion.insert(
        id: 'item-${i.toString().padLeft(3, '0')}',
        libraryId: 'library',
        sectionId: 'section',
        title: 'Repeated title',
        filename: '$i.mp4',
        filePath: '/fixture/not-present/$i.mp4',
        relativePath: '$i.mp4',
        itemType: 'video',
        orderIndex: i,
        createdAt: drift.Value(i),
      ),
    );
  }
}

Future<List<Item>> _readPage(
  ProviderContainer container,
  MediaFilter filter,
) async {
  final provider = mediaCatalogueProvider(filter);
  final subscription = container.listen(provider, (_, _) {});
  try {
    return await container.read(provider.future);
  } finally {
    subscription.close();
  }
}
