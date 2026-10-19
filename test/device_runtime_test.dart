import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_stream/data/db/app_database.dart';
import 'package:study_stream/data/providers/app_providers.dart';
import 'package:study_stream/data/providers/device_runtime_provider.dart';
import 'package:study_stream/data/sync/lan_sync_server.dart';
import 'package:study_stream/domain/models/device_configuration.dart';

void main() {
  late AppDatabase database;
  late LanSyncServer server;
  late ProviderContainer container;

  ProviderContainer makeContainer() => ProviderContainer(
    overrides: [
      appDatabaseProvider.overrideWithValue(database),
      lanSyncServerProvider.overrideWithValue(server),
    ],
  );

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    server = LanSyncServer(database);
    container = makeContainer();
  });

  tearDown(() async {
    container.dispose();
    await server.dispose();
    await database.close();
  });

  test(
    'fresh installs require a role; player selection never starts hosting',
    () async {
      expect((await container.read(deviceRuntimeProvider.future)).role, isNull);
      await container
          .read(deviceRuntimeProvider.notifier)
          .chooseRole(AppRole.player);
      expect(server.state.running, isFalse);
      container.dispose();
      container = makeContainer();
      expect(
        (await container.read(deviceRuntimeProvider.future)).role,
        AppRole.player,
      );
      expect(server.state.running, isFalse);
    },
  );

  test(
    'configured server restarts on launch; switching to player stops it',
    () async {
      await container
          .read(deviceRuntimeProvider.notifier)
          .startServer(name: 'Living room', port: 0, autoStart: true);
      final chosen = await container.read(deviceRuntimeProvider.future);
      expect(server.state.running, isTrue);
      expect(chosen.port, server.state.port);
      expect(server.state.name, 'Living room');
      await server.stop();
      container.dispose();
      container = makeContainer();
      final restored = await container.read(deviceRuntimeProvider.future);
      expect(restored.role, AppRole.server);
      expect(server.state.running, isTrue);
      expect(server.state.port, chosen.port);

      await container
          .read(deviceRuntimeProvider.notifier)
          .chooseRole(AppRole.player);
      expect(server.state.running, isFalse);
      expect(
        (await container.read(deviceRuntimeProvider.future)).serverConfigured,
        isTrue,
      );
    },
  );

  test(
    'an explicit stop disables automatic restart without forgetting setup',
    () async {
      await container
          .read(deviceRuntimeProvider.notifier)
          .startServer(name: 'Media room', port: 0, autoStart: true);
      await container.read(deviceRuntimeProvider.notifier).stopServer();
      container.dispose();
      container = makeContainer();
      final restored = await container.read(deviceRuntimeProvider.future);
      expect(restored.role, AppRole.server);
      expect(restored.autoStart, isFalse);
      expect(restored.serverConfigured, isTrue);
      expect(server.state.running, isFalse);
    },
  );

  test(
    'occupied ports leave the previous role and configuration intact',
    () async {
      await container
          .read(deviceRuntimeProvider.notifier)
          .chooseRole(AppRole.player);
      final occupied = await HttpServer.bind(InternetAddress.anyIPv4, 0);
      addTearDown(() => occupied.close(force: true));
      await expectLater(
        container
            .read(deviceRuntimeProvider.notifier)
            .startServer(
              name: 'Unavailable',
              port: occupied.port,
              autoStart: true,
            ),
        throwsA(isA<SocketException>()),
      );
      expect(server.state.running, isFalse);
      expect(server.state.error, isNotNull);
      expect(
        (await container.read(deviceRuntimeProvider.future)).role,
        AppRole.player,
      );
    },
  );

  test(
    'backup restore cannot change this device’s role or enable a server',
    () async {
      await container
          .read(deviceRuntimeProvider.notifier)
          .chooseRole(AppRole.player);
      final snapshot = await database.exportData();
      final rows = (snapshot['settings'] as List).cast<Map<String, dynamic>>();
      final role = rows.singleWhere(
        (row) => row['key'] == DeviceRuntime.settingKey,
      );
      role['value'] = jsonEncode(
        const DeviceConfiguration(
          role: AppRole.server,
          autoStart: true,
          serverConfigured: true,
        ).toJson(),
      );
      role['updatedAt'] = DateTime.now().millisecondsSinceEpoch + 100000;
      await database.importData({...snapshot, 'settings': rows});
      container.dispose();
      container = makeContainer();
      expect(
        (await container.read(deviceRuntimeProvider.future)).role,
        AppRole.player,
      );
      expect(server.state.running, isFalse);
    },
  );
}
