enum AppRole { player, server }

/// Device-local configuration. It must never change through library sync.
class DeviceConfiguration {
  const DeviceConfiguration({
    this.role,
    this.serverName = 'Tangerine server',
    this.port = 45831,
    this.autoStart = true,
    this.serverConfigured = false,
  });

  final AppRole? role;
  final String serverName;
  final int port;
  final bool autoStart;
  final bool serverConfigured;

  factory DeviceConfiguration.fromJson(Map<String, dynamic> json) {
    final port = json['port'];
    final name = json['serverName'];
    return DeviceConfiguration(
      role: switch (json['role']) {
        'player' => AppRole.player,
        'server' => AppRole.server,
        _ => null,
      },
      serverName: name is String && name.trim().isNotEmpty
          ? name.trim()
          : 'Tangerine server',
      port: port is int && port >= 0 && port <= 65535 ? port : 45831,
      autoStart: json['autoStart'] == true,
      serverConfigured: json['serverConfigured'] == true,
    );
  }

  Map<String, Object?> toJson() => {
    'role': role?.name,
    'serverName': serverName,
    'port': port,
    'autoStart': autoStart,
    'serverConfigured': serverConfigured,
  };

  DeviceConfiguration withRole(AppRole? value) => DeviceConfiguration(
    role: value,
    serverName: serverName,
    port: port,
    autoStart: autoStart,
    serverConfigured: serverConfigured,
  );
}
