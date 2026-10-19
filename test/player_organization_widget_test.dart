import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_stream/data/db/app_database.dart';
import 'package:study_stream/core/theme/app_theme.dart';
import 'package:study_stream/data/providers/app_providers.dart';
import 'package:study_stream/features/playlists/playlists_screen.dart';
import 'package:study_stream/features/settings/player_controls_screen.dart';

void main() {
  testWidgets(
    'playlists and player controls support narrow screens and large text',
    (tester) async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      await db.customSelect('SELECT 1').get();
      const channel = MethodChannel('tangerine/playback');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async => []);
      addTearDown(() => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null));
      for (final width in [320.0, 768.0, 1280.0]) {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        for (final screen in [
          const PlaylistsScreen(),
          const PlayerControlsScreen(),
        ]) {
          await tester.pumpWidget(
            ProviderScope(
              overrides: [appDatabaseProvider.overrideWithValue(db)],
              child: MaterialApp(
              theme: AppTheme.dark(),
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: const TextScaler.linear(1.7)),
                  child: child!,
                ),
                home: screen,
              ),
            ),
          );
          for (var attempt = 0; attempt < 40; attempt++) {
            await tester.pump(const Duration(milliseconds: 50));
            if (find.byType(CircularProgressIndicator).evaluate().isEmpty) break;
          }
          expect(find.byType(CircularProgressIndicator), findsNothing);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pumpAndSettle();
        }
      }
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    },
  );
}
