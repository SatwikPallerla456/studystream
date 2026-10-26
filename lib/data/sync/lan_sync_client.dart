import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' as drift;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../db/app_database.dart';
import 'sync_snapshot_merger.dart';
import 'sync_change_journal.dart';
import 'music_sync_projection.dart';
import '../../domain/services/sync_conflict_resolver.dart';
import '../../domain/catalog/catalog_identity_store.dart';

enum ConnectionPhase { disconnected, connecting, connected, retrying, error }

class SyncClientState {
  const SyncClientState({
    this.phase = ConnectionPhase.disconnected,
    this.address,
    this.lastSyncAt,
    this.message,
    this.attempt = 0,
  });
  final ConnectionPhase phase;
  final String? address;
  final int? lastSyncAt;
  final String? message;
  final int attempt;
}

abstract interface class CredentialStore {
  Future<String?> read();
  Future<void> write(String value);
  Future<void> clear();
}

class SecureCredentialStore implements CredentialStore {
  const SecureCredentialStore({this.key = 'studystream.pairedHost'});
  final String key;
  static const _storage = FlutterSecureStorage(
    mOptions: MacOsOptions(usesDataProtectionKeychain: false),
  );
  @override
  Future<String?> read() => _storage.read(key: key);
  @override
  Future<void> write(String value) => _storage.write(key: key, value: value);
  @override
  Future<void> clear() => _storage.delete(key: key);
}

class RemoteMediaSource {
  const RemoteMediaSource(this.uri, this.headers);
  final Uri uri;
  final Map<String, String> headers;
}

class LanSyncClient {
  LanSyncClient(this.database, {CredentialStore? credentials})
    : credentials = credentials ?? const SecureCredentialStore();
  final AppDatabase database;
  bool _musicPeer = false;
  final CredentialStore credentials;
  final _states = StreamController<SyncClientState>.broadcast();
  SyncClientState _state = const SyncClientState();
  SyncClientState get state => _state;
  Stream<SyncClientState> get states => _states.stream;
  Uri? _address;
  String? _token;
  Timer? _timer;
  bool _disposed = false;
  int _generation = 0;
  int _attempt = 0;
  Future<void>? _activeSync;
  HttpClient? _http;

  static Uri validateAddress(String raw) {
    final uri = Uri.tryParse(
      raw.trim().contains('://') ? raw.trim() : 'http://${raw.trim()}',
    );
    if (uri == null ||
        !['http', 'https'].contains(uri.scheme) ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        (uri.path.isNotEmpty && uri.path != '/') ||
        uri.hasQuery ||
        uri.hasFragment) {
      throw const FormatException(
        'Enter a host address such as http://192.168.1.20:45831.',
      );
    }
    return uri.replace(path: '');
  }

  Future<void> restore({bool synchronize = true}) async {
    final generation = _generation;
    try {
      final value = await credentials.read();
      if (value == null || _disposed || generation != _generation) return;
      final data = jsonDecode(value) as Map<String, dynamic>;
      _address = validateAddress(data['address'] as String);
      _token = data['token'] as String;
      final lastSync = int.tryParse(
        await database.getSetting('sync.lastSuccess') ?? '',
      );
      _state = SyncClientState(
        address: _address.toString(),
        lastSyncAt: lastSync,
      );
      if (synchronize) await sync();
    } catch (_) {
      if (!_disposed && _address == null) {
        _emit(
          ConnectionPhase.error,
          'Saved pairing credentials could not be loaded. Pair this device again.',
        );
      }
    }
  }

  Future<void> pair({
    required String address,
    required String code,
    required String name,
  }) async {
    final uri = validateAddress(address);
    if (!RegExp(r'^\d{6}$').hasMatch(code.trim()) || name.trim().isEmpty) {
      throw const FormatException(
        'Enter a device name and the six-digit pairing code.',
      );
    }
    await disconnect(forget: false);
    final generation = _generation;
    _emit(ConnectionPhase.connecting);
    try {
      final response = await _request(
        uri,
        '/v1/pair',
        body: {
          'code': code.trim(),
          'name': name.trim(),
          'deviceId': await database.getDeviceId(),
        },
        authenticate: false,
      );
      if (_disposed || generation != _generation) return;
      final token = response['token'];
      if (token is! String || token.isEmpty) {
        throw const FormatException('Invalid pairing response.');
      }
      await credentials.write(
        jsonEncode({'address': uri.toString(), 'token': token}),
      );
      if (_disposed || generation != _generation) return;
      _address = uri;
      _token = token;
      await sync();
    } catch (error) {
      if (!_disposed && generation == _generation) {
        _emit(ConnectionPhase.error, _friendly(error));
      }
      rethrow;
    }
  }

