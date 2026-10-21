import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:pdfrx/pdfrx.dart';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart' as drift;

import '../../core/utils/id_utils.dart';
import '../db/app_database.dart';
import '../playback/remote_playback_controller.dart';
import 'sync_snapshot_merger.dart';
import 'approved_media_source.dart';
import 'lan_discovery.dart';
import 'library_access_store.dart';
import 'sync_change_journal.dart';
import '../../domain/catalog/catalog_identity_store.dart';
import '../../domain/catalog/media_catalog_repository.dart';
import '../../domain/catalog/media_record_contract.dart';
import '../../domain/services/thumbnail_cache.dart';
import '../../domain/services/catalog_artwork_cache.dart';
import '../reader/book_page_source.dart';
import 'web_player.dart';
import '../../domain/study/study_catalog_repository.dart';

class LanSyncState {
  const LanSyncState({
    required this.running,
    this.port,
    this.pairingCode,
    this.error,
    this.name = 'Tangerine server',
  });

  final bool running;
  final int? port;
  final String? pairingCode;
  final String? error;
  final String name;
}

class LanSyncServer {
  LanSyncServer(this.database, {this.playbackController});

  final RemotePlaybackController? playbackController;

  final AppDatabase database;
  final _states = StreamController<LanSyncState>.broadcast();
  final _random = Random.secure();
  final _discovery = LanDiscovery();
  final _pairAttempts = <String, (int, int)>{};
  HttpServer? _server;
  StreamSubscription<HttpRequest>? _requestSubscription;
  Timer? _pairingTimer;
  String? _pairingCode;
  final _artwork = ThumbnailCache();
  int _pageJobs = 0;
  String _name = 'Tangerine server';
  Future<void>? _starting;

  LanSyncState _state = const LanSyncState(running: false);

  LanSyncState get state => _state;
  Stream<LanSyncState> get states => _states.stream;

  Future<void> start({int port = 0, String name = 'Tangerine server'}) =>
      _starting ??= _start(
        port: port,
        name: name,
      ).whenComplete(() => _starting = null);

  Future<void> _start({required int port, required String name}) async {
    if (_server != null) return;
    if (port < 0 ||
        port > 65535 ||
        name.trim().isEmpty ||
        name.trim().length > 80) {
      throw const FormatException('Enter a server name and a valid port.');
    }
    _name = name.trim();
    try {
      final server = await HttpServer.bind(
        InternetAddress.anyIPv4,
        port,
        shared: false,
      );
      _server = server;
      await SyncChangeJournal(database).trim();
      await _discovery.advertise(server.port, name: _name);
      regeneratePairingCode();
      _requestSubscription = server.listen(
        (request) => unawaited(
          _handle(request).catchError((Object error) async {
            // A client can disconnect after response headers or streaming began.
            try {
              await request.response.close();
            } catch (_) {
              /* Socket already closed. */
            }
          }),
        ),
        onError: (Object error, StackTrace stack) => _emit(
          LanSyncState(
            running: true,
            port: server.port,
            error: error.toString(),
            pairingCode: _pairingCode,
            name: _name,
          ),
        ),
      );
      _emit(
        LanSyncState(
          running: true,
          port: server.port,
          pairingCode: _pairingCode,
          name: _name,
        ),
      );
    } catch (error) {
      _pairingTimer?.cancel();
      _discovery.close();
      await _requestSubscription?.cancel();
      await _server?.close(force: true);
      _server = null;
      _requestSubscription = null;
      _emit(LanSyncState(running: false, error: error.toString()));
      rethrow;
    }
  }

  void regeneratePairingCode() {
    _pairingCode = (100000 + _random.nextInt(900000)).toString();
    _pairingTimer?.cancel();
    _pairingTimer = Timer(const Duration(minutes: 10), () {
      _pairingCode = null;
      _emit(LanSyncState(running: true, port: _server?.port, name: _name));
    });
    if (_server != null) {
      _emit(
        LanSyncState(
          running: true,
          port: _server?.port,
          pairingCode: _pairingCode,
          name: _name,
        ),
      );
    }
  }

  Future<void> stop() async {
    try {
      await _starting;
    } on Object {
      /* Failed starts are already cleaned up. */
    }
    _pairingTimer?.cancel();
    _discovery.close();
    await _requestSubscription?.cancel();
    await _server?.close(force: true);
    _server = null;
    _pairingCode = null;
    _requestSubscription = null;
    _emit(const LanSyncState(running: false));
  }

