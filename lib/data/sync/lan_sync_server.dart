import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart' as drift;

import '../../core/utils/id_utils.dart';
import '../db/app_database.dart';
import 'sync_snapshot_merger.dart';

class LanSyncState {
  const LanSyncState({
    required this.running,
    this.port,
    this.pairingCode,
    this.error,
  });

  final bool running;
  final int? port;
  final String? pairingCode;
  final String? error;
}

class LanSyncServer {
  LanSyncServer(this.database);

  final AppDatabase database;
  final _states = StreamController<LanSyncState>.broadcast();
  final _random = Random.secure();
  HttpServer? _server;
  StreamSubscription<HttpRequest>? _requestSubscription;
  Timer? _pairingTimer;
  String? _pairingCode;

  LanSyncState _state = const LanSyncState(running: false);

  LanSyncState get state => _state;
  Stream<LanSyncState> get states => _states.stream;

  Future<void> start({int port = 0}) async {
    if (_server != null) return;
    try {
      final server = await HttpServer.bind(
        InternetAddress.anyIPv4,
        port,
        shared: true,
      );
      _server = server;
      regeneratePairingCode();
      _requestSubscription = server.listen(
        (request) => unawaited(_handle(request)),
        onError: (Object error, StackTrace stack) => _emit(
          LanSyncState(
            running: true,
            port: server.port,
            error: error.toString(),
          ),
        ),
      );
      _emit(
        LanSyncState(
          running: true,
          port: server.port,
          pairingCode: _pairingCode,
        ),
      );
    } catch (error) {
      _emit(LanSyncState(running: false, error: error.toString()));
      rethrow;
    }
  }

  void regeneratePairingCode() {
    _pairingCode = (100000 + _random.nextInt(900000)).toString();
    _pairingTimer?.cancel();
    _pairingTimer = Timer(const Duration(minutes: 10), () {
      _pairingCode = null;
      _emit(LanSyncState(running: true, port: _server?.port));
    });
    if (_server != null) {
      _emit(
        LanSyncState(
          running: true,
          port: _server?.port,
          pairingCode: _pairingCode,
        ),
      );
    }
  }

  Future<void> stop() async {
    _pairingTimer?.cancel();
    await _requestSubscription?.cancel();
    await _server?.close(force: true);
    _server = null;
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
      if (request.method == 'GET' && request.uri.path == '/v1/health') {
        return _json(request, HttpStatus.ok, {
          'service': 'StudyStream',
          'version': 1,
        });
      }
      if (request.method == 'POST' && request.uri.path == '/v1/pair') {
        return _pair(request);
      }
      final device = await _authorise(request);
      if (device == null) return;
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
      if (request.method == 'GET' && request.uri.path == '/v1/snapshot') {
        final snapshot = await database.exportSyncData();
        await database.markDeviceSynced(
          device.id,
          address: request.connectionInfo?.remoteAddress.address,
        );
        return _json(request, HttpStatus.ok, snapshot);
      }
      if (request.method == 'POST' && request.uri.path == '/v1/snapshot') {
        final body = await _readJson(request);
        await SyncSnapshotMerger(database).merge(body);
        await database.markDeviceSynced(
          device.id,
          address: request.connectionInfo?.remoteAddress.address,
        );
        return _json(request, HttpStatus.ok, {'status': 'merged'});
      }
      if ((request.method == 'GET' || request.method == 'HEAD') &&
          path.length == 3 &&
          path[0] == 'v1' &&
          path[1] == 'media') {
        return _serveMedia(request, path[2]);
      }
      _json(request, HttpStatus.notFound, {'error': 'Not found'});
    } on FormatException catch (error) {
      _json(request, HttpStatus.badRequest, {'error': error.message});
    } on _PayloadTooLargeException {
      _json(request, HttpStatus.requestEntityTooLarge, {
        'error': 'Request body is too large',
      });
    } catch (_) {
      _json(request, HttpStatus.internalServerError, {
        'error': 'Request failed',
      });
    }
  }

  Future<void> _pair(HttpRequest request) async {
    final body = await _readJson(request);
    if (_pairingCode == null || body['code']?.toString() != _pairingCode) {
      return _json(request, HttpStatus.unauthorized, {
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
    regeneratePairingCode();
    _json(request, HttpStatus.created, {'deviceId': deviceId, 'token': token});
  }

  Future<KnownDevice?> _authorise(HttpRequest request) async {
    final header = request.headers.value(HttpHeaders.authorizationHeader);
    if (header == null || !header.startsWith('Bearer ')) {
      _json(request, HttpStatus.unauthorized, {'error': 'Approval required'});
      return null;
    }
    final tokenHash = sha256
        .convert(utf8.encode(header.substring(7)))
        .toString();
    final device = await database.getDeviceByTokenHash(tokenHash);
    if (device == null) {
      _json(request, HttpStatus.forbidden, {
        'error': 'Device access has been revoked',
      });
    }
    return device;
  }

  Future<void> _serveMedia(HttpRequest request, String itemId) async {
    final item = await database.getItemById(itemId);
    if (item == null || item.unavailable) {
      return _json(request, HttpStatus.notFound, {
        'error': 'Media unavailable',
      });
    }
    final library = await database.getLibraryById(item.libraryId);
    if (library == null) {
      return _json(request, HttpStatus.notFound, {
        'error': 'Library unavailable',
      });
    }
    if (!await File(item.filePath).exists() ||
        !await Directory(library.rootFolderPath).exists()) {
      return _json(request, HttpStatus.notFound, {
        'error': 'Media unavailable',
      });
    }
    final canonicalRoot = await Directory(
      library.rootFolderPath,
    ).resolveSymbolicLinks();
    final canonicalFile = await File(item.filePath).resolveSymbolicLinks();
    if (canonicalFile != canonicalRoot &&
        !canonicalFile.startsWith('$canonicalRoot${Platform.pathSeparator}')) {
      return _json(request, HttpStatus.forbidden, {
        'error': 'File is outside the approved library',
      });
    }
    final file = File(item.filePath);
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

  void _json(HttpRequest request, int status, Object body) {
    request.response
      ..statusCode = status
      ..headers.contentType = ContentType.json
      ..write(jsonEncode(body))
      ..close();
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
