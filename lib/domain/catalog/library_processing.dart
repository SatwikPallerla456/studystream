import 'dart:async';
import 'dart:io';
import 'package:drift/drift.dart';
import 'package:flutter/widgets.dart';
import 'package:uuid/uuid.dart';
import '../../data/db/app_database.dart';
import 'technical_media.dart';
import 'automatic_catalog_identification.dart';
import 'library_organization.dart';

/// Device-local execution state, never exported as user/catalog sync state.
class LibraryProcessingStore {
  const LibraryProcessingStore(this.db);
  final AppDatabase db;
  static String signature(Item item) =>
      '${item.fingerprint}:${item.fileSize}:${item.modifiedAt}';
  static Future<void> createTables(AppDatabase db) async {
    await db.customStatement(
      '''CREATE TABLE IF NOT EXISTS library_processing_jobs(
      item_id TEXT NOT NULL REFERENCES items(id) ON DELETE CASCADE,
      library_id TEXT NOT NULL REFERENCES libraries(id) ON DELETE CASCADE,
      kind TEXT NOT NULL,signature TEXT NOT NULL,version INTEGER NOT NULL,
      state TEXT NOT NULL DEFAULT 'queued',attempts INTEGER NOT NULL DEFAULT 0,
      retry_at INTEGER NOT NULL DEFAULT 0,error_code TEXT,lease TEXT,updated_at INTEGER NOT NULL,
      PRIMARY KEY(item_id,kind))''',
    );
    await db.customStatement(
      'CREATE INDEX IF NOT EXISTS idx_processing_due ON library_processing_jobs(state,retry_at,library_id,item_id)',
    );
    await db.customStatement(
      '''CREATE TABLE IF NOT EXISTS processing_suggestions(
      item_id TEXT PRIMARY KEY REFERENCES items(id) ON DELETE CASCADE,
      library_id TEXT NOT NULL REFERENCES libraries(id) ON DELETE CASCADE,
      target_id TEXT REFERENCES items(id) ON DELETE SET NULL,reason TEXT NOT NULL,dismissed INTEGER NOT NULL DEFAULT 0)''',
    );
    await db.customStatement(
      'CREATE INDEX IF NOT EXISTS idx_processing_suggestions ON processing_suggestions(library_id,dismissed,item_id)',
    );
  }

  void notify() => db.notifyUpdates({TableUpdate.onTable(db.appSettings)});
  Future<void> enqueue(Item item, {bool force = false, String? only}) async {
    if (item.filePath.startsWith('remote:')) return;
    for (final kind in [
      'organize',
      if (item.itemType == 'video') 'identify',
      if (TechnicalMediaAnalyzer.supports(item)) 'analyze',
    ]) {
      if (only != null && only != kind) continue;
      final version = kind == 'identify'
          ? AutomaticCatalogIdentification.version
          : kind == 'analyze'
          ? TechnicalMediaAnalyzer.version
          : LibraryOrganization.version;
      await db.customStatement(
        '''INSERT INTO library_processing_jobs(item_id,library_id,kind,signature,version,state,updated_at)
        VALUES(?,?,?,?,?,'queued',?) ON CONFLICT(item_id,kind) DO UPDATE SET signature=excluded.signature,
        version=excluded.version,state='queued',attempts=0,retry_at=0,error_code=NULL,lease=NULL,updated_at=excluded.updated_at
        WHERE library_processing_jobs.signature<>excluded.signature OR library_processing_jobs.version<>excluded.version ${force ? 'OR 1=1' : ''}''',
        [
          item.id,
          item.libraryId,
          kind,
          signature(item),
          version,
          DateTime.now().millisecondsSinceEpoch,
        ],
      );
    }
  }

  Future<void> enqueueLibrary(
    String libraryId, {
    bool force = false,
    String? only,
  }) async {
    var cursor = '';
    while (true) {
      final rows = await db
          .customSelect(
            'SELECT * FROM items WHERE library_id=? AND id>? ORDER BY id LIMIT 100',
            variables: [Variable(libraryId), Variable(cursor)],
          )
          .get();
      if (rows.isEmpty) break;
      await db.transaction(() async {
        for (final row in rows) {
          await enqueue(db.items.map(row.data), force: force, only: only);
        }
      });
      cursor = rows.last.data['id'] as String;
      await Future<void>.delayed(Duration.zero);
    }
    notify();
  }