  Future<void> dispose() async {
    await stop();
    await _states.close();
  }

  Future<void> _handle(HttpRequest request) async {
    try {
      request.response.headers
        ..set('X-Content-Type-Options', 'nosniff')
        ..set('Cache-Control', 'no-store');
      final path = request.uri.pathSegments;
      if ((request.method == 'GET' || request.method == 'HEAD') &&
          request.uri.path == '/') {
        request.response.headers
          ..contentType = ContentType.html
          ..set(
            'Content-Security-Policy',
            "default-src 'self'; script-src 'unsafe-inline'; style-src 'unsafe-inline'; frame-src 'self'; object-src 'none'; base-uri 'none'; frame-ancestors 'none'",
          )
          ..set('Referrer-Policy', 'no-referrer');
        if (request.method == 'GET') request.response.write(webPlayerHtml);
        await request.response.close();
        return;
      }
      if (request.method == 'GET' && request.uri.path == '/v1/health') {
        return await _json(request, HttpStatus.ok, {
          'service': 'StudyStream',
          'version': 1,
          'protocolVersion': 2,
          'name': _name,
          'product': 'Tangerine',
          'capabilities': [
            'catalogue',
            'streaming',
            'range-requests',
            'study-sync',
            'study-pages-v1',
            'catalog-v2',
            'catalog-bootstrap-v2',
            'change-feed-v2',
            'library-grants-v1',
            'reader-locator-v1',
            'field-overrides-v1',
          ],
        });
      }
      if (request.method == 'POST' && request.uri.path == '/v1/pair') {
        return await _pair(request);
      }
      final device = await _authorise(request);
      if (device == null) return;
      if (request.method == 'GET' && request.uri.path == '/v1/session') {
        return await _json(request, HttpStatus.ok, {
          'deviceId': device.id,
          'capabilities': ['study-pages-v1'],
          'name': _name,
          'protocolVersion': 2,
          'libraries': [
            for (final library
                in await database.select(database.libraries).get())
              if ((await LibraryAccessStore(
                database,
              ).allowed(device.id, 'browse')).contains(library.id))
                {'id': library.id, 'title': library.title},
          ],
        });
      }
      if (request.method == 'POST' && request.uri.path == '/v1/logout') {
        await database.revokeDevice(device.id);
        request.response.cookies.add(
          Cookie('myvlc_session', '')
            ..path = '/v1'
            ..httpOnly = true
            ..sameSite = SameSite.strict
            ..maxAge = 0,
        );
        request.response.cookies.add(
          Cookie('myvlc_session', '')
            ..path = '/'
            ..httpOnly = true
            ..sameSite = SameSite.strict
            ..maxAge = 0,
        );
        return await _json(request, HttpStatus.ok, {'status': 'disconnected'});
      }
      await database.upsertKnownDevice(
        device
            .toCompanion(true)
            .copyWith(
              lastSeenAt: drift.Value(DateTime.now().millisecondsSinceEpoch),
              lastAddress: drift.Value(
                request.connectionInfo?.remoteAddress.address,
              ),
            ),
      );
      final access = LibraryAccessStore(database);
      final browse = await access.allowed(device.id, 'browse');
      final mutate = await access.allowed(device.id, 'mutate');
      final stream = await access.allowed(device.id, 'stream');
      final scopeIds = browse.toList()..sort();
      final scope = stableId(scopeIds.join('::'));
      if (request.method == 'GET' && request.uri.path == '/v2/bootstrap') {
        return _json(request, HttpStatus.ok, {
          'protocolVersion': 2,
          'scope': scope,
          'libraries': scopeIds,
          ...await SyncChangeJournal(
            database,
          ).bootstrap(browse, cursor: request.uri.queryParameters['cursor']),
        });
      }
      if (request.method == 'GET' && request.uri.path == '/v2/changes') {
        if (request.uri.queryParameters['scope'] != scope)
          return _json(request, HttpStatus.ok, {
            'protocolVersion': 2,
            'scope': scope,
            'libraries': scopeIds,
            'resetRequired': true,
            'events': [],
          });
        final since = int.tryParse(request.uri.queryParameters['since'] ?? '');
        final limit = int.tryParse(
          request.uri.queryParameters['limit'] ?? '100',
        );
        if (since == null || limit == null)
          throw const FormatException(
            'A valid change cursor and limit are required',
          );
        return _json(request, HttpStatus.ok, {
          'protocolVersion': 2,
          'scope': scope,
          'libraries': scopeIds,
          ...await SyncChangeJournal(
            database,
          ).page(since, browse, limit: limit),
        });
      }
      if (request.method == 'GET' &&
          path.length == 3 &&
          path[0] == 'v2' &&
          path[1] == 'study') {
        final item = await database.getItemById(path[2]);
        if (item == null || !browse.contains(item.libraryId))
          return _json(request, HttpStatus.notFound, {
            'error': 'Item unavailable',
          });
        final args = request.uri.queryParameters;
        final limit = int.tryParse(args['limit'] ?? '40');
        if (limit == null)
          throw const FormatException('Invalid Study page limit');
        final repository = StudyCatalogRepository(database);
        final kind = args['kind'];
        if (kind != null) {
          if (!{'notes', 'bookmarks'}.contains(kind))
            throw const FormatException('Unknown Study entry kind');
          final page = await repository.page(
            item,
            kind == 'notes' ? StudyKind.notes : StudyKind.bookmarks,
            query: args['q'] ?? '',
            cursor: args['cursor'],
            limit: limit,
          );
          return _json(request, HttpStatus.ok, {
            'protocolVersion': 2,
            'kind': kind,
            ...page.toJson(),
          });
        }
        if (args.containsKey('cursor'))
          throw const FormatException('A Study cursor requires an entry kind');
        // Preserve the original response shape for older browser clients.
        final notes = await repository.page(
          item,
          StudyKind.notes,
          query: args['q'] ?? '',
          limit: limit,
        );
        final bookmarks = await repository.page(
          item,
          StudyKind.bookmarks,
          query: args['q'] ?? '',
          limit: limit,
        );
        return _json(request, HttpStatus.ok, {
          'notes': notes.entries,
          'bookmarks': bookmarks.entries,
          'pages': {
            'notes': {'next': notes.next},
            'bookmarks': {'next': bookmarks.next},
          },
        });
      }

      if ((request.method == 'GET' || request.method == 'HEAD') &&
          path.length == 3 &&
          path[0] == 'v2' &&
          path[1] == 'artwork')
        return _serveArtwork(request, path[2], browse);
      if ((request.method == 'GET' || request.method == 'HEAD') &&
          path.length == 4 &&
          path[0] == 'v2' &&
          path[1] == 'pages')
        return _servePage(request, path[2], path[3], stream);
      if (request.method == 'GET' && request.uri.path == '/v2/catalog')
        return await _catalogPage(request, browse);
      if (request.uri.path == '/v1/playback') {
        final active = playbackController?.status['itemId'];
        final activeItem = active is String
            ? await database.getItemById(active)
            : null;
        if (activeItem == null ||
            !browse.contains(activeItem.libraryId) ||
            request.method == 'POST' &&
                !mutate.contains(activeItem.libraryId)) {
          if (request.method == 'GET')
            return _json(request, HttpStatus.ok, {
              'enabled': false,
              'active': false,
            });
          return _json(request, HttpStatus.forbidden, {
            'error': 'This library is not approved for playback control',
          });
        }
        final enabled =
            await database.getSetting('sync.allowPlaybackControl') == 'true';
        if (request.method == 'GET') {
          return await _json(request, HttpStatus.ok, {
            'enabled': enabled,
            if (enabled) ...?playbackController?.status,
          });
        }
        if (request.method == 'POST') {
          if (!enabled ||
              playbackController == null ||
              playbackController!.status['active'] != true) {
            return await _json(request, HttpStatus.conflict, {
              'error':
                  'Host playback control is disabled or no player is open.',
            });
          }
          final body = await _readJson(request);
          final action = body['action'];
          final value = body['value'];
          if (action is! String || value != null && value is! num) {
            throw const FormatException('Invalid player command.');
          }
          if ({'next', 'previous'}.contains(action) &&
              !(await _hostedLibraryIds()).every(mutate.contains))
            return await _json(request, HttpStatus.forbidden, {
              'error':
                  'Queue navigation requires access to all hosted libraries',
            });
          await playbackController!.execute(
            action,
            (value as num?)?.toDouble(),
          );
          return await _json(request, HttpStatus.ok, {'status': 'applied'});
        }
      }
      if (request.method == 'GET' && request.uri.path == '/v1/snapshot') {
        final snapshot = await _hostedSnapshot(allowed: browse);
        await database.markDeviceSynced(
          device.id,
          address: request.connectionInfo?.remoteAddress.address,
        );
        return await _json(request, HttpStatus.ok, snapshot);
      }
      if (request.method == 'POST' && request.uri.path == '/v1/snapshot') {
        final body = await _readJson(request);
        await SyncSnapshotMerger(
          database,
        ).merge(body, allowedLibraryIds: mutate);
        await database.markDeviceSynced(
          device.id,
          address: request.connectionInfo?.remoteAddress.address,
        );
        return await _json(request, HttpStatus.ok, {'status': 'merged'});
      }
      if ((request.method == 'GET' || request.method == 'HEAD') &&
          path.length == 3 &&
          path[0] == 'v1' &&
          path[1] == 'media') {
        return await _serveMedia(request, path[2], stream);
      }
      await _json(request, HttpStatus.notFound, {'error': 'Not found'});
    } on FormatException catch (error) {
      await _json(request, HttpStatus.badRequest, {'error': error.message});
    } on _PayloadTooLargeException {
      await _json(request, HttpStatus.requestEntityTooLarge, {
        'error': 'Request body is too large',
      });
    } catch (_) {
      await _json(request, HttpStatus.internalServerError, {
        'error': 'Request failed',
      });
    }
  }

