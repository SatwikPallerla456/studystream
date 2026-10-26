import 'dart:async';
import 'dart:convert';

import '../../data/db/app_database.dart';
import '../catalog/media_catalog_repository.dart';
import '../catalog/media_record_contract.dart';
import 'reader_contract.dart';
import '../../data/sync/sync_state_store.dart';

/// Serial writes capture immutable changes; resume never materializes defaults.
class ReaderSessionStore {
  ReaderSessionStore(this.db, this.item)
    : catalog = MediaCatalogRepository(db) {
    _context = SyncStateStore(db).context('reading', item.id);
  }
  late Future<Map<String, dynamic>> _context;
  Future<Map<String, dynamic>> get progressContext => _context;
  final AppDatabase db;
  final Item item;
  final MediaCatalogRepository catalog;
  Future<void> _tail = Future.value();
  static const settingKeys = {
    'rtl',
    'mode',
    'background',
    'fit',
    'fontSize',
    'lineHeight',
    'coverSingle',
    'leadingEdgeAction',
    'trailingEdgeAction',
    'topAction',
    'centerAction',
    'pairingStarts',
    'singlePages',
  };
  Future<Map<String, dynamic>> settings() async {
    final raw = await db.getSetting('reader_defaults');
    final app = raw == null
        ? <String, dynamic>{}
        : Map<String, dynamic>.from(jsonDecode(raw) as Map);
    return resolveReaderSettings(
      app: ReaderPreferencesStore.project(app),
      library: ReaderPreferencesStore.project(
        (await catalog.record('library:${item.libraryId}'))?.data ?? {},
      ),
      title: (await catalog.record('reader:${item.id}'))?.data ?? {},
    );
  }

  Future<void> write({
    ReaderLocator? locator,
    Map<String, dynamic>? progressContext,
    Map<String, dynamic> changes = const {},
    Set<String> reset = const {},
  }) {
    final captured = Map<String, dynamic>.from(changes);
    final removals = Set<String>.from(reset);
    final encoded = locator?.encode();
    final write = _tail.then(
      (_) => db.transaction(() async {
        if (encoded != null)
          await SyncStateStore(db).requireContext(
            'reading',
            item.id,
            progressContext ?? await _context,
          );
        final old = (await catalog.record('reader:${item.id}'))?.data ?? {};
        final next = <String, dynamic>{...old, ...captured};
        for (final key in removals) {
          next.remove(key);
        }
        if (encoded != null) next['locator'] = encoded;
        await catalog.save(
          'reader:${item.id}',
          'reader',
          item.libraryId,
          next,
          itemId: item.id,
          changedFields: {
            ...captured.keys,
            ...removals,
            if (encoded != null) 'locator',
          },
        );
      }),
    );
    _tail = write.catchError((Object _) {});
    return write;
  }

  Future<void> defaultsForLibrary(
    Map<String, dynamic> resolved,
  ) => db.transaction(() async {
    final old = (await catalog.record('library:${item.libraryId}'))?.data ?? {};
    await catalog.save('library:${item.libraryId}', 'library', item.libraryId, {
      ...old,
      for (final key in ReaderPreferencesStore.sharedKeys)
        if (resolved.containsKey(key)) key: resolved[key],
    }, changedFields: ReaderPreferencesStore.sharedKeys);
  });
  Future<void> get flushed => _tail;
}

enum ReaderPreferenceScope { app, library, title }

class ReaderPreferenceLayers {
  const ReaderPreferenceLayers(this.app, this.library, this.title);
  final Map<String, dynamic> app, library, title;
  Map<String, dynamic> own(ReaderPreferenceScope scope) => switch (scope) {
    ReaderPreferenceScope.app => app,
    ReaderPreferenceScope.library => library,
    ReaderPreferenceScope.title => title,
  };
  Map<String, dynamic> inherited(ReaderPreferenceScope scope) =>
      resolveReaderSettings(
        app: scope == ReaderPreferenceScope.app ? const {} : app,
        library: scope == ReaderPreferenceScope.title ? library : const {},
      );
  Map<String, dynamic> resolved(ReaderPreferenceScope scope) =>
      resolveReaderSettings(
        app: app,
        library: scope == ReaderPreferenceScope.app ? const {} : library,
        title: scope == ReaderPreferenceScope.title ? title : const {},
      );
}

