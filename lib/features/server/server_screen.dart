import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;

import '../../core/theme/app_theme.dart';
import '../../data/db/app_database.dart';
import '../../data/indexer/library_indexer.dart';
import '../../data/platform/folder_access.dart';
import '../../data/providers/app_providers.dart';
import '../../data/providers/device_runtime_provider.dart';
import '../../data/sync/lan_sync_server.dart';
import '../../domain/models/device_configuration.dart';
import '../../domain/services/media_import_service.dart';
import '../../shared/widgets/study_ui.dart';
import 'library_grants_screen.dart';
import '../library/library_setup_sheet.dart';
import '../../domain/catalog/media_catalog_repository.dart';

class ServerScreen extends ConsumerStatefulWidget {
  const ServerScreen({super.key});

  @override
  ConsumerState<ServerScreen> createState() => _ServerScreenState();
}

class _ServerScreenState extends ConsumerState<ServerScreen> {
  final _name = TextEditingController();
  final _port = TextEditingController();
  bool _initialized = false;
  bool _autoStart = true;
  bool _busy = false;
  String? _error;
  String? _activity;
  ScanCancellationToken? _scanToken;
  int? _addressPort;
  Future<List<String>>? _addresses;

  bool get _mobile => Platform.isAndroid || Platform.isIOS;