  Future<void> _pair(HttpRequest request) async {
    final address = request.connectionInfo?.remoteAddress.address ?? 'unknown';
    final nowAt = DateTime.now().millisecondsSinceEpoch;
    final attempt = _pairAttempts[address];
    final count = attempt != null && nowAt - attempt.$1 < 60000
        ? attempt.$2 + 1
        : 1;
    if (_pairAttempts.length > 256) _pairAttempts.clear();
    _pairAttempts[address] = (count == 1 ? nowAt : attempt!.$1, count);
    if (count > 10) {
      await _json(request, HttpStatus.tooManyRequests, {
        'error': 'Try pairing again in one minute',
      });
      return;
    }
    final body = await _readJson(request);
    if (_pairingCode == null || body['code']?.toString() != _pairingCode) {
      return await _json(request, HttpStatus.unauthorized, {
        'error': 'Invalid or expired pairing code',
      });
    }
    final name = body['name']?.toString().trim();
    final suppliedId = body['deviceId']?.toString().trim();
    if (name == null || name.isEmpty) {
      throw const FormatException('A device name is required.');
    }
    final rawToken = _randomBytes(32);
    final token = base64UrlEncode(rawToken);
    final tokenHash = sha256.convert(utf8.encode(token)).toString();
    final now = DateTime.now().millisecondsSinceEpoch;
    final deviceId = suppliedId == null || suppliedId.isEmpty
        ? stableId('$name::$tokenHash')
        : suppliedId;
    await database.upsertKnownDevice(
      KnownDevicesCompanion.insert(
        id: deviceId,
        name: name,
        tokenHash: tokenHash,
        approved: const drift.Value(true),
        createdAt: now,
        lastSeenAt: drift.Value(now),
        lastAddress: drift.Value(request.connectionInfo?.remoteAddress.address),
      ),
    );
    await LibraryAccessStore(database).approveCurrentLibraries(deviceId);
    regeneratePairingCode();
    request.response.cookies.add(
      Cookie('myvlc_session', '')
        ..path = '/v1'
        ..httpOnly = true
        ..sameSite = SameSite.strict
        ..maxAge = 0,
    );
    request.response.cookies.add(
      Cookie('myvlc_session', token)
        ..path = '/'
        ..httpOnly = true
        ..sameSite = SameSite.strict
        ..secure = request.requestedUri.scheme == 'https'
        ..maxAge = 30 * 24 * 60 * 60,
    );
    await _json(request, HttpStatus.created, {
      'deviceId': deviceId,
      'token': token,
    });
  }