  Future<void> sync() =>
      _activeSync ??= _synchronize().whenComplete(() => _activeSync = null);

  Future<void> _synchronize() async {
    final address = _address;
    if (_disposed || address == null || _token == null) return;
    final generation = _generation;
    _timer?.cancel();
    _emit(_attempt > 0 ? ConnectionPhase.retrying : ConnectionPhase.connecting);
    try {
      final health = await _request(address, '/v1/health', authenticate: false);
      _musicPeer = (health['capabilities'] as List? ?? []).contains(
        MusicSyncProjection.capability,
      );
      final modern = (health['capabilities'] as List? ?? []).contains(
        'catalog-bootstrap-v2',
      );
      if (modern) {
        await _uploadChanges(address);
        await _pullModern(address, generation);
      } else {
        await _uploadChanges(address, legacy: true);
        final snapshot = await _request(address, '/v1/snapshot');
        if (_disposed || generation != _generation) return;
        await database.transaction(() async {
          await _importCatalogue(snapshot);
          await SyncSnapshotMerger(
            database,
          ).merge(snapshot, allowedLibraryIds: await _remoteLibraryIds());
        });
      }
      if (_disposed || generation != _generation) return;
      _attempt = 0;
      final now = DateTime.now().millisecondsSinceEpoch;
      await database.setSetting('sync.lastSuccess', '$now');
      _state = SyncClientState(
        phase: ConnectionPhase.connected,
        address: address.toString(),
        lastSyncAt: now,
      );
      _states.add(_state);
      _timer = Timer(const Duration(seconds: 15), () => unawaited(sync()));
    } catch (error) {
      if (_disposed || generation != _generation) return;
      _attempt++;
      final revoked =
          error is SyncRequestException && [401, 403].contains(error.status);
      _emit(
        revoked ? ConnectionPhase.error : ConnectionPhase.retrying,
        _friendly(error),
      );
      if (!revoked) {
        final seconds = (1 << _attempt.clamp(1, 6)).clamp(2, 60);
        _timer = Timer(Duration(seconds: seconds), () => unawaited(sync()));
      }
    }
  }

  String _cursorKey(Uri address) => 'sync.v2.${address.toString()}';
  Future<Set<String>> _remoteLibraryIds() async =>
      (await (database.select(database.libraries)..where(
                (library) => library.rootFolderPath.equals('remote:$_address'),
              ))
              .get())
          .map((library) => library.id)
          .toSet();

  Future<void> _uploadChanges(Uri address, {bool legacy = false}) async {
    final journal = SyncChangeJournal(database),
        libraries = await _remoteLibraryIds();
    if (libraries.isEmpty) return;
    final ids = libraries.toList()..sort();
    final scope = jsonEncode({'libraries': ids, 'music': _musicPeer}),
        key = '${_cursorKey(address)}.uploadJournal${legacy ? '.legacy' : ''}';
    var cursor = await database.getSetting('$key.scope') == scope
        ? int.tryParse(await database.getSetting('$key.cursor') ?? '')
        : null;
    // Only bounded pages are resident. Acknowledgement precedes cursor advance;
    // failure replays the same semantic revisions without inventing new edits.
    Future<void> send(List events) async {
      var body = <String, dynamic>{
        'schemaVersion': 3,
        'protocolVersion': legacy ? 1 : 2,
        'catalogRows': <String, List<Map<String, dynamic>>>{},
      };
      var bytes = 0, count = 0;
      Future<void> flush() async {
        if (count == 0) return;
        await _request(address, '/v1/snapshot', body: body);
        body = {
          'schemaVersion': 3,
          'protocolVersion': legacy ? 1 : 2,
          'catalogRows': <String, List<Map<String, dynamic>>>{},
        };
        bytes = 0;
        count = 0;
      }

      const names = {
        'playback_progress': 'playback',
        'reading_progress': 'reading',
        'media_records': 'mediaRecords',
      };
      for (final raw in events) {
        var record = raw['record'];
        // Hard deletion of host-owned files is not a client mutation. User-data
        // deletions travel as retained soft-deleted rows in this same journal.
        if (record is! Map<String, dynamic>) continue;
        final kind = raw['entity_kind'] as String;
        if (legacy && CatalogIdentityStore.tables.contains(kind)) continue;
        if (!_musicPeer) {
          record = MusicSyncProjection.record(kind, record);
          if (record == null) continue;
        }
        final length = utf8.encode(jsonEncode(record)).length;
        if (length > 4 * 1024 * 1024)
          throw const FormatException(
            'A sync record exceeds the transfer limit',
          );
        if (count >= 100 || bytes + length > 512 * 1024) await flush();
        if (CatalogIdentityStore.tables.contains(kind)) {
          ((body['catalogRows']
                      as Map<String, List<Map<String, dynamic>>>)[kind] ??=
                  [])
              .add(record);
        } else {
          (body[names[kind] ?? kind] ??= <Map<String, dynamic>>[]).add(record);
        }
        bytes += length;
        count++;
      }
      await flush();
    }

    if (cursor != null) {
      final page = await journal.page(cursor, libraries);
      if (page['resetRequired'] == true) cursor = null;
    }
    if (cursor == null) {
      final start = await journal.head();
      String? next;
      do {
        final page = await journal.bootstrap(libraries, cursor: next);
        await send(page['events'] as List);
        next = page['next'] as String?;
      } while (next != null);
      cursor = start;
      await database.setSetting('$key.scope', scope);
      await database.setSetting('$key.cursor', '$cursor');
    }
    while (true) {
      final page = await journal.page(cursor!, libraries);
      if (page['resetRequired'] == true) {
        await database.setSetting('$key.scope', '');
        throw const FormatException(
          'Sync history changed. Retry to refresh the scoped upload.',
        );
      }
      await send(page['events'] as List);
      cursor = page['cursor'] as int;
      await database.setSetting('$key.cursor', '$cursor');
      if (page['hasMore'] != true) break;
    }
  }

