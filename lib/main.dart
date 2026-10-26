import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:pdfrx/pdfrx.dart';

import 'features/setup/tangerine_startup.dart';
import 'data/providers/app_providers.dart';
import 'data/platform/folder_access.dart';
import 'dart:async';
import 'dart:convert';
import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'features/player/desktop_playback_windows.dart';
import 'features/player/desktop_application_behavior.dart';
import 'domain/services/player_library_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  PaintingBinding.instance.imageCache.maximumSizeBytes = 64 * 1024 * 1024;
  if (DesktopPlaybackWindows.available) {
    final window = await WindowController.fromCurrentEngine();
    if (window.arguments.isNotEmpty && window.arguments.length < 4096) {
      Object? decoded;
      try {
        decoded = jsonDecode(window.arguments);
      } on FormatException {
        decoded = null;
      }
      final args = decoded is Map ? decoded : const {};
      if (args['type'] == 'player' &&
          args['item'] is String &&
          args['session'] is String &&
          (args['item'] as String).isNotEmpty &&
          (args['item'] as String).length <= 256 &&
          RegExp(r'^[a-f0-9-]{36}$').hasMatch(args['session'] as String)) {
        await FolderAccess.restore();
        await pdfrxFlutterInitialize();
        final scope = ProviderContainer(
          overrides: [
            independentPlaybackWindowProvider.overrideWithValue(true),
            playerLibraryRepositoryProvider.overrideWith(
              (ref) => PlayerLibraryRepository(
                ref.watch(appDatabaseProvider),
                queueNamespace: args['session'] as String,
              ),
            ),
          ],
        );
        await scope.read(appDatabaseProvider).customSelect('SELECT 1').get();
        await scope.read(lanSyncClientProvider).restore(synchronize: false);
        runApp(
          UncontrolledProviderScope(
            container: scope,
            child: DesktopPlaybackWindow(
              itemId: args['item'] as String,
              position: (args['position'] as num?)?.toDouble(),
              fromQueue: args['queue'] == true,
              title: args['title'] as String?,
            ),
          ),
        );
        return;
      }
    }
  }
  runApp(TangerineStartup(initialize: _initialize));
}

Future<ProviderContainer> _initialize(ValueChanged<String> phase) async {
  ProviderContainer? container;
  try {
    phase('Restoring your library access');
    await FolderAccess.restore();
    phase('Preparing your player');
    if (const bool.fromEnvironment('TANGERINE_INTERIM_PLAYER')) {
      MediaKit.ensureInitialized();
    }
    phase('Preparing your reader');
    await pdfrxFlutterInitialize();
    phase('Opening your library');
    container = ProviderContainer();
    await container.read(appDatabaseProvider).customSelect('SELECT 1').get();
    container.read(libraryWatcherProvider);
    container.read(desktopPlayerCoordinatorProvider);
    container.read(desktopApplicationBehaviorProvider);
    container.read(libraryProcessingProvider).start();
    unawaited(container.read(lanSyncClientProvider).restore());
    return container;
  } catch (_) {
    container?.dispose();
    rethrow;
  }
}