  Future<Set<String>> _hostedLibraryIds() async =>
      (await database.select(database.libraries).get())
          .where(
            (library) =>
                !library.rootFolderPath.startsWith('remote:') &&
                !library.rootFolderPath.startsWith('import:'),
          )
          .map((library) => library.id)
          .toSet();

  Future<Map<String, Object?>> _hostedSnapshot({Set<String>? allowed}) =>
      database.transaction(() async {
        final snapshot = await database.exportSyncData();
        final localLibraries = (await _hostedLibraryIds()).intersection(
          allowed ?? await _hostedLibraryIds(),
        );
        List<Map<String, dynamic>> rows(String key) =>
            (snapshot[key] as List).cast<Map<String, dynamic>>();
        final libraries = rows(
          'libraries',
        ).where((row) => localLibraries.contains(row['id'])).toList();
        final sections = rows(
          'sections',
        ).where((row) => localLibraries.contains(row['libraryId'])).toList();
        final sectionLibraries = {
          for (final row in sections) row['id']: row['libraryId'],
        };
        final items = rows('items')
            .where(
              (row) =>
                  localLibraries.contains(row['libraryId']) &&
                  sectionLibraries[row['sectionId']] == row['libraryId'],
            )
            .toList();
        final itemLibraries = {
          for (final row in items) row['id']: row['libraryId'],
        };
        bool ownsItem(
          Map<String, dynamic> row,
          String libraryKey,
          String itemKey,
        ) =>
            localLibraries.contains(row[libraryKey]) &&
            (row[itemKey] == null ||
                itemLibraries[row[itemKey]] == row[libraryKey]);
        return {
          'schemaVersion': snapshot['schemaVersion'],
          'exportedAt': snapshot['exportedAt'],
          'protocolVersion': snapshot['protocolVersion'],
          'changeCursor': await SyncChangeJournal(database).head(),
          'capabilities': snapshot['capabilities'],
          'catalogRows': await CatalogIdentityStore(database).transportRows(
            libraries: localLibraries,
            itemIds: itemLibraries.keys.cast<String>().toSet(),
          ),
          'libraries': libraries,
          'sections': sections,
          'items': items,
          for (final key in ['playback', 'reading'])
            key: rows(
              key,
            ).where((row) => itemLibraries.containsKey(row['itemId'])).toList(),
          for (final key in ['notes', 'bookmarks'])
            key: rows(
              key,
            ).where((row) => ownsItem(row, 'libraryId', 'itemId')).toList(),
          'mediaRecords': rows('mediaRecords').where((row) {
            if (!ownsItem(row, 'library_id', 'item_id')) return false;
            if (['collection', 'playlist', 'album'].contains(row['kind'])) {
              final payload = jsonDecode(row['payload'] as String) as Map;
              return (payload['items'] as List).every(
                (id) => itemLibraries[id] == row['library_id'],
              );
            }
            return true;
          }).toList(),
        };
      });