  Future<void> retryFailures(String libraryId) async {
    await db.customStatement(
      "UPDATE library_processing_jobs SET state='queued',attempts=0,retry_at=0,error_code=NULL WHERE library_id=? AND state IN ('failed','deferred','unsupported')",
      [libraryId],
    );
    notify();
  }

  Future<void> setPaused(String libraryId, bool paused) async {
    await db.setSetting(
      'processing.pause:$libraryId',
      paused ? 'true' : 'false',
    );
    notify();
  }

  Stream<List<QueryRow>> watchSummary(String libraryId) => db
      .customSelect(
        '''SELECT j.kind,j.state,COUNT(*) AS total
    FROM library_processing_jobs j WHERE j.library_id=? GROUP BY j.kind,j.state''',
        variables: [Variable(libraryId)],
        readsFrom: {db.items, db.appSettings},
      )
      .watch();
  Stream<List<QueryRow>> watchJobs(String libraryId, {String? after}) => db
      .customSelect(
        '''SELECT j.*,i.title,i.user_title,i.unavailable
    FROM library_processing_jobs j JOIN items i ON i.id=j.item_id WHERE j.library_id=?
    ${after == null ? '' : "AND (j.item_id || ':' || j.kind)>?"}
    ORDER BY j.item_id,j.kind LIMIT 51''',
        variables: [Variable(libraryId), if (after != null) Variable(after)],
        readsFrom: {db.items, db.appSettings},
      )
      .watch();
}

/// One owned job at a time, with bounded seeding and revision-safe publication.
/// It runs while the app is open; no OS background-service claim is made.
class LibraryProcessingService with WidgetsBindingObserver {
  LibraryProcessingService(this.db) : store = LibraryProcessingStore(db);
  final AppDatabase db;
  final LibraryProcessingStore store;
  Timer? _timer;
  StreamSubscription<dynamic>? _items;
  bool _disposed = false,
      _started = false,
      _ticking = false,
      _seed = true,
      _suspended = false;
  int _generation = 0, _holds = 0, _lastSeed = 0;
  String _cursor = '';
  final _paused = <String>{};
  bool _needsRecovery = false;
  bool get _blocked => _disposed || _suspended || _holds > 0;
  void start() {
    if (_started || _disposed) return;
    _started = true;
    WidgetsBinding.instance.addObserver(this);
    _items = db
        .customSelect('SELECT COUNT(*) FROM items', readsFrom: {db.items})
        .watch()
        .listen((_) {
          _seed = true;
        }, onError: (Object _) {});
    unawaited(_recover());
  }

  Future<void> _recover() async {
    try {
      await db.customStatement(
        "UPDATE library_processing_jobs SET state='queued',lease=NULL WHERE state='running'",
      );
      store.notify();
    } catch (_) {
      _needsRecovery = true;
    } finally {
      _schedule();
    }
  }

  void _schedule() {
    if (_started && !_disposed) {
      _timer?.cancel();
      _timer = Timer(
        const Duration(milliseconds: 750),
        () => unawaited(_tick()),
      );
    }
  }

  VoidCallback hold() {
    _holds++;
    _generation++;
    var released = false;
    return () {
      if (released) return;
      released = true;
      _holds--;
      _schedule();
    };
  }

  Future<void> pause(String libraryId, bool paused) async {
    await store.setPaused(libraryId, paused);
    if (paused)
      _paused.add(libraryId);
    else
      _paused.remove(libraryId);
    _generation++;
    _schedule();
  }

  Future<void> setAutomaticIdentification(
    String libraryId,
    bool enabled,
  ) async {
    _generation++;
    await db.setSetting(
      AutomaticCatalogIdentification.setting(libraryId),
      enabled ? 'true' : 'false',
    );
    store.notify();
    _schedule();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _suspended = {
      AppLifecycleState.paused,
      AppLifecycleState.detached,
    }.contains(state);
    if (_suspended) _generation++;
    _schedule();
  }

  Future<void> _seedPage() async {
    final rows = await db
        .customSelect(
          "SELECT * FROM items WHERE id>? AND file_path NOT LIKE 'remote:%' ORDER BY id LIMIT 100",
          variables: [Variable(_cursor)],
        )
        .get();
    if (rows.isEmpty) {
      _cursor = '';
      _seed = false;
      _lastSeed = DateTime.now().millisecondsSinceEpoch;
      return;
    }
    await db.transaction(() async {
      for (final row in rows) {
        await store.enqueue(db.items.map(row.data));
      }
    });
    _cursor = rows.last.data['id'] as String;
    store.notify();
  }

