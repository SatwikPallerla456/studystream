import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:pdfrx/pdfrx.dart';

import 'app.dart';
import 'data/providers/app_providers.dart';
import 'data/platform/folder_access.dart';
import 'dart:async';
import 'dart:io';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FolderAccess.restore();
  if (!Platform.isMacOS ||
      const bool.fromEnvironment('TANGERINE_INTERIM_PLAYER')) {
    MediaKit.ensureInitialized();
  }
  await pdfrxFlutterInitialize();
  PaintingBinding.instance.imageCache.maximumSizeBytes = 64 * 1024 * 1024;
  final container = ProviderContainer();
  try {
    await container.read(appDatabaseProvider).customSelect('SELECT 1').get();
  } catch (_) {
    container.dispose();
    runApp(
      MaterialApp(
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.storage_rounded, size: 48),
                  const SizedBox(height: 16),
                  const Text('Local learning data could not be opened'),
                  const SizedBox(height: 8),
                  const Text(
                    'Check available storage and folder permissions. Your existing database has been kept.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  FilledButton(onPressed: main, child: const Text('Try again')),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    return;
  }
  container.read(libraryWatcherProvider);
  unawaited(container.read(lanSyncClientProvider).restore());
  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const StudyMediaPlayerApp(),
    ),
  );
}