  Future<void> _applyEvents(List<dynamic> events) async {
    if (events.length > 100)
      throw const FormatException('Too many sync events');
    final snapshot = <String, dynamic>{
      'schemaVersion': 3,
      'protocolVersion': 2,
      for (final key in [
        'libraries',
        'sections',
        'items',
        'playback',
        'reading',
        'notes',
        'bookmarks',
        'mediaRecords',
      ])
        key: <Map<String, dynamic>>[],
      'catalogRows': <String, List<Map<String, dynamic>>>{},
    };
    final tombstones = <Map<String, dynamic>>[];
    const names = {
      'playback_progress': 'playback',
      'reading_progress': 'reading',
      'media_records': 'mediaRecords',
    };
    for (final raw in events) {
      if (raw is! Map<String, dynamic> ||
          raw['entity_kind'] is! String ||
          raw['entity_id'] is! String)
        throw const FormatException('Invalid sync event');
      final kind = raw['entity_kind'] as String, record = raw['record'];
      if (record == null) {
        tombstones.add(raw);
        continue;
      }
      if (record is! Map<String, dynamic>)
        throw const FormatException('Invalid sync record');
      if (CatalogIdentityStore.tables.contains(kind)) {
        ((snapshot['catalogRows']
                    as Map<String, List<Map<String, dynamic>>>)[kind] ??=
                [])
            .add(record);
      } else {
        final key = names[kind] ?? kind;
        if (snapshot[key] is! List)
          throw const FormatException('Unknown sync entity');
        (snapshot[key] as List).add(record);
      }
    }
    await database.transaction(() async {
      await _importCatalogue(snapshot);
      final allowed = await _remoteLibraryIds();
      await SyncSnapshotMerger(
        database,
      ).merge(snapshot, allowedLibraryIds: allowed);
      for (final event in tombstones) {
        final id = event['entity_id'] as String;
        if (!allowed.contains(event['library_id'])) continue;
        switch (event['entity_kind']) {
          case 'items':
            await database.customStatement(
              'UPDATE items SET unavailable=1 WHERE id=? AND library_id=?',
              [id, event['library_id']],
            );
          case 'sections':
            await database.customStatement(
              'UPDATE sections SET unavailable=1 WHERE id=? AND library_id=?',
              [id, event['library_id']],
            );
          case 'libraries':
            await database.customStatement(
              'UPDATE libraries SET unavailable=1 WHERE id=?',
              [id],
            );
          case 'notes':
            await database.deleteNoteSoft(id);
          case 'bookmarks':
            await database.deleteBookmarkSoft(id);
          case 'media_parts':
          case 'media_extras':
            final table = event['entity_kind'] as String;
            await database.customStatement(
              'DELETE FROM $table WHERE id=? AND library_id=?',
              [id, event['library_id']],
            );
          default:
            break; // Retain asset-linked history after descriptive cascades.
        }
      }
    });
  }