  Future<void> _tick() async {
    if (_ticking) return;
    _ticking = true;
    try {
      if (_blocked) return;
      if (_needsRecovery) {
        await db.customStatement(
          "UPDATE library_processing_jobs SET state='queued',lease=NULL WHERE state='running'",
        );
        _needsRecovery = false;
        store.notify();
      }
      final now = DateTime.now().millisecondsSinceEpoch;
      if (_seed || now - _lastSeed > 30000) await _seedPage();
      final pauses = await db
          .customSelect(
            "SELECT key FROM app_settings WHERE key LIKE 'processing.pause:%' AND value='true'",
          )
          .get();
      _paused
        ..clear()
        ..addAll(
          pauses.map(
            (r) =>
                (r.data['key'] as String).substring('processing.pause:'.length),
          ),
        );
      final rows = await db
          .customSelect(
            '''SELECT j.* FROM library_processing_jobs j JOIN items i ON i.id=j.item_id
        WHERE (j.state='queued' OR (j.state IN ('failed','deferred') AND j.attempts<3 AND j.retry_at<=?))
        AND i.unavailable=0 AND i.file_path NOT LIKE 'remote:%'
        AND NOT EXISTS(SELECT 1 FROM item_assets a JOIN library_sources s ON s.id=a.source_id WHERE a.item_id=i.id AND s.unavailable=1)
        AND NOT EXISTS(SELECT 1 FROM app_settings p WHERE p.key='processing.pause:'||j.library_id AND p.value='true')
        AND (j.kind<>'identify' OR NOT EXISTS(SELECT 1 FROM app_settings a WHERE a.key='identification.enabled:'||j.library_id AND a.value='false'))
        ORDER BY j.updated_at,j.item_id,CASE j.kind WHEN 'organize' THEN 0 WHEN 'identify' THEN 2 ELSE 1 END LIMIT 1''',
            variables: [Variable(now)],
          )
          .get();
      if (rows.isEmpty || _blocked) return;
      final job = rows.first.data,
          item = await db.getItemById(job['item_id'] as String);
      if (item == null) return;
      if (LibraryProcessingStore.signature(item) != job['signature']) {
        await store.enqueue(item);
        return;
      }
      final generation = _generation,
          kind = job['kind'] as String,
          signature = job['signature'] as String,
          lease = const Uuid().v4();
      bool current() =>
          !_blocked &&
          _generation == generation &&
          !_paused.contains(item.libraryId);
      await db.customStatement(
        "UPDATE library_processing_jobs SET state='running',lease=?,attempts=attempts+1,updated_at=? WHERE item_id=? AND kind=? AND signature=?",
        [lease, now, item.id, kind, signature],
      );
      store.notify();
      var state = 'complete';
      String? error;
      try {
        if (kind == 'organize') {
          await LibraryOrganization(db).organize(item, isCurrent: current);
        } else if (kind == 'identify') {
          final result = await AutomaticCatalogIdentification(
            db,
          ).run(item, isCurrent: current);
          state = result.state;
          error = result.reason;
        } else {
          final data = await TechnicalMediaAnalyzer(
            db,
          ).analyze(item, isCurrent: current);
          state = data['analysisState'] as String;
          if (state == 'failed') error = 'parseFailed';
        }
      } on FileSystemException {
        state = 'deferred';
        error = 'sourceUnavailable';
      } on Object {
        state = current() ? 'failed' : 'queued';
        error = current()
            ? (kind == 'identify' ? 'providerUnavailable' : 'processingFailed')
            : null;
      }
      if (!current()) {
        state = 'queued';
        error = null;
      }
      final attempts = job['attempts'] as int;
      await db.customStatement(
        '''UPDATE library_processing_jobs SET state=?,error_code=?,retry_at=?,updated_at=?,
        attempts=CASE WHEN ? IN ('queued','deferred') THEN MAX(0,attempts-1) ELSE attempts END WHERE item_id=? AND kind=? AND signature=? AND lease=?''',
        [
          state,
          error,
          DateTime.now().millisecondsSinceEpoch +
              (attempts == 0 ? 60000 : 300000),
          DateTime.now().millisecondsSinceEpoch,
          state,
          item.id,
          kind,
          signature,
          lease,
        ],
      );
      store.notify();
    } catch (_) {
      // Retry a possibly interrupted claim after a transient database failure.
      _needsRecovery = true;
    } finally {
      _ticking = false;
      _schedule();
    }
  }

  Future<void> dispose() async {
    _disposed = true;
    _generation++;
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    await _items?.cancel();
    // Current owned work drains, discards its result and leaves a resumable job.
  }
}