  Future<void> _serveArtwork(
    HttpRequest request,
    String id,
    Set<String> allowed,
  ) async {
    final item = await database.getItemById(id);
    if (item == null || item.unavailable || !allowed.contains(item.libraryId))
      return _json(request, HttpStatus.notFound, {
        'error': 'Artwork unavailable',
      });
    try {
      final metadata = await MediaCatalogRepository(database).metadata(item);
      var path = await CatalogArtworkCache.instance.get(
        metadata['artworkUrl'] as String?,
      );
      if (path == null) {
        final source = await resolveApprovedMedia(database, item);
        final lease = _artwork.acquire(item.copyWith(filePath: source.path));
        try {
          path = await lease.future;
        } finally {
          lease.release();
        }
      }
      if (path == null) {
        return _json(request, HttpStatus.notFound, {
          'error': 'Artwork is not available for this format',
        });
      }
      final file = File(path), length = await File(path).length();
      if (length > 2 * 1024 * 1024) {
        return _json(request, HttpStatus.notFound, {
          'error': 'Artwork exceeds delivery limit',
        });
      }
      request.response.headers
        ..contentType = ContentType('image', 'png')
        ..contentLength = length;
      if (request.method == 'GET')
        await request.response.addStream(file.openRead());
      await request.response.close();
    } on MediaSourceException catch (error) {
      return _json(request, error.statusCode, {'error': error.message});
    } on FileSystemException {
      return _json(request, HttpStatus.notFound, {
        'error': 'Artwork is temporarily unavailable',
      });
    }
  }