  Future<void> _pruneScope(List<dynamic> ids) async {
    final allowed = ids.whereType<String>().toSet();
    for (final id in await _remoteLibraryIds()) {
      if (allowed.contains(id)) continue;
      await database.customStatement(
        'UPDATE libraries SET unavailable=1 WHERE id=?',
        [id],
      );
      await database.customStatement(
        'UPDATE items SET unavailable=1 WHERE library_id=?',
        [id],
      );
    }
    database.notifyUpdates({
      drift.TableUpdate.onTable(database.items),
      drift.TableUpdate.onTable(database.libraries),
    });
  }

  Future<void> _pullModern(
    Uri address,
    int generation, {
    int resets = 0,
  }) async {
    if (resets > 2)
      throw const FormatException(
        'Host access changed repeatedly. Sync again.',
      );
    final key = _cursorKey(address);
    var cursor = int.tryParse(await database.getSetting('$key.cursor') ?? '');
    var scope = await database.getSetting('$key.scope');
    if (cursor != null && scope != null) {
      while (true) {
        final page = await _request(
          address,
          Uri(
            path: '/v2/changes',
            queryParameters: {'since': '$cursor', 'scope': scope!},
          ).toString(),
        );
        if (_disposed || generation != _generation) return;
        if (page['resetRequired'] == true) {
          cursor = null;
          await database.setSetting(
            '${_cursorKey(address)}.uploadJournal.scope',
            '',
          );
          await _uploadChanges(address);
          break;
        }
        final next = page['cursor'];
        if (next is! int || next < cursor!)
          throw const FormatException('Invalid host change cursor');
        await database.transaction(() async {
          await _applyEvents(page['events'] as List);
          await _pruneScope(page['libraries'] as List);
          await database.setSetting('$key.cursor', '$next');
        });
        cursor = next;
        if (page['hasMore'] != true) return;
      }
    }
    String? next;
    int? start;
    String? transferScope;
    List<dynamic> libraries = [];
    do {
      final page = await _request(
        address,
        Uri(
          path: '/v2/bootstrap',
          queryParameters: {if (next != null) 'cursor': next},
        ).toString(),
      );
      if (_disposed || generation != _generation) return;
      if (page['head'] is! int || page['scope'] is! String)
        throw const FormatException('Invalid initial transfer');
      start ??= page['head'] as int;
      transferScope ??= page['scope'] as String;
      if (page['scope'] != transferScope)
        throw const FormatException(
          'Library access changed during transfer. Sync again.',
        );
      libraries = page['libraries'] as List;
      await _applyEvents(page['events'] as List);
      next = page['next'] as String?;
    } while (next != null);
    await database.transaction(() async {
      await _pruneScope(libraries);
      await database.setSetting('$key.cursor', '$start');
      await database.setSetting('$key.scope', transferScope!);
    });
    // Replay changes since the first bootstrap page, including deletions that
    // happened while later pages were in flight.
    await _pullModern(address, generation, resets: resets + 1);
  }

  Future<void> _importCatalogue(Map<String, dynamic> snapshot) async {
    final version = snapshot['schemaVersion'];
    if (version is! int || version < 1 || version > database.schemaVersion) {
      throw const FormatException(
        'This host uses an incompatible sync version.',
      );
    }
    final hostKey = _address!.toString();
    final deviceId = await database.getDeviceId();
    await database.transaction(() async {
      for (final row
          in (snapshot['libraries'] as List).cast<Map<String, dynamic>>()) {
        final remote = Library.fromJson(row);
        final existing = await database.getLibraryById(remote.id);
        if (existing?.rootFolderPath == 'remote:$hostKey')
          await database.upsertLibrary(
            existing!
                .copyWith(unavailable: remote.unavailable)
                .toCompanion(true),
          );
        if (existing == null) {
          await database.upsertLibrary(
            remote
                .copyWith(rootFolderPath: 'remote:$hostKey')
                .toCompanion(true),
          );
        }
      }
      for (final row
          in (snapshot['sections'] as List).cast<Map<String, dynamic>>()) {
        final remote = Section.fromJson(row);
        final library = await database.getLibraryById(remote.libraryId);
        if (library?.rootFolderPath != 'remote:$hostKey') continue;
        await database
            .into(database.sections)
            .insertOnConflictUpdate(
              remote.copyWith(folderPath: 'remote:$hostKey'),
            );
      }
      for (final row
          in (snapshot['items'] as List).cast<Map<String, dynamic>>()) {
        final remote = Item.fromJson(row);
        final library = await database.getLibraryById(remote.libraryId);
        if (library?.rootFolderPath != 'remote:$hostKey') continue;
        final existing = await database.getItemById(remote.id);
        final metadata = existing == null
            ? remote
            : Item.fromJson(
                SyncConflictResolver.mergeMetadata(
                  existing.toJson(),
                  remote.toJson(),
                ),
              );
        final item = remote.copyWith(
          filePath: 'remote:${remote.id}',
          userTitle: drift.Value(metadata.userTitle),
          title: metadata.title,
          updatedAt: metadata.updatedAt,
          version: metadata.version,
        );
        await database.into(database.items).insertOnConflictUpdate(item);
      }
      // Device identity is local and never comes from a host snapshot.
      await database.setSetting('deviceId', deviceId);
    });
  }

