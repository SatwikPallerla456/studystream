import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/app_preferences.dart';
import '../../domain/services/app_preferences_repository.dart';
import '../db/app_database.dart';
import '../indexer/library_indexer.dart';
import '../indexer/library_watcher.dart';
import '../sync/lan_sync_server.dart';
import '../sync/lan_sync_client.dart';

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final database = AppDatabase();
  ref.onDispose(database.close);
  return database;
});

final libraryIndexerProvider = Provider<LibraryIndexer>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return LibraryIndexer(db);
});

final libraryWatcherProvider = Provider<LibraryWatcher>((ref) {
  final watcher = LibraryWatcher(
    ref.watch(appDatabaseProvider),
    ref.watch(libraryIndexerProvider),
  )..start();
  ref.onDispose(watcher.dispose);
  return watcher;
});

final lanSyncServerProvider = Provider<LanSyncServer>((ref) {
  final server = LanSyncServer(ref.watch(appDatabaseProvider));
  ref.onDispose(server.dispose);
  return server;
});

final lanSyncClientProvider = Provider<LanSyncClient>((ref) {
  final client = LanSyncClient(ref.watch(appDatabaseProvider));
  ref.onDispose(client.dispose);
  return client;
});

final appPreferencesRepositoryProvider = Provider<AppPreferencesRepository>(
  (ref) => AppPreferencesRepository(ref.watch(appDatabaseProvider)),
);

final themeModeProvider = NotifierProvider<ThemeModeController, ThemeMode>(
  ThemeModeController.new,
);

final appPreferencesProvider =
    NotifierProvider<AppPreferencesController, AppPreferences>(
      AppPreferencesController.new,
    );

class AppPreferencesController extends Notifier<AppPreferences> {
  late final AppPreferencesRepository _repository;
  bool _changed = false;

  @override
  AppPreferences build() {
    _repository = ref.read(appPreferencesRepositoryProvider);
    unawaited(_load());
    return const AppPreferences();
  }

  Future<void> _load() async {
    final loaded = await _repository.load();
    if (ref.mounted && !_changed) state = loaded;
  }

  Future<void> update(AppPreferences value) async {
    _changed = true;
    state = value;
    await _repository.save(value);
  }
}

class ThemeModeController extends Notifier<ThemeMode> {
  bool _changed = false;
  @override
  ThemeMode build() {
    _load();
    return ThemeMode.system;
  }

  Future<void> _load() async {
    final value = await ref.read(appDatabaseProvider).getSetting('themeMode');
    if (!ref.mounted || _changed) return;
    state = switch (value) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  Future<void> setMode(ThemeMode mode) async {
    _changed = true;
    state = mode;
    await ref.read(appDatabaseProvider).setSetting('themeMode', mode.name);
  }
}
