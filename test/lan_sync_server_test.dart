import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_stream/data/db/app_database.dart';
import 'package:study_stream/data/sync/lan_sync_server.dart';

void main() {
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
