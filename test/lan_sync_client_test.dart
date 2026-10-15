import 'dart:convert';
import 'dart:io';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_stream/data/db/app_database.dart';
import 'package:study_stream/data/indexer/library_indexer.dart';
import 'package:study_stream/data/sync/lan_sync_client.dart';
import 'package:study_stream/data/sync/lan_sync_server.dart';

class MemoryCredentials implements CredentialStore {
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String next) async {
    value = next;
  }

  @override
  Future<void> clear() async {
    value = null;
  }
}

void main() {
  test(
    'pair, browse, authenticated stream, offline edit, reconnect, duplicate sync, and revoke',
    () async {
      final root = await Directory.systemTemp.createTemp('studystream-client-');
      final hostDb = AppDatabase.forTesting(
        NativeDatabase(File('${root.path}/host.sqlite')),
      );
      final clientFile = File('${root.path}/client.sqlite');
      var clientDb = AppDatabase.forTesting(NativeDatabase(clientFile));
      final source = await Directory('${root.path}/media').create();
      await File('test/fixtures/lesson.wav').copy('${source.path}/lesson.wav');
      final libraryId = (await LibraryIndexer(hostDb).scanRootFolder(
        rootFolderPath: source.path,
        title: 'Remote course',
      )).libraryId;
      final item = (await hostDb.getItemsForLibrary(libraryId)).single;
      final server = LanSyncServer(hostDb);
      final credentials = MemoryCredentials();
      var client = LanSyncClient(clientDb, credentials: credentials);
      final http = HttpClient();
      addTearDown(() async {
        http.close(force: true);
        await client.dispose();
        await server.dispose();
        await clientDb.close();
        await hostDb.close();
        await root.delete(recursive: true);
      });
      await server.start();
      final port = server.state.port!;
      final address = 'http://127.0.0.1:$port';
      await client.pair(
        address: address,
        code: server.state.pairingCode!,
        name: 'Test companion',
      );
      expect(client.state.phase, ConnectionPhase.connected);
      final remoteItem = (await clientDb.getItemById(item.id))!;
      expect(remoteItem.filePath, 'remote:${item.id}');
      expect(client.state.lastSyncAt, isNotNull);
      final media = await client.sourceFor(remoteItem);
      final request = await http.getUrl(media.uri);
      media.headers.forEach(request.headers.set);
      request.headers.set(HttpHeaders.rangeHeader, 'bytes=0-11');
      final response = await request.close();
      expect(response.statusCode, HttpStatus.partialContent);
      final header = await response.fold<List<int>>(
        [],
        (bytes, chunk) => bytes..addAll(chunk),
      );
      expect(ascii.decode(header.sublist(0, 4)), 'RIFF');
      await server.stop();
      await clientDb.setItemCompletion(item: remoteItem, completed: true);
      final deviceId = await clientDb.getDeviceId();
      await clientDb.upsertNote(
        NotesCompanion.insert(
          id: 'offline',
          libraryId: libraryId,
          itemId: Value(item.id),
          content: 'An offline note',
          createdAt: 1,
          updatedAt: 2,
          deviceId: deviceId,
        ),
      );
      await client.sync();
      expect(client.state.phase, ConnectionPhase.retrying);
      await server.start(port: port);
      await client.states
          .firstWhere((state) => state.phase == ConnectionPhase.connected)
          .timeout(const Duration(seconds: 10));
      expect(
        (await hostDb.watchNotes().first).single.content,
        'An offline note',
      );
      await client.dispose();
      await clientDb.close();
      clientDb = AppDatabase.forTesting(NativeDatabase(clientFile));
      client = LanSyncClient(clientDb, credentials: credentials);
      expect(await clientDb.getDeviceId(), deviceId);
      await server.start(port: port);
      await client.restore();
      expect(client.state.phase, ConnectionPhase.connected);
      expect((await hostDb.getPlaybackByItemId(item.id))!.completed, isTrue);
      expect(
        (await hostDb.watchNotes().first).single.content,
        'An offline note',
      );
      await client.sync();
      await client.sync();
      expect(await hostDb.watchNotes().first, hasLength(1));
      final device = (await hostDb.watchKnownDevices().first).single;
      await hostDb.revokeDevice(device.id);
      await client.sync();
      expect(client.state.phase, ConnectionPhase.error);
      expect(client.state.message, contains('revoked'));
      await client.disconnect(forget: true);
      expect(credentials.value, isNull);
    },
  );

  test(
    'rejects addresses with credentials, redirects, paths or unsupported schemes',
    () {
      for (final address in [
        'ftp://host',
        'http://user:secret@host',
        'http://host/path',
        'http://host?a=1',
      ]) {
        expect(
          () => LanSyncClient.validateAddress(address),
          throwsFormatException,
        );
      }
      expect(
        LanSyncClient.validateAddress('192.168.1.2:1234').host,
        '192.168.1.2',
      );
    },
  );
}
