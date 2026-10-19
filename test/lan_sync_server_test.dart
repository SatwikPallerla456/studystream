import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_stream/data/db/app_database.dart';
import 'package:study_stream/data/sync/lan_sync_server.dart';

void main() {
  test(
    'browser pairing cookies protect catalogue, range reads, study writes, and logout',
    () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      final root = await Directory.systemTemp.createTemp('myvlc-browser-');
      final file = await File(
        '${root.path}/lesson.mp4',
      ).writeAsBytes([1, 2, 3, 4]);
      await _seed(database, root.path, file.path);
      await database.upsertLibrary(
        LibrariesCompanion.insert(
          id: 'upstream',
          title: 'Mirrored server',
          rootFolderPath: 'remote:upstream',
          createdAt: 1,
          updatedAt: 1,
        ),
      );
      final server = LanSyncServer(database);
      final client = HttpClient();
      addTearDown(() async {
        client.close(force: true);
        await server.dispose();
        await database.close();
        await root.delete(recursive: true);
      });
      await Future.wait([
        server.start(name: 'Living room'),
        server.start(name: 'Living room'),
      ]);
      final base = Uri.parse('http://127.0.0.1:${server.state.port}');
      final page = await (await client.getUrl(base)).close();
      expect(page.statusCode, HttpStatus.ok);
      expect(
        await utf8.decoder.bind(page).join(),
        contains('<title>Tangerine</title>'),
      );

      final unauthorised = await (await client.getUrl(
        base.resolve('/v1/session'),
      )).close();
      expect(unauthorised.statusCode, HttpStatus.unauthorized);
      await unauthorised.drain<void>();

      final pairing = await client.postUrl(base.resolve('/v1/pair'));
      pairing.headers.contentType = ContentType.json;
      pairing.write(
        jsonEncode({
          'name': 'Browser player',
          'code': server.state.pairingCode,
        }),
      );
      final paired = await pairing.close();
      final cookie = paired.cookies.single;
      final body =
          jsonDecode(await utf8.decoder.bind(paired).join())
              as Map<String, dynamic>;
      expect(cookie.name, 'myvlc_session');
      expect(cookie.httpOnly, isTrue);
      expect(cookie.sameSite, SameSite.strict);
      expect(cookie.path, '/v1');

      Future<HttpClientRequest> authenticated(
        String method,
        String path,
      ) async {
        final request = await client.openUrl(method, base.resolve(path));
        request.cookies.add(Cookie(cookie.name, cookie.value));
        return request;
      }

      final session = await (await authenticated('GET', '/v1/session')).close();
      expect(jsonDecode(await utf8.decoder.bind(session).join()), {
        'deviceId': body['deviceId'],
        'name': 'Living room',
      });
      final catalogue = await (await authenticated(
        'GET',
        '/v1/snapshot',
      )).close();
      final catalogueData =
          jsonDecode(await utf8.decoder.bind(catalogue).join())
              as Map<String, dynamic>;
      expect((catalogueData['libraries'] as List).map((row) => row['id']), [
        'library',
      ]);

      final range = await authenticated('GET', '/v1/media/item');
      range.headers.set(HttpHeaders.rangeHeader, 'bytes=1-2');
      final ranged = await range.close();
      expect(ranged.statusCode, HttpStatus.partialContent);
      expect(
        await ranged.fold<List<int>>(
          [],
          (bytes, chunk) => [...bytes, ...chunk],
        ),
        [2, 3],
      );

      final note = await authenticated('POST', '/v1/snapshot');
      note.headers.contentType = ContentType.json;
      note.write(
        jsonEncode({
          'schemaVersion': database.schemaVersion,
          'notes': [
            {
              'id': 'browser-note',
              'libraryId': 'library',
              'itemId': 'item',
              'content': 'From the browser',
              'positionSeconds': 1.5,
              'pageNumber': null,
              'createdAt': 10,
              'updatedAt': 10,
              'deviceId': body['deviceId'],
              'version': 1,
              'deleted': false,
            },
          ],
        }),
      );
      final saved = await note.close();
      expect(saved.statusCode, HttpStatus.ok);
      await saved.drain<void>();
      expect(
        (await database.select(database.notes).get()).single.content,
        'From the browser',
      );

      final logout = await (await authenticated('POST', '/v1/logout')).close();
      expect(logout.statusCode, HttpStatus.ok);
      expect(logout.cookies.single.maxAge, 0);
      await logout.drain<void>();
      final revoked = await (await authenticated(
        'GET',
        '/v1/media/item',
      )).close();
      expect(revoked.statusCode, HttpStatus.forbidden);
      await revoked.drain<void>();
    },
  );

  test('requires pairing, issues a token, and honours revocation', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    final root = await Directory.systemTemp.createTemp('study-stream-sync-');
    final media = await File(
      '${root.path}/lesson.mp4',
    ).writeAsBytes([1, 2, 3, 4]);
    await _seed(database, root.path, media.path);
    final server = LanSyncServer(database);
    final client = HttpClient();
    addTearDown(() async {
      client.close(force: true);
      await server.dispose();
      await database.close();
      await root.delete(recursive: true);
    });
    await server.start();
    final base = Uri.parse('http://127.0.0.1:${server.state.port}');

    final unauthorised = await client
        .getUrl(base.resolve('/v1/snapshot'))
        .then((r) => r.close());
    expect(unauthorised.statusCode, HttpStatus.unauthorized);

    final pairRequest = await client.postUrl(base.resolve('/v1/pair'));
    pairRequest.headers.contentType = ContentType.json;
    pairRequest.write(
      jsonEncode({'code': server.state.pairingCode, 'name': 'Test phone'}),
    );
    final pairResponse = await pairRequest.close();
    final pairBody =
        jsonDecode(await utf8.decoder.bind(pairResponse).join())
            as Map<String, dynamic>;
    expect(pairResponse.statusCode, HttpStatus.created);

    final snapshotRequest = await client.getUrl(base.resolve('/v1/snapshot'));
    snapshotRequest.headers.set(
      HttpHeaders.authorizationHeader,
      'Bearer ${pairBody['token']}',
    );
    final snapshotResponse = await snapshotRequest.close();
    expect(snapshotResponse.statusCode, HttpStatus.ok);
    final snapshot =
        jsonDecode(await utf8.decoder.bind(snapshotResponse).join())
            as Map<String, dynamic>;
    expect(snapshot, isNot(contains('settings')));
    expect((snapshot['libraries'] as List).single['rootFolderPath'], isEmpty);
    expect((snapshot['sections'] as List).single['folderPath'], isEmpty);
    expect((snapshot['items'] as List).single['filePath'], isEmpty);

    final rangeRequest = await client.getUrl(base.resolve('/v1/media/item'));
    rangeRequest.headers
      ..set(HttpHeaders.authorizationHeader, 'Bearer ${pairBody['token']}')
      ..set(HttpHeaders.rangeHeader, 'bytes=1-2');
    final rangeResponse = await rangeRequest.close();
    expect(rangeResponse.statusCode, HttpStatus.partialContent);
    expect(await rangeResponse.fold<List<int>>([], (a, b) => [...a, ...b]), [
      2,
      3,
    ]);

    final invalidRangeRequest = await client.getUrl(
      base.resolve('/v1/media/item'),
    );
    invalidRangeRequest.headers
      ..set(HttpHeaders.authorizationHeader, 'Bearer ${pairBody['token']}')
      ..set(HttpHeaders.rangeHeader, 'bytes=99-100');
    final invalidRangeResponse = await invalidRangeRequest.close();
    expect(
      invalidRangeResponse.statusCode,
      HttpStatus.requestedRangeNotSatisfiable,
    );
    await invalidRangeResponse.drain<void>();

    final knownDevice = (await database.watchKnownDevices().first).single;
    expect(knownDevice.lastSyncAt, isNotNull);

    await database.revokeDevice(pairBody['deviceId'] as String);
    final revokedRequest = await client.getUrl(base.resolve('/v1/snapshot'));
    revokedRequest.headers.set(
      HttpHeaders.authorizationHeader,
      'Bearer ${pairBody['token']}',
    );
    final revokedResponse = await revokedRequest.close();
    expect(revokedResponse.statusCode, HttpStatus.forbidden);
  });
}

Future<void> _seed(
  AppDatabase database,
  String rootPath,
  String mediaPath,
) async {
  await database.upsertLibrary(
    LibrariesCompanion.insert(
      id: 'library',
      title: 'Course',
      rootFolderPath: rootPath,
      createdAt: 1,
      updatedAt: 1,
    ),
  );
  await database.upsertSection(
    SectionsCompanion.insert(
      id: 'section',
      libraryId: 'library',
      title: 'Module',
      orderIndex: 0,
      folderPath: rootPath,
    ),
  );
  await database.upsertItem(
    ItemsCompanion.insert(
      id: 'item',
      libraryId: 'library',
      sectionId: 'section',
      title: 'Lesson',
      filename: 'lesson.mp4',
      filePath: mediaPath,
      relativePath: 'lesson.mp4',
      itemType: 'video',
      orderIndex: 0,
    ),
  );
}
