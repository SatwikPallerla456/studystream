import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_stream/data/db/app_database.dart';
import 'package:study_stream/data/playback/remote_playback_controller.dart';
import 'package:study_stream/data/sync/lan_sync_server.dart';

void main() {
  test(
    'host remote requires pairing and local opt-in; revocation removes control',
    () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      final controller = RemotePlaybackController();
      final actions = <String>[];
      controller.attach(
        status: () => {'active': true, 'title': 'Synthetic fixture'},
        perform: (action, value) async {
          actions.add(action);
        },
      );
      final server = LanSyncServer(database, playbackController: controller);
      final client = HttpClient();
      addTearDown(() async {
        client.close(force: true);
        await server.dispose();
        await database.close();
      });
      await server.start();
      final base = Uri.parse('http://127.0.0.1:${server.state.port}');
      Future<HttpClientResponse> command({
        String? token,
        String action = 'play',
        Object? value,
      }) async {
        final request = await client.postUrl(base.resolve('/v1/playback'));
        if (token != null) {
          request.headers.set('Authorization', 'Bearer $token');
        }
        request.headers.contentType = ContentType.json;
        request.write(
          jsonEncode({'action': action, 'value': ?value}),
        );
        return request.close();
      }

      final unauthenticated = await command();
      expect(unauthenticated.statusCode, 401);
      await unauthenticated.drain<void>();
      final request = await client.postUrl(base.resolve('/v1/pair'));
      request.headers.contentType = ContentType.json;
      request.write(
        jsonEncode({
          'name': 'Synthetic remote',
          'code': server.state.pairingCode,
        }),
      );
      final paired = await request.close();
      final credentials =
          jsonDecode(await utf8.decoder.bind(paired).join()) as Map;
      final token = credentials['token'] as String;
      final disabled = await command(token: token);
      expect(disabled.statusCode, 409);
      await disabled.drain<void>();
      expect(actions, isEmpty);
      await database.setSetting('sync.allowPlaybackControl', 'true');
      final applied = await command(token: token);
      expect(applied.statusCode, 200);
      await applied.drain<void>();
      expect(actions, ['play']);
      final invalid = await command(token: token, action: 'rate', value: 50);
      expect(invalid.statusCode, 400);
      await invalid.drain<void>();
      await database.revokeDevice(credentials['deviceId'] as String);
      final revoked = await command(token: token);
      expect(revoked.statusCode, 403);
      await revoked.drain<void>();
      expect(actions, ['play']);
    },
  );
}
