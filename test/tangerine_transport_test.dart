import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_stream/data/db/app_database.dart';
import 'package:study_stream/data/sync/lan_sync_server.dart';

import 'fixtures/tangerine_preservation_fixture.dart';

void main() {
  late AppDatabase db;
  late Directory temporary;
  late Directory secondary;
  late LanSyncServer server;
  late HttpClient client;
  late Uri base;
  late String token;

  Future<HttpClientResponse> request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    String? range,
  }) async {
    final req = await client.openUrl(method, base.resolve(path));
    req.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
    if (range != null) req.headers.set(HttpHeaders.rangeHeader, range);
    if (body != null) {
      req.headers.contentType = ContentType.json;
      req.write(jsonEncode(body));
    }
    return req.close();
  }

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    temporary = await Directory.systemTemp.createTemp('tangerine-transport-');
    secondary = await Directory('${temporary.path}/secondary').create();
    await File('${secondary.path}/movie.mp4').writeAsBytes([10, 20, 30, 40]);
    await File('${secondary.path}/book.pdf').writeAsBytes([1, 2, 3, 4]);
    await seedTangerinePreservation(
      db,
      legacyRoot: '${temporary.path}/disconnected',
      secondaryRoot: secondary.path,
    );
    server = LanSyncServer(db);
    client = HttpClient();
    await server.start();
    base = Uri.parse('http://127.0.0.1:${server.state.port}');
    final req = await client.postUrl(base.resolve('/v1/pair'));
    req.headers.contentType = ContentType.json;
    req.write(
      jsonEncode({'code': server.state.pairingCode, 'name': 'P0 fixture'}),
    );
    final res = await req.close();
    expect(res.statusCode, HttpStatus.created);
    token =
        (jsonDecode(await utf8.decoder.bind(res).join()) as Map)['token']
            as String;
  });
  tearDown(() async {
    client.close(force: true);
    await server.dispose();
    await db.close();
    await temporary.delete(recursive: true);
  });

  test(
    'healthy secondary source serves GET, HEAD and ranges with a disconnected legacy root',
    () async {
      final response = await request(
        'GET',
        '/v1/media/local-video',
        range: 'bytes=1-2',
      );
      expect(response.statusCode, HttpStatus.partialContent);
      expect(
        response.headers.value(HttpHeaders.contentRangeHeader),
        'bytes 1-2/4',
      );
      expect(await response.fold<List<int>>([], (a, b) => [...a, ...b]), [
        20,
        30,
      ]);
      final head = await request('HEAD', '/v1/media/local-video');
      expect(head.statusCode, HttpStatus.ok);
      expect(head.contentLength, 4);
      expect(await head.fold<List<int>>([], (a, b) => [...a, ...b]), isEmpty);
      final suffix = await request(
        'GET',
        '/v1/media/local-video',
        range: 'bytes=-1',
      );
      expect(suffix.statusCode, HttpStatus.partialContent);
      expect(await suffix.fold<List<int>>([], (a, b) => [...a, ...b]), [40]);
      final bad = await request(
        'GET',
        '/v1/media/local-video',
        range: 'bytes=10-20',
      );
      expect(bad.statusCode, HttpStatus.requestedRangeNotSatisfiable);
      await bad.drain<void>();
    },
  );

  test(
    'source ownership rejects foreign roots, traversal, symlink escapes and rehosting',
    () async {
      final original = (await db.getItemById('local-video'))!;
      final outside = await File(
        '${temporary.path}/outside.mp4',
      ).writeAsBytes([99]);
      final link = await Link(
        '${secondary.path}/escape.mp4',
      ).create(outside.path);
      final otherRoot = await Directory('${temporary.path}/other').create();
      final otherFile = await File(
        '${otherRoot.path}/movie.mp4',
      ).writeAsBytes([98]);
      await db.customStatement(
        'INSERT INTO library_sources(id,library_id,root_path,namespace,updated_at) VALUES(?,?,?,?,?)',
        ['other', 'local', otherRoot.path, '@sources/other', 1],
      );
      for (final (path, relative) in [
        (outside.path, original.relativePath),
        (link.path, original.relativePath),
        (otherFile.path, original.relativePath),
        ('${secondary.path}/movie.mp4', '@sources/missing/movie.mp4'),
        ('${secondary.path}/movie.mp4', '@sources/secondary/../movie.mp4'),
      ]) {
        await db.upsertItem(
          original
              .copyWith(filePath: path, relativePath: relative)
              .toCompanion(true),
        );
        final response = await request('GET', '/v1/media/local-video');
        expect(
          response.statusCode,
          HttpStatus.forbidden,
          reason: '$path under $relative',
        );
        await response.drain<void>();
      }
      for (final id in ['mirror-video', 'imports-video']) {
        final item = (await db.getItemById(id))!;
        await db.upsertItem(
          item
              .copyWith(filePath: '${secondary.path}/movie.mp4')
              .toCompanion(true),
        );
        final response = await request('GET', '/v1/media/$id');
        expect(response.statusCode, HttpStatus.notFound);
        await response.drain<void>();
      }
    },
  );

  test(
    'hosted snapshots scope all derived records and retain local-only metadata in backups',
    () async {
      final response = await request('GET', '/v1/snapshot');
      expect(response.statusCode, HttpStatus.ok);
      final snapshot =
          jsonDecode(await utf8.decoder.bind(response).join())
              as Map<String, dynamic>;
      expect(snapshot.keys.toSet(), {
        'schemaVersion',
        'exportedAt',
        'protocolVersion',
        'libraries',
        'sections',
        'items',
        'playback',
        'reading',
        'notes',
        'bookmarks',
        'mediaRecords',
      });
      expect((snapshot['libraries'] as List).map((r) => r['id']), ['local']);
      for (final key in ['sections', 'items', 'notes', 'bookmarks']) {
        expect(
          (snapshot[key] as List).every((r) => r['libraryId'] == 'local'),
          isTrue,
          reason: key,
        );
      }
      for (final key in ['playback', 'reading']) {
        expect(
          (snapshot[key] as List).every(
            (r) => (r['itemId'] as String).startsWith('local-'),
          ),
          isTrue,
          reason: key,
        );
      }
      final records = (snapshot['mediaRecords'] as List)
          .cast<Map<String, dynamic>>();
      expect(records, hasLength(5));
      expect(records.every((r) => r['library_id'] == 'local'), isTrue);
      expect(jsonEncode(snapshot), isNot(contains(temporary.path)));
      expect(jsonEncode(snapshot), isNot(contains('private.json')));
      final backup = await db.exportData();
      expect(jsonEncode(backup['mediaRecords']), contains('private.json'));
      expect(backup, contains('sources'));
      expect(backup, contains('settings'));
    },
  );

  test(
    'paired edits cannot update unhosted progress, notes or catalog records',
    () async {
      final snapshot = await db.exportData();
      final response = await request(
        'POST',
        '/v1/snapshot',
        body: {
          ...snapshot,
          'playback': (snapshot['playback'] as List)
              .cast<Map<String, dynamic>>()
              .map(
                (r) => {
                  ...r,
                  'resumePositionSeconds': 90.0,
                  'lastEventAt': 999,
                  'version': 9,
                },
              )
              .toList(),
          'notes': (snapshot['notes'] as List)
              .cast<Map<String, dynamic>>()
              .map(
                (r) => {
                  ...r,
                  'content': 'Edited',
                  'updatedAt': 999,
                  'version': 9,
                },
              )
              .toList(),
          'mediaRecords': (snapshot['mediaRecords'] as List)
              .cast<Map<String, dynamic>>()
              .map((r) => {...r, 'updated_at': (r['updated_at'] as int) + 1})
              .toList(),
        },
      );
      expect(response.statusCode, HttpStatus.ok);
      await response.drain<void>();
      expect(
        (await db.getPlaybackByItemId('mirror-video'))?.resumePositionSeconds,
        42,
      );
      expect(
        (await db.getPlaybackByItemId('imports-video'))?.resumePositionSeconds,
        42,
      );
      expect(
        (await db.watchNotes(itemId: 'mirror-book').first).single.content,
        'mirror page note',
      );
      expect(
        (await db.watchNotes(itemId: 'local-book').first).single.content,
        'Edited',
      );
      final rows = await db.exportMediaRows('media_records');
      final old = (snapshot['mediaRecords'] as List)
          .cast<Map<String, dynamic>>();
      for (final row in rows.where((r) => r['library_id'] != 'local')) {
        expect(row, old.firstWhere((r) => r['id'] == row['id']));
      }
    },
  );

  test(
    'unavailable sources fail cleanly and pairing revocation still blocks bytes',
    () async {
      await db.customStatement(
        'UPDATE library_sources SET unavailable = 1 WHERE id = ?',
        ['secondary'],
      );
      final missing = await request('GET', '/v1/media/local-video');
      expect(missing.statusCode, HttpStatus.notFound);
      await missing.drain<void>();
      await db.customStatement(
        'UPDATE library_sources SET unavailable = 0 WHERE id = ?',
        ['secondary'],
      );
      await db.revokeDevice((await db.watchKnownDevices().first).single.id);
      final revoked = await request('GET', '/v1/media/local-video');
      expect(revoked.statusCode, HttpStatus.forbidden);
      await revoked.drain<void>();
    },
  );
}