  Future<void> _servePage(
    HttpRequest request,
    String id,
    String rawPage,
    Set<String> allowed,
  ) async {
    final item = await database.getItemById(id), number = int.tryParse(rawPage);
    if (item == null || item.unavailable || !allowed.contains(item.libraryId))
      return _json(request, HttpStatus.notFound, {'error': 'Page unavailable'});
    if (number == null || number < 1 || number > 10000)
      throw const FormatException('Invalid canonical page');
    if (_pageJobs >= 2)
      return _json(request, HttpStatus.serviceUnavailable, {
        'error': 'Page renderer is busy. Retry shortly.',
      });
    _pageJobs++;
    try {
      final file = await resolveApprovedMedia(database, item);
      late Uint8List bytes;
      ContentType type = ContentType('image', 'png');
      if (item.itemType == 'pdf') {
        final document = await PdfDocument.openFile(file.path);
        try {
          if (number > document.pages.length)
            throw const FormatException('Page is outside this document');
          final page = document.pages[number - 1], scale = 1024 / page.width;
          final height = (page.height * scale).round();
          if (height < 1 || height > 4096)
            throw const FormatException(
              'Page dimensions exceed the delivery budget',
            );
          final bitmap = await page.render(
            width: 1024,
            height: height,
            fullWidth: 1024,
            fullHeight: height.toDouble(),
          );
          if (bitmap == null)
            throw const FormatException('Page could not render');
          try {
            final image = await bitmap.createImage();
            try {
              final data = await image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              if (data == null)
                throw const FormatException('Page could not encode');
              bytes = data.buffer.asUint8List();
            } finally {
              image.dispose();
            }
          } finally {
            bitmap.dispose();
          }
        } finally {
          await document.dispose();
        }
      } else if (item.itemType == 'cbz') {
        final source = await ArchiveBookSource.open(file.path, epub: false);
        try {
          if (number > source.pageCount)
            throw const FormatException('Page is outside this comic');
          final page = await source.load(number);
          bytes = page.image!;
          type = _contentType(source.locator(number));
        } finally {
          await source.dispose();
        }
      } else {
        return _json(request, HttpStatus.unprocessableEntity, {
          'error':
              'Use the publication renderer or original file for this format',
        });
      }
      if (bytes.length > 32 * 1024 * 1024)
        throw const FormatException('Page exceeds delivery budget');
      request.response.headers
        ..contentType = type
        ..contentLength = bytes.length;
      if (request.method == 'GET') request.response.add(bytes);
      await request.response.close();
    } on MediaSourceException catch (error) {
      return _json(request, error.statusCode, {'error': error.message});
    } finally {
      _pageJobs--;
    }
  }