  @override
  void dispose() {
    _scanToken?.cancel();
    _name.dispose();
    _port.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } on ScanCancelledException {
      /* Closing the screen cancels its folder scan. */
    } on FormatException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'This action could not finish. Check file permissions, local-network access, available storage, and the server port.',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _activity = null;
        });
      }
    }
  }

  Future<void> _addFolder() => _run(() async {
    final path = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Choose a media library',
    );
    if (path == null || !mounted) return;
    await FolderAccess.retain(path);
    if (!mounted) return;
    final setup = await showLibrarySetup(context, p.basename(path));
    if (setup == null || !mounted) return;
    final token = _scanToken = ScanCancellationToken();
    final result = await ref
        .read(libraryIndexerProvider)
        .scanRootFolder(
          rootFolderPath: path,
          title: setup.name,
          cancellationToken: token,
          onProgress: (progress) {
            if (mounted) {
              setState(
                () => _activity =
                    '${progress.phase} · ${progress.processedFiles} files',
              );
            }
          },
        );
    await MediaCatalogRepository(
      ref.read(appDatabaseProvider),
    ).setLibraryKind(result.libraryId, setup.kind);
    _scanToken = null;
  });

  Future<void> _addFiles() => _run(() async {
    setState(
      () => _activity = 'Copying selected media into this device’s library…',
    );
    await MediaImportService(ref.read(libraryIndexerProvider)).pickFiles();
  });

  Future<void> _start() => _run(() async {
    final port = int.tryParse(_port.text.trim());
    if (port == null) {
      throw const FormatException('Enter a numeric server port.');
    }
    await ref
        .read(deviceRuntimeProvider.notifier)
        .startServer(name: _name.text, port: port, autoStart: _autoStart);
  });

  Future<void> _switchPlayer() => _run(() async {
    await ref.read(deviceRuntimeProvider.notifier).chooseRole(AppRole.player);
    if (mounted) context.go('/');
  });

  @override
  Widget build(BuildContext context) {
    final configuration = ref.watch(deviceRuntimeProvider).asData?.value;
    if (configuration != null && !_initialized) {
      _initialized = true;
      _name.text = configuration.serverName;
      _port.text = '${configuration.port}';
      _autoStart = configuration.autoStart;
    }
    final database = ref.watch(appDatabaseProvider);
    final server = ref.watch(lanSyncServerProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Media server',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          if (MediaQuery.sizeOf(context).width < 700)
            IconButton(
              tooltip: 'Player mode',
              onPressed: _busy ? null : _switchPlayer,
              icon: const Icon(Icons.play_circle_outline_rounded),
            )
          else
            TextButton.icon(
              onPressed: _busy ? null : _switchPlayer,
              icon: const Icon(Icons.play_circle_outline_rounded),
              label: const Text('Player mode'),
            ),
          const SizedBox(width: AppSpace.xs),
        ],
      ),
      body: StreamBuilder<LanSyncState>(
        stream: server.states,
        initialData: server.state,
        builder: (context, serverSnapshot) {
          final state = serverSnapshot.data ?? server.state;
          if (state.running && _addressPort != state.port) {
            _addressPort = state.port;
            _addresses = _localAddresses(state.port!);
          }
          return StudyPage(
            maxWidth: 1100,
            child: StreamBuilder<List<Library>>(
              stream: database.watchLibraries(),
              builder: (context, librariesSnapshot) {
                final libraries = (librariesSnapshot.data ?? [])
                    .where(
                      (library) =>
                          !library.rootFolderPath.startsWith('remote:'),
                    )
                    .toList();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    StudyPageHeader(
                      title: state.running
                          ? state.name
                          : 'Set up your media server',
                      description: state.running
                          ? 'Pair another Tangerine player using the address and code below. Keep this app open to make your libraries available.'
                          : 'Name this server, add your media, and start sharing with your other devices.',
                    ),
                    const SizedBox(height: AppSpace.lg),
                    if (state.running) ...[
                      StudySection(
                        title: 'Connect a player',
                        description:
                            'On the other device, choose Player → Network → Pair this device.',
                        icon: Icons.devices_rounded,
                        trailing: const StudyStatusBadge(
                          label: 'Online',
                          tone: StudyStatusTone.success,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Pairing code',
                              style: Theme.of(context).textTheme.labelLarge,
                            ),
                            const SizedBox(height: AppSpace.xs),
                            SelectableText(
                              state.pairingCode ?? 'Code expired',
                              style: Theme.of(context).textTheme.headlineMedium
                                  ?.copyWith(letterSpacing: 4),
                            ),
                            Text(
                              state.pairingCode == null
                                  ? 'Generate a new code to pair another player.'
                                  : 'Expires in ten minutes and rotates after a successful pairing.',
                            ),
                            const SizedBox(height: AppSpace.md),
                            FutureBuilder<List<String>>(
                              future: _addresses,
                              builder: (context, snapshot) => Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  for (final address
                                      in snapshot.data ??
                                          [
                                            'http://${Platform.localHostname}:${state.port}',
                                          ])
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: AppSpace.xs,
                                      ),
                                      child: Wrap(
                                        crossAxisAlignment:
                                            WrapCrossAlignment.center,
                                        spacing: AppSpace.xs,
                                        children: [
                                          SelectableText(address),
                                          IconButton(
                                            tooltip: 'Copy server address',
                                            onPressed: () => Clipboard.setData(
                                              ClipboardData(text: address),
                                            ),
                                            icon: const Icon(
                                              Icons.copy_rounded,
                                              size: 18,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            Wrap(
                              spacing: AppSpace.xs,
                              runSpacing: AppSpace.xs,
                              children: [
                                OutlinedButton.icon(
                                  onPressed: server.regeneratePairingCode,
                                  icon: const Icon(Icons.password_rounded),
                                  label: const Text('New pairing code'),
                                ),
                                OutlinedButton.icon(
                                  onPressed: () => setState(
                                    () => _addresses = _localAddresses(
                                      state.port!,
                                    ),
                                  ),
                                  icon: const Icon(Icons.refresh_rounded),
                                  label: const Text('Refresh addresses'),
                                ),
                                FilledButton.icon(
                                  onPressed: _busy
                                      ? null
                                      : () => _run(
                                          () => ref
                                              .read(
                                                deviceRuntimeProvider.notifier,
                                              )
                                              .stopServer(),
                                        ),
                                  icon: const Icon(Icons.stop_circle_outlined),
                                  label: const Text('Stop server'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      StudySection(
                        title: '1. Server details',
                        icon: Icons.dns_outlined,
                        child: Column(
                          children: [
                            TextField(
                              controller: _name,
                              enabled: !_busy,
                              maxLength: 80,
                              decoration: const InputDecoration(
                                labelText: 'Server name',
                              ),
                            ),
                            const SizedBox(height: AppSpace.sm),
                            TextField(
                              controller: _port,
                              enabled: !_busy,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Port',
                                helperText:
                                    'Default: 45831. Use 0 to choose an available port.',
                              ),
                            ),
                            const SizedBox(height: AppSpace.sm),
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text(
                                'Start automatically in Server mode',
                              ),
                              subtitle: const Text(
                                'Resume sharing after you choose Server on the opening screen.',
                              ),
                              value: _autoStart,
                              onChanged: _busy
                                  ? null
                                  : (value) =>
                                        setState(() => _autoStart = value),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpace.md),
                    StudySection(
                      title: state.running
                          ? 'Shared libraries'
                          : '2. Add your media',
                      description:
                          'Choose library access for each approved player. Adding files copies them into this app; adding a folder keeps media in place.',
                      icon: Icons.video_library_outlined,
                      trailing: StudyStatusBadge(
                        label: '${libraries.length} libraries',
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (libraries.isEmpty)
                            const Padding(
                              padding: EdgeInsets.only(bottom: AppSpace.md),
                              child: Text(
                                'Add video, music, documents, or a course to get started.',
                              ),
                            ),
                          for (final library in libraries)
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: Icon(
                                library.unavailable
                                    ? Icons.folder_off_outlined
                                    : Icons.folder_outlined,
                              ),
                              title: Text(library.title),
                              subtitle: Text(
                                library.unavailable
                                    ? 'Folder unavailable · relink it in the library'
                                    : library.rootFolderPath,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: IconButton(
                                tooltip: 'Browse library',
                                icon: const Icon(Icons.arrow_forward_rounded),
                                onPressed: () =>
                                    context.push('/library/${library.id}'),
                              ),
                            ),
                          Wrap(
                            spacing: AppSpace.xs,
                            runSpacing: AppSpace.xs,
                            children: [
                              if (!_mobile)
                                OutlinedButton.icon(
                                  onPressed: _busy ? null : _addFolder,
                                  icon: const Icon(
                                    Icons.create_new_folder_outlined,
                                  ),
                                  label: const Text('Add folder'),
                                ),
                              OutlinedButton.icon(
                                onPressed: _busy ? null : _addFiles,
                                icon: const Icon(Icons.add_rounded),
                                label: const Text('Add files'),
                              ),
                            ],
                          ),
                          if (_busy) ...[
                            const SizedBox(height: AppSpace.sm),
                            const LinearProgressIndicator(),
                            if (_activity != null)
                              Padding(
                                padding: const EdgeInsets.only(
                                  top: AppSpace.xs,
                                ),
                                child: Text(_activity!),
                              ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpace.md),
                    if (!state.running)
                      StudySection(
                        title: '3. Start sharing',
                        icon: Icons.wifi_tethering_rounded,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Approved devices can browse and stream your local libraries, and sync notes, bookmarks, and progress. HTTP traffic is authenticated but unencrypted; use a trusted private network.',
                            ),
                            const SizedBox(height: AppSpace.md),
                            FilledButton.icon(
                              onPressed:
                                  _busy ||
                                      configuration == null ||
                                      libraries.every(
                                        (library) => library.unavailable,
                                      )
                                  ? null
                                  : _start,
                              icon: const Icon(
                                Icons.power_settings_new_rounded,
                              ),
                              label: Text(
                                _busy ? 'Please wait…' : 'Start server',
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (state.running) ...[
                      const Text(
                        'Sharing uses authenticated HTTP on your private network. Traffic is not encrypted.',
                      ),
                      const SizedBox(height: AppSpace.md),
                      _ApprovedPlayers(database: database),
                    ],
                    if (_error != null || state.error != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSpace.md,
                        ),
                        child: Text(
                          _error ??
                              'The server could not start. Check local-network permissions and whether the port is in use.',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    const SizedBox(height: AppSpace.md),
                    Text(
                      _mobile
                          ? 'Mobile hosting works while the app is open. The operating system may suspend the server when the app is in the background or the screen is locked.'
                          : 'Leave Tangerine open and keep this device awake while other players use the server. Switching to Player mode stops hosting.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                );
              },
            ),
          );
        },
      ),
    );
  }

  static Future<List<String>> _localAddresses(int port) async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
      );
      final addresses = {
        for (final interface in interfaces)
          for (final address in interface.addresses)
            'http://${address.address}:$port',
      }.toList();
      if (addresses.isNotEmpty) return addresses;
    } on SocketException {
      /* The hostname remains a useful manual fallback. */
    }
    return ['http://${Platform.localHostname}:$port'];
  }
}

class _ApprovedPlayers extends StatelessWidget {
  const _ApprovedPlayers({required this.database});
  final AppDatabase database;

  @override
  Widget build(BuildContext context) => StudySection(
    title: 'Approved players',
    icon: Icons.verified_user_outlined,
    child: StreamBuilder<List<KnownDevice>>(
      stream: database.watchKnownDevices(),
      builder: (context, snapshot) {
        final devices = (snapshot.data ?? [])
            .where((device) => device.approved && !device.revoked)
            .toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (devices.isEmpty)
              const Text(
                'No players paired yet. Use the address and code above on another device.',
              ),
            for (final device in devices)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.devices_rounded),
                title: Text(device.name),
                subtitle: Text(device.lastAddress ?? 'Paired player'),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        LibraryGrantsScreen(database: database, device: device),
                  ),
                ),
                trailing: TextButton(
                  onPressed: () async {
                    final revoke = await showStudyAdaptiveModal<bool>(
                      context: context,
                      builder: (_) => StudyConfirmDialog(
                        title: 'Revoke ${device.name}?',
                        message:
                            'This player will need to pair again to access your media.',
                        confirmLabel: 'Revoke access',
                        icon: Icons.phonelink_erase_rounded,
                        destructive: true,
                      ),
                    );
                    if (revoke == true) await database.revokeDevice(device.id);
                  },
                  child: const Text('Revoke'),
                ),
              ),
          ],
        );
      },
    ),
  );
}
