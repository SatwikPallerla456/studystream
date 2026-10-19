import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:study_stream/core/theme/app_theme.dart';
import 'package:study_stream/data/db/app_database.dart';
import 'package:study_stream/data/providers/app_providers.dart';
import 'package:study_stream/data/providers/device_runtime_provider.dart';
import 'package:study_stream/features/setup/device_home.dart';
import 'package:study_stream/features/setup/mode_selection_screen.dart';

void main() {
  testWidgets(
    'choosing Server opens setup; switching to Player keeps libraries',
    (tester) async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      await tester.runAsync(
        () => database.upsertLibrary(
          LibrariesCompanion.insert(
            id: 'existing',
            title: 'Existing media',
            rootFolderPath: '/existing',
            createdAt: 1,
            updatedAt: 1,
          ),
        ),
      );
      final router = _router();
      addTearDown(router.dispose);
      await _pump(tester, database, router, const Size(1280, 900));
      await tester.tap(find.text('Set up server'));
      await _settle(tester);
      expect(find.text('Set up your media server'), findsOneWidget);
      expect(find.text('Existing media'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Start server'),
            )
            .onPressed,
        isNotNull,
      );
      await tester.tap(find.text('Player mode'));
      await _settle(tester);
      expect(find.text('Your media, all in one place'), findsOneWidget);
      final libraries = await tester.runAsync(
        () => database.watchLibraries().first,
      );
      expect(libraries!.single.id, 'existing');
      final setting = await tester.runAsync(
        () => database.getSetting(DeviceRuntime.settingKey),
      );
      final saved = jsonDecode(setting!);
      expect(saved['role'], 'player');
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'mode chooser and server setup support narrow screens and large text',
    (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 1.7;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      for (final width in [320.0, 430.0, 768.0, 1280.0]) {
        final database = AppDatabase.forTesting(NativeDatabase.memory());
        final router = _router();
        await _pump(tester, database, router, Size(width, 1000));
        await tester.ensureVisible(find.text('Set up server'));
        await tester.tap(find.text('Set up server'));
        await _settle(tester);
        await tester.ensureVisible(find.text('Start server'));
        expect(
          tester
              .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Start server'),
              )
              .onPressed,
          isNull,
        );
        expect(tester.takeException(), isNull, reason: 'Overflow at $width');
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(seconds: 1));
        router.dispose();
        await tester.runAsync(database.close);
      }
    },
  );
}

GoRouter _router() => GoRouter(
  routes: [
    GoRoute(path: '/', builder: (_, _) => const DeviceHome()),
    GoRoute(path: '/mode', builder: (_, _) => const ModeSelectionScreen()),
  ],
);

Future<void> _pump(
  WidgetTester tester,
  AppDatabase database,
  GoRouter router,
  Size size,
) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [appDatabaseProvider.overrideWithValue(database)],
      child: MaterialApp.router(theme: AppTheme.dark(), routerConfig: router),
    ),
  );
  await _settle(tester);
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 30)),
    );
    await tester.pump(const Duration(milliseconds: 80));
  }
}
