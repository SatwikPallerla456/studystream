import 'dart:async';
import 'dart:io';
import '../db/app_database.dart';
import '../../domain/catalog/media_catalog_repository.dart';
import 'library_indexer.dart';

/// Each source has its own watcher, cancellation and availability boundary.
class LibraryWatcher {
  LibraryWatcher(this.database, this.indexer);
  final AppDatabase database;
  final LibraryIndexer indexer;
  final _watches = <String, StreamSubscription<FileSystemEvent>>{};
  final _paths = <String, String>{};
  final _timers = <String, Timer>{};
  final _tokens = <String, ScanCancellationToken>{};
  final _dirty = <String>{};
  StreamSubscription<List<Library>>? _libraries;
  Timer? _reconcileTimer;
  bool _disposed = false, _reconciling = false;
  void start() {
    _libraries ??= database.watchLibraries().listen(
      (_) => unawaited(_reconcile()),
    );
    _reconcileTimer ??= Timer.periodic(
      const Duration(seconds: 5),
      (_) => unawaited(_reconcile()),
    );
  }

  Future<void> _reconcile() async {
    if (_disposed || _reconciling) return;
    _reconciling = true;
    try {
      final ids = <String>{};
      for (final library in await database.watchLibraries().first) {
        for (final source in await MediaCatalogRepository(
          database,
        ).sources(library.id)) {
          ids.add(source.id);
          final available = await Directory(source.root).exists();
          if (!available) {
            await MediaCatalogRepository(
              database,
            ).setSourceAvailability(source, true);
            await _watches.remove(source.id)?.cancel();
            continue;
          }
          if (source.unavailable) {
            await MediaCatalogRepository(
              database,
            ).setSourceAvailability(source, false);
            _schedule(library, source);
          }
          if (_paths[source.id] == source.root &&
              _watches.containsKey(source.id))
            continue;
          await _watches.remove(source.id)?.cancel();
          _paths[source.id] = source.root;
          try {
            _watches[source.id] = Directory(source.root)
                .watch(recursive: true)
                .listen(
                  (event) {
                    if (!event.path
                        .split(Platform.pathSeparator)
                        .last
                        .startsWith('.'))
                      _schedule(library, source);
                  },
                  onError: (Object _) {
                    _watches.remove(source.id)?.cancel();
                  },
                );
          } on FileSystemException {
            /* Refresh stays available. */
          }
        }
      }
      for (final id in _paths.keys.toList()) {
        if (!ids.contains(id)) {
          await _watches.remove(id)?.cancel();
          _paths.remove(id);
          _timers.remove(id)?.cancel();
          _tokens[id]?.cancel();
        }
      }
    } finally {
      _reconciling = false;
    }
  }

  void _schedule(Library library, LibrarySource source) {
    if (_disposed) return;
    _timers.remove(source.id)?.cancel();
    _timers[source.id] = Timer(
      const Duration(milliseconds: 900),
      () => unawaited(_refresh(library, source)),
    );
  }

  Future<void> _refresh(Library library, LibrarySource source) async {
    if (_disposed) return;
    if (_tokens.containsKey(source.id)) {
      _dirty.add(source.id);
      return;
    }
    final token = _tokens[source.id] = ScanCancellationToken();
    try {
      await indexer.scanRootFolder(
        rootFolderPath: source.root,
        title: library.title,
        existingLibraryId: library.id,
        source: source,
        cancellationToken: token,
      );
    } on Object {
      /* Missing volumes never delete history. */
    } finally {
      _tokens.remove(source.id);
      if (_dirty.remove(source.id)) _schedule(library, source);
    }
  }

  Future<void> dispose() async {
    _disposed = true;
    _reconcileTimer?.cancel();
    for (final t in _timers.values) {
      t.cancel();
    }
    for (final token in _tokens.values) {
      token.cancel();
    }
    await _libraries?.cancel();
    for (final watch in _watches.values) {
      await watch.cancel();
    }
  }
}
