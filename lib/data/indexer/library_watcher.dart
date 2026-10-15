import 'dart:async';
import 'dart:io';

import '../db/app_database.dart';
import 'library_indexer.dart';

/// Watches only imported local roots. Watch failures leave manual refresh usable.
class LibraryWatcher {
  LibraryWatcher(this.database, this.indexer);
  final AppDatabase database;
  final LibraryIndexer indexer;
  StreamSubscription<List<Library>>? _libraries;
  final _watches = <String, StreamSubscription<FileSystemEvent>>{};
  final _timers = <String, Timer>{};
  final _scanning = <String>{};
  final _dirty = <String>{};
  final _tokens = <String, ScanCancellationToken>{};
  final _paths = <String, String>{};
  bool _disposed = false;

  void start() {
    _libraries ??= database.watchLibraries().listen((libraries) {
      if (_disposed) return;
      final ids = libraries.map((library) => library.id).toSet();
      for (final id in _paths.keys.toList()) {
        if (!ids.contains(id)) {
          _watches.remove(id)?.cancel();
          _timers.remove(id)?.cancel();
          _paths.remove(id);
          _tokens[id]?.cancel();
        }
      }
      for (final library in libraries) {
        if (library.rootFolderPath.startsWith('remote:') ||
            _paths[library.id] == library.rootFolderPath) {
          continue;
        }
        _watches.remove(library.id)?.cancel();
        _paths[library.id] = library.rootFolderPath;
        try {
          _watches[library.id] = Directory(library.rootFolderPath)
              .watch(recursive: true)
              .listen(
                (event) {
                  if (event.path
                      .split(Platform.pathSeparator)
                      .last
                      .startsWith('.')) {
                    return;
                  }
                  _schedule(library);
                },
                onError: (Object _) {
                  _watches.remove(library.id)?.cancel();
                },
              );
        } on FileSystemException {
          /* Manual refresh is the fallback on unsupported platforms. */
        }
      }
    });
  }

  void _schedule(Library library) {
    if (_disposed) return;
    _timers.remove(library.id)?.cancel();
    _timers[library.id] = Timer(
      const Duration(milliseconds: 900),
      () => unawaited(_refresh(library)),
    );
  }

  Future<void> _refresh(Library library) async {
    if (_disposed || !_paths.containsKey(library.id)) return;
    if (!_scanning.add(library.id)) {
      _dirty.add(library.id);
      return;
    }
    final token = _tokens[library.id] = ScanCancellationToken();
    try {
      await indexer.scanRootFolder(
        rootFolderPath: library.rootFolderPath,
        title: library.title,
        cancellationToken: token,
      );
    } on Object {
      // Do not remove data when a volume is temporarily unavailable.
    } finally {
      _tokens.remove(library.id);
      _scanning.remove(library.id);
      if (_dirty.remove(library.id)) _schedule(library);
    }
  }

  Future<void> dispose() async {
    _disposed = true;
    for (final timer in _timers.values) {
      timer.cancel();
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
