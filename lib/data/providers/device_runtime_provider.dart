import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/device_configuration.dart';
import 'app_providers.dart';

final deviceRuntimeProvider =
    AsyncNotifierProvider<DeviceRuntime, DeviceConfiguration>(
      DeviceRuntime.new,
    );

class DeviceRuntime extends AsyncNotifier<DeviceConfiguration> {
  // The sync. prefix also excludes this setting from backup restoration.
  static const settingKey = 'sync.deviceConfiguration';

  @override
  Future<DeviceConfiguration> build() async {
    final raw = await ref.read(appDatabaseProvider).getSetting(settingKey);
    var configuration = const DeviceConfiguration();
    if (raw != null) {
      try {
        final json = jsonDecode(raw);
        if (json is Map<String, dynamic>) {
          configuration = DeviceConfiguration.fromJson(json);
        }
      } on FormatException {
        // A damaged preference does not affect libraries or learning records.
      }
    }
    return configuration;
  }

  Future<void> chooseRole(AppRole? role) async {
    final configuration = await future;
    // Persist first: a storage failure must not silently change the device role.
    final next = configuration.withRole(role);
    await _save(next);
    if (role != AppRole.server) {
      await ref.read(lanSyncServerProvider).stop();
    } else if (next.serverConfigured && next.autoStart) {
      // Opening settings is read-only. Resume sharing only after Server is chosen.
      try {
        final server = ref.read(lanSyncServerProvider);
        if (!server.state.running)
          await server.start(port: next.port, name: next.serverName);
      } on Object {
        // Show Server so a port/permission failure can be repaired there.
      }
    }
    if (ref.mounted) state = AsyncData(next);
  }

  Future<void> startServer({
    required String name,
    required int port,
    required bool autoStart,
  }) async {
    if (name.trim().isEmpty || name.trim().length > 80) {
      throw const FormatException('Enter a server name of 1–80 characters.');
    }
    if (port < 0 || port > 65535) {
      throw const FormatException(
        'Use a port from 1–65535, or 0 for automatic.',
      );
    }
    final previous = await future;
    final server = ref.read(lanSyncServerProvider);
    if (server.state.running) return;
    await server.start(port: port, name: name.trim());
    final next = DeviceConfiguration(
      role: AppRole.server,
      serverName: name.trim(),
      // Remember the chosen port when automatic allocation was requested.
      port: port == 0 ? server.state.port! : port,
      autoStart: autoStart,
      serverConfigured: true,
    );
    try {
      await _save(next);
    } catch (_) {
      await server.stop();
      if (ref.mounted) state = AsyncData(previous);
      rethrow;
    }
    if (ref.mounted) state = AsyncData(next);
  }

  Future<void> stopServer() async {
    final previous = await future;
    final next = DeviceConfiguration(
      role: previous.role,
      serverName: previous.serverName,
      port: previous.port,
      autoStart: false,
      serverConfigured: previous.serverConfigured,
    );
    await _save(next);
    await ref.read(lanSyncServerProvider).stop();
    if (ref.mounted) state = AsyncData(next);
  }

  Future<void> _save(DeviceConfiguration configuration) => ref
      .read(appDatabaseProvider)
      .setSetting(settingKey, jsonEncode(configuration.toJson()));
}
