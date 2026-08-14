import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/app_preferences.dart';
import '../../domain/services/app_preferences_repository.dart';
import '../db/app_database.dart';
import '../indexer/library_indexer.dart';
import '../sync/lan_sync_server.dart';

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final database = AppDatabase();
  ref.onDispose(database.close);
  return database;
});

final libraryIndexerProvider = Provider<LibraryIndexer>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return LibraryIndexer(db);
});

final lanSyncServerProvider = Provider<LanSyncServer>((ref) {
  final server = LanSyncServer(ref.watch(appDatabaseProvider));
  ref.onDispose(server.dispose);
  return server;
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

  @override
  AppPreferences build() {
    _repository = ref.read(appPreferencesRepositoryProvider);
    unawaited(_load());
    return const AppPreferences();
  }

  Future<void> _load() async {
    final loaded = await _repository.load();
    if (ref.mounted) state = loaded;
  }

  Future<void> update(AppPreferences value) async {
    state = value;
    await _repository.save(value);
  }
}

class ThemeModeController extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    _load();
    return ThemeMode.system;
  }

  Future<void> _load() async {
    final value = await ref.read(appDatabaseProvider).getSetting('themeMode');
    state = switch (value) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  Future<void> setMode(ThemeMode mode) async {
    state = mode;
    await ref.read(appDatabaseProvider).setSetting('themeMode', mode.name);
  }
}