  Future<void> _catalogPage(HttpRequest request, Set<String> allowed) async {
    final args = request.uri.queryParameters;
    final library = args['library'];
    if (library != null && !allowed.contains(library))
      return _json(request, HttpStatus.forbidden, {
        'error': 'This library is not approved for browsing',
      });
    final limit = int.tryParse(args['limit'] ?? '60');
    if (limit == null ||
        limit < 1 ||
        limit > 100 ||
        (args['q']?.length ?? 0) > 512)
      throw const FormatException('Invalid catalog page limits');
    final clauses = <String>['i.unavailable=0'];
    final variables = <drift.Variable>[];
    final scope = library == null ? allowed : {library};
    if (scope.isEmpty)
      return _json(request, HttpStatus.ok, {
        'protocolVersion': 2,
        'items': [],
        'next': null,
      });
    clauses.add('i.library_id IN (${scope.map((_) => '?').join(',')})');
    variables.addAll(scope.map(drift.Variable.new));
    final type = args['type'];
    if (type == 'documents') {
      clauses.add("i.item_type NOT IN ('video','audio')");
    } else if (type != null) {
      clauses.add('i.item_type=?');
      variables.add(drift.Variable(type));
    }
    final query = args['q']?.trim() ?? '';
    if (query.isNotEmpty) {
      final terms = query
          .split(RegExp(r'\s+'))
          .take(8)
          .map((term) => '"${term.replaceAll('"', '""')}"*')
          .join(' AND ');
      clauses.add(
        'i.id IN (SELECT item_id FROM catalog_search WHERE catalog_search MATCH ?)',
      );
      variables.add(drift.Variable(terms));
    }
    final cursor = args['cursor'];
    if (cursor != null) {
      if (cursor.length > 4096)
        throw const FormatException('Invalid catalog cursor');
      final data = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(cursor))),
      );
      if (data is! Map ||
          data['title'] is! String ||
          data['id'] is! String ||
          data['library'] != library ||
          data['q'] != query ||
          data['type'] != type)
        throw const FormatException('Cursor does not match this query');
      clauses.add(
        '(COALESCE(s.title,i.title)>? OR (COALESCE(s.title,i.title)=? AND i.id>?))',
      );
      variables.addAll([
        drift.Variable(data['title'] as String),
        drift.Variable(data['title'] as String),
        drift.Variable(data['id'] as String),
      ]);
    }
    final rows = await database
        .customSelect(
          'SELECT i.*,COALESCE(s.title,i.title) AS catalog_title FROM items i LEFT JOIN catalog_search s ON s.item_id=i.id WHERE ${clauses.join(' AND ')} ORDER BY COALESCE(s.title,i.title),i.id LIMIT ?',
          variables: [...variables, drift.Variable(limit + 1)],
        )
        .get();
    final page = rows.take(limit).toList();
    final catalog = MediaCatalogRepository(database);
    final items = <Map<String, dynamic>>[];
    for (final row in page) {
      final item = database.items.map(row.data);
      final metadata = await catalog.metadata(item);
      items.add({
        ...item.toJson(),
        'filePath': '',
        'thumbnailPath': null,
        'fingerprint': null,
        'libraryKind': (await catalog.libraryKind(item.libraryId)).name,
        'metadata': {
          for (final key in MediaRecordContract.fields('metadata')!)
            if (metadata.containsKey(key)) key: metadata[key],
        },
        'playback': (await database.getPlaybackByItemId(item.id))?.toJson(),
        'reading': (await database.getReadingByItemId(item.id))?.toJson(),
      });
    }
    final next = rows.length > limit
        ? base64UrlEncode(
            utf8.encode(
              jsonEncode({
                'title': page.last.data['catalog_title'],
                'id': page.last.data['id'],
                'library': library,
                'q': query,
                'type': type,
              }),
            ),
          )
        : null;
    return _json(request, HttpStatus.ok, {
      'protocolVersion': 2,
      'items': items,
      'next': next,
      'limit': limit,
    });
  }

  Future<KnownDevice?> _authorise(HttpRequest request) async {
    final header = request.headers.value(HttpHeaders.authorizationHeader);
    String? token = header?.startsWith('Bearer ') == true
        ? header!.substring(7)
        : null;
    if (header == null) {
      for (final cookie in request.cookies) {
        if (cookie.name == 'myvlc_session') token = cookie.value;
      }
    }
    if (token == null || token.isEmpty) {
      await _json(request, HttpStatus.unauthorized, {
        'error': 'Approval required',
      });
      return null;
    }
    final tokenHash = sha256.convert(utf8.encode(token)).toString();
    final device = await database.getDeviceByTokenHash(tokenHash);
    if (device == null) {
      await _json(request, HttpStatus.forbidden, {
        'error': 'Device access has been revoked',
      });
    }
    return device;
  }

  Future<void> _serveMedia(
    HttpRequest request,
    String itemId,
    Set<String> allowed,
  ) async {
    final item = await database.getItemById(itemId);
    if (item == null || item.unavailable || !allowed.contains(item.libraryId)) {
      return await _json(request, HttpStatus.notFound, {
        'error': 'Media unavailable',
      });
    }
    final File file;
    try {
      file = await resolveApprovedMedia(database, item);
    } on MediaSourceException catch (error) {
      return await _json(request, error.statusCode, {'error': error.message});
    }
    if (item.itemType == 'html') {
      request.response.headers.set(
        'Content-Security-Policy',
        "sandbox; default-src 'none'; style-src 'unsafe-inline'; img-src data:",
      );
    }
    final length = await file.length();
    if (length == 0) {
      request.response.headers
        ..contentType = _contentType(item.filename)
        ..contentLength = 0;
      return request.response.close();
    }
    var start = 0;
    var end = length - 1;
    final range = request.headers.value(HttpHeaders.rangeHeader);
    if (range != null) {
      final match = RegExp(r'^bytes=(\d*)-(\d*)$').firstMatch(range.trim());
      if (match == null ||
          (match.group(1)!.isEmpty && match.group(2)!.isEmpty)) {
        return _rangeNotSatisfiable(request, length);
      }
      if (match.group(1)!.isEmpty) {
        final suffix = int.tryParse(match.group(2)!);
        if (suffix == null || suffix <= 0) {
          return _rangeNotSatisfiable(request, length);
        }
        start = (length - suffix).clamp(0, length - 1);
      } else {
        final parsedStart = int.tryParse(match.group(1)!);
        if (parsedStart == null || parsedStart >= length) {
          return _rangeNotSatisfiable(request, length);
        }
        start = parsedStart;
        if (match.group(2)!.isNotEmpty) {
          final parsedEnd = int.tryParse(match.group(2)!);
          if (parsedEnd == null || parsedEnd < start) {
            return _rangeNotSatisfiable(request, length);
          }
          end = parsedEnd.clamp(start, length - 1);
        }
      }
      request.response.statusCode = HttpStatus.partialContent;
      request.response.headers.set(
        HttpHeaders.contentRangeHeader,
        'bytes $start-$end/$length',
      );
    }
    request.response.headers
      ..contentType = _contentType(item.filename)
      ..set(HttpHeaders.acceptRangesHeader, 'bytes')
      ..contentLength = end - start + 1;
    if (request.method == 'HEAD') return request.response.close();
    await request.response.addStream(file.openRead(start, end + 1));
    await request.response.close();
  }

  Future<void> _rangeNotSatisfiable(HttpRequest request, int length) async {
    request.response
      ..statusCode = HttpStatus.requestedRangeNotSatisfiable
      ..headers.set(HttpHeaders.contentRangeHeader, 'bytes */$length');
    await request.response.close();
  }

  Future<Map<String, dynamic>> _readJson(HttpRequest request) async {
    const maximumBytes = 10 * 1024 * 1024;
    if (request.contentLength > maximumBytes) {
      throw const _PayloadTooLargeException();
    }
    final bytes = BytesBuilder(copy: false);
    var length = 0;
    await for (final chunk in request) {
      length += chunk.length;
      if (length > maximumBytes) throw const _PayloadTooLargeException();
      bytes.add(chunk);
    }
    final text = utf8.decode(bytes.takeBytes());
    final value = jsonDecode(text);
    if (value is! Map<String, dynamic>) {
      throw const FormatException('Expected a JSON object.');
    }
    return value;
  }

  Future<void> _json(HttpRequest request, int status, Object body) async {
    request.response
      ..statusCode = status
      ..headers.contentType = ContentType.json
      ..write(jsonEncode(body));
    await request.response.close();
  }

  List<int> _randomBytes(int length) =>
      List.generate(length, (_) => _random.nextInt(256));

  ContentType _contentType(String filename) =>
      switch (filename.toLowerCase().split('.').last) {
        'mp4' || 'm4v' => ContentType('video', 'mp4'),
        'mov' => ContentType('video', 'quicktime'),
        'mkv' => ContentType('video', 'x-matroska'),
        'webm' => ContentType('video', 'webm'),
        'mp3' => ContentType('audio', 'mpeg'),
        'm4a' || 'aac' => ContentType('audio', 'mp4'),
        'wav' => ContentType('audio', 'wav'),
        'flac' => ContentType('audio', 'flac'),
        'ogg' || 'opus' => ContentType('audio', 'ogg'),
        'pdf' => ContentType('application', 'pdf'),
        'jpg' || 'jpeg' => ContentType('image', 'jpeg'),
        'png' => ContentType('image', 'png'),
        'webp' => ContentType('image', 'webp'),
        'gif' => ContentType('image', 'gif'),
        'txt' => ContentType.text,
        'html' || 'htm' => ContentType.html,
        _ => ContentType.binary,
      };

  void _emit(LanSyncState value) {
    _state = value;
    if (!_states.isClosed) _states.add(value);
  }
}

class _PayloadTooLargeException implements Exception {
  const _PayloadTooLargeException();
}