  Future<RemoteMediaSource> artworkFor(Item item) async {
    final media = await sourceFor(item);
    return RemoteMediaSource(
      media.uri.replace(path: '/v2/artwork/${Uri.encodeComponent(item.id)}'),
      media.headers,
    );
  }

  Future<RemoteMediaSource> sourceFor(Item item) async {
    if (!item.filePath.startsWith('remote:')) {
      return RemoteMediaSource(Uri.file(item.filePath), const {});
    }
    final library = await database.getLibraryById(item.libraryId);
    if (_address == null ||
        _token == null ||
        library?.rootFolderPath != 'remote:$_address') {
      throw StateError(
        'Connect to this library’s host in Settings to open its lessons.',
      );
    }
    return RemoteMediaSource(
      _address!.resolve('/v1/media/${Uri.encodeComponent(item.id)}'),
      {HttpHeaders.authorizationHeader: 'Bearer $_token'},
    );
  }

  Future<Map<String, dynamic>> _request(
    Uri address,
    String path, {
    Map<String, Object?>? body,
    bool authenticate = true,
  }) async {
    final client = _http ??= HttpClient()
      ..connectionTimeout = const Duration(seconds: 8);
    final request = await client
        .openUrl(body == null ? 'GET' : 'POST', address.resolve(path))
        .timeout(const Duration(seconds: 10));
    request.headers.set(
      'X-Tangerine-Capabilities',
      'progress-intent-v1,field-preferences-v1,music-metadata-v1',
    );
    request.followRedirects =
        false; // Never forward pairing credentials to redirects.
    if (authenticate) {
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $_token');
    }
    if (body != null) {
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode(body));
    }
    final response = await request.close().timeout(const Duration(seconds: 15));
    final bytes = <int>[];
    await for (final chunk in response.timeout(const Duration(seconds: 15))) {
      if (bytes.length + chunk.length > 10 * 1024 * 1024) {
        throw const FormatException('Sync snapshot is too large.');
      }
      bytes.addAll(chunk);
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw SyncRequestException(response.statusCode);
    }
    final decoded = jsonDecode(utf8.decode(bytes));
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Invalid host response.');
    }
    return decoded;
  }

  Future<void> disconnect({bool forget = false}) async {
    _generation++;
    _timer?.cancel();
    _http?.close(force: true);
    _http = null;
    await _activeSync;
    _address = null;
    _token = null;
    _attempt = 0;
    if (forget) await credentials.clear();
    if (!_disposed) _emit(ConnectionPhase.disconnected);
  }

  String _friendly(Object error) => error is SyncRequestException
      ? (error.status == 401 || error.status == 403
            ? 'Pairing was rejected or revoked. Check the code and pair again.'
            : 'The host could not process this request. Retry after checking the host.')
      : error is FormatException
      ? error.message
      : 'The host is unreachable. Offline edits are saved here; reconnection will retry automatically.';

  void _emit(ConnectionPhase phase, [String? message]) {
    if (_disposed) return;
    _state = SyncClientState(
      phase: phase,
      address: _address?.toString(),
      lastSyncAt: _state.lastSyncAt,
      message: message,
      attempt: _attempt,
    );
    _states.add(_state);
  }

  Future<void> dispose() async {
    _disposed = true;
    await disconnect();
    await _states.close();
  }
}

class SyncRequestException implements Exception {
  const SyncRequestException(this.status);
  final int status;
}