/// Preference edits write one sparse layer, preserving locators and library type.
/// Reading position writes can continue while the settings panel is open.
class ReaderPreferencesStore {
  const ReaderPreferencesStore(this.db, {this.libraryId, this.item});
  final AppDatabase db;
  final String? libraryId;
  final Item? item;
  static const sharedKeys = {
    'rtl',
    'mode',
    'background',
    'fit',
    'fontSize',
    'lineHeight',
    'coverSingle',
    'leadingEdgeAction',
    'trailingEdgeAction',
    'topAction',
    'centerAction',
  };

  static Map<String, dynamic> project(
    Map<String, dynamic> input, {
    bool title = false,
  }) => {
    for (final entry in input.entries)
      if ((sharedKeys.contains(entry.key) ||
              title && {'singlePages', 'pairingStarts'}.contains(entry.key)) &&
          entry.value != null)
        entry.key: entry.value,
  };

  Future<Map<String, dynamic>> _app() async {
    final raw = await db.getSetting('reader_defaults');
    if (raw == null) return {};
    return Map<String, dynamic>.from(jsonDecode(raw) as Map);
  }

  Future<ReaderPreferenceLayers> layers() async {
    final catalog = MediaCatalogRepository(db);
    return ReaderPreferenceLayers(
      project(await _app()),
      libraryId == null
          ? {}
          : project((await catalog.record('library:$libraryId'))?.data ?? {}),
      item == null
          ? {}
          : project(
              (await catalog.record('reader:${item!.id}'))?.data ?? {},
              title: true,
            ),
    );
  }

  Future<void> change(
    ReaderPreferenceScope scope, {
    Map<String, dynamic> changes = const {},
    Set<String> reset = const {},
  }) => db.transaction(() async {
    final keys = scope == ReaderPreferenceScope.title
        ? ReaderSessionStore.settingKeys
        : sharedKeys;
    if (changes.keys.any((key) => !keys.contains(key)) ||
        reset.any((key) => !keys.contains(key))) {
      throw const FormatException(
        'This preference belongs to an individual title.',
      );
    }
    final catalog = MediaCatalogRepository(db);
    final Map<String, dynamic> old;
    switch (scope) {
      case ReaderPreferenceScope.app:
        old = await _app();
      case ReaderPreferenceScope.library:
        if (libraryId == null)
          throw const FormatException('Choose a library first.');
        old = (await catalog.record('library:$libraryId'))?.data ?? {};
      case ReaderPreferenceScope.title:
        if (item == null || item!.libraryId != libraryId)
          throw const FormatException('Choose a title first.');
        old = (await catalog.record('reader:${item!.id}'))?.data ?? {};
    }
    final next = {...old, ...changes};
    for (final key in reset) {
      next.remove(key);
    }
    if (scope == ReaderPreferenceScope.app) {
      // Reuse the reader value contract without giving global settings a media owner.
      MediaRecordContract.validate(
        id: 'reader:defaults',
        kind: 'reader',
        libraryId: 'defaults',
        itemId: 'defaults',
        data: project(next),
      );
      await db.setSetting('reader_defaults', jsonEncode(project(next)));
    } else if (scope == ReaderPreferenceScope.library) {
      await catalog.save(
        'library:$libraryId',
        'library',
        libraryId!,
        next,
        changedFields: {...changes.keys, ...reset},
      );
    } else {
      await catalog.save(
        'reader:${item!.id}',
        'reader',
        libraryId!,
        next,
        itemId: item!.id,
        changedFields: {...changes.keys, ...reset},
      );
    }
  });
}
