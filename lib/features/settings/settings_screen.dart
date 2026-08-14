import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../data/db/app_database.dart';
import '../../data/providers/app_providers.dart';
import '../../data/sync/lan_sync_server.dart';
import '../../domain/models/app_preferences.dart';
import '../../domain/services/backup_service.dart';
import '../../shared/widgets/content_state.dart';
import '../../shared/widgets/study_ui.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _exporting = false;
  bool _restoring = false;

  Future<void> _export(AppDatabase database) async {
    if (_exporting) return;
    setState(() => _exporting = true);
    try {
      final path = await BackupService(database).exportBackup();
      if (mounted && path != null) {
        _message('Backup exported successfully', success: true);
      }
    } catch (_) {
      if (mounted) {
        _message(
          'The backup could not be exported. Check the destination and try again.',
          error: true,
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _restore(AppDatabase database) async {
    if (_restoring) return;
    final confirmed = await showStudyAdaptiveModal<bool>(
      context: context,
      builder: (_) => const StudyConfirmDialog(
        title: 'Restore a StudyStream backup?',
        message:
            'Valid records will be merged with data on this device. Matching records are updated; your source media files are not included or changed.',
        confirmLabel: 'Choose backup',
        icon: Icons.restore_rounded,
      ),
    );
    if (confirmed != true) return;
    setState(() => _restoring = true);
    try {
      final path = await BackupService(database).importBackup();
      if (mounted && path != null) {
        _message(
          'Backup restored. Libraries, progress, notes, bookmarks, and settings were merged.',
          success: true,
        );
      }
    } on FormatException {
      if (mounted) {
        _message(
          'This file is not a compatible StudyStream backup.',
          error: true,
        );
      }
    } catch (_) {
      if (mounted) {
        _message(
          'The backup could not be restored. The selected file may be damaged or inaccessible.',
          error: true,
        );
      }
    } finally {
      if (mounted) setState(() => _restoring = false);
    }
  }

  Future<void> _revokeDevice(AppDatabase database, KnownDevice device) async {
    final confirmed = await showStudyAdaptiveModal<bool>(
      context: context,
      builder: (_) => StudyConfirmDialog(
        title: 'Revoke ${device.name}?',
        message:
            'This device will no longer be approved for local-network sync. It can be paired again later.',
        confirmLabel: 'Revoke access',
        icon: Icons.phonelink_erase_rounded,
        destructive: true,
      ),
    );
    if (confirmed != true) return;
    await database.revokeDevice(device.id);
    if (mounted) _message('${device.name} was revoked');
  }

  void _message(String message, {bool error = false, bool success = false}) {
    final colors = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              error
                  ? Icons.error_outline_rounded
                  : success
                  ? Icons.check_circle_outline_rounded
                  : Icons.info_outline_rounded,
              color: colors.onInverseSurface,
            ),
            const SizedBox(width: AppSpace.sm),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final database = ref.watch(appDatabaseProvider);
    final server = ref.watch(lanSyncServerProvider);
    final themeMode = ref.watch(themeModeProvider);
    final preferences = ref.watch(appPreferencesProvider);

    final appearance = StudySection(
      title: 'Appearance',
      description: 'Choose how StudyStream should look on this device.',
      icon: Icons.palette_outlined,
      child: SizedBox(
        width: double.infinity,
        child: SegmentedButton<ThemeMode>(
          segments: const [
            ButtonSegment(value: ThemeMode.system, label: Text('System')),
            ButtonSegment(value: ThemeMode.light, label: Text('Light')),
            ButtonSegment(value: ThemeMode.dark, label: Text('Dark')),
          ],
          selected: {themeMode},
          onSelectionChanged: (value) {
            ref.read(themeModeProvider.notifier).setMode(value.first);
          },
        ),
      ),
    );

    final playback = StudySection(
      title: 'Playback',
      description: 'Defaults for newly opened video and audio lessons.',
      icon: Icons.play_circle_outline_rounded,
      child: _PlaybackPreferences(
        value: preferences,
        onChanged: (value) =>
            ref.read(appPreferencesProvider.notifier).update(value),
      ),
    );

    final reading = const StudySection(
      title: 'Reading',
      description: 'Document behaviour is kept simple and local.',
      icon: Icons.menu_book_outlined,
      child: Column(
        children: [
          _InformationRow(
            icon: Icons.bookmark_added_outlined,
            title: 'Resume automatically',
            description: 'PDFs reopen at your saved page and zoom level.',
          ),
          SizedBox(height: AppSpace.sm),
          _InformationRow(
            icon: Icons.done_all_rounded,
            title: 'Reading progress',
            description:
                'Completion follows the same threshold used for media.',
          ),
        ],
      ),
    );

    final backup = StudySection(
      title: 'Backup & restore',
      description:
          'Backups contain libraries, progress, notes, bookmarks, metadata, and settings. Source media is never included.',
      icon: Icons.inventory_2_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpace.md),
            decoration: BoxDecoration(
              color: context.studyColors.infoContainer,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  color: context.studyColors.info,
                ),
                const SizedBox(width: AppSpace.sm),
                Expanded(
                  child: Text(
                    'Keep your source folders separately backed up. A StudyStream backup restores your learning data, not the media itself.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpace.md),
          Wrap(
            spacing: AppSpace.xs,
            runSpacing: AppSpace.xs,
            children: [
              FilledButton.icon(
                onPressed: _exporting ? null : () => _export(database),
                icon: _exporting
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.download_outlined),
                label: Text(_exporting ? 'Exporting…' : 'Export backup'),
              ),
              OutlinedButton.icon(
                onPressed: _restoring ? null : () => _restore(database),
                icon: _restoring
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.restore_rounded),
                label: Text(_restoring ? 'Restoring…' : 'Restore backup'),
              ),
            ],
          ),
        ],
      ),
    );

    return StudyPage(
      maxWidth: 1240,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const StudyPageHeader(
            eyebrow: 'Make it yours',
            title: 'Settings',
            description:
                'Tune your learning experience, protect your progress, and manage local connections.',
          ),
          const SizedBox(height: AppSpace.xl),
          _SettingsGrid(children: [appearance, playback, reading, backup]),
          const SizedBox(height: AppSpace.md),
          StreamBuilder<LanSyncState>(
            stream: server.states,
            initialData: server.state,
            builder: (context, snapshot) => _SyncSection(
              server: server,
              state: snapshot.data ?? server.state,
              onMessage: _message,
            ),
          ),
          const SizedBox(height: AppSpace.md),
          _DevicesSection(
            database: database,
            onRevoke: (device) => _revokeDevice(database, device),
          ),
          const SizedBox(height: AppSpace.md),
          const _SettingsGrid(
            children: [_KeyboardSection(), _DiagnosticsSection()],
          ),
        ],
      ),
    );
  }
}

class _SettingsGrid extends StatelessWidget {
  const _SettingsGrid({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 900 ? 2 : 1;
        if (columns == 1) {
          return Column(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                children[i],
                if (i != children.length - 1)
                  const SizedBox(height: AppSpace.md),
              ],
            ],
          );
        }
        final width = (constraints.maxWidth - AppSpace.md) / 2;
        return Wrap(
          spacing: AppSpace.md,
          runSpacing: AppSpace.md,
          children: [
            for (final child in children) SizedBox(width: width, child: child),
          ],
        );
      },
    );
  }
}

class _PlaybackPreferences extends StatelessWidget {
  const _PlaybackPreferences({required this.value, required this.onChanged});

  final AppPreferences value;
  final ValueChanged<AppPreferences> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _SettingRow(
          label: 'Default speed',
          description: 'Applied when a lesson has no saved speed.',
          control: DropdownButton<double>(
            value: value.defaultPlaybackSpeed,
            items: const [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0]
                .map(
                  (speed) =>
                      DropdownMenuItem(value: speed, child: Text('$speed×')),
                )
                .toList(),
            onChanged: (speed) {
              if (speed != null) {
                onChanged(value.copyWith(defaultPlaybackSpeed: speed));
              }
            },
          ),
        ),
        const Divider(height: AppSpace.lg),
        _SettingRow(
          label: 'Resume rewind',
          description: 'Replay a little context before your saved position.',
          control: DropdownButton<double>(
            value: value.resumeRewindSeconds,
            items: const [0.0, 5.0, 10.0, 15.0, 30.0]
                .map(
                  (seconds) => DropdownMenuItem(
                    value: seconds,
                    child: Text('${seconds.round()} sec'),
                  ),
                )
                .toList(),
            onChanged: (seconds) {
              if (seconds != null) {
                onChanged(value.copyWith(resumeRewindSeconds: seconds));
              }
            },
          ),
        ),
        const Divider(height: AppSpace.lg),
        _SettingRow(
          label: 'Completion point',
          description: 'Automatically mark a lesson complete near its end.',
          control: DropdownButton<double>(
            value: value.completionThreshold,
            items: const [0.75, 0.8, 0.85, 0.9, 0.95, 1.0]
                .map(
                  (threshold) => DropdownMenuItem(
                    value: threshold,
                    child: Text('${(threshold * 100).round()}%'),
                  ),
                )
                .toList(),
            onChanged: (threshold) {
              if (threshold != null) {
                onChanged(value.copyWith(completionThreshold: threshold));
              }
            },
          ),
        ),
        const Divider(height: AppSpace.lg),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Auto-advance'),
          subtitle: const Text('Offer the next lesson after media finishes.'),
          value: value.autoAdvance,
          onChanged: (enabled) =>
              onChanged(value.copyWith(autoAdvance: enabled)),
        ),
      ],
    );
  }
}

class _SettingRow extends StatelessWidget {
  const _SettingRow({
    required this.label,
    required this.description,
    required this.control,
  });

  final String label;
  final String description;
  final Widget control;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final text = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: AppSpace.xxs),
            Text(description, style: Theme.of(context).textTheme.bodySmall),
          ],
        );
        if (constraints.maxWidth < 380) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              text,
              const SizedBox(height: AppSpace.xs),
              control,
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: text),
            const SizedBox(width: AppSpace.sm),
            control,
          ],
        );
      },
    );
  }
}

class _SyncSection extends StatelessWidget {
  const _SyncSection({
    required this.server,
    required this.state,
    required this.onMessage,
  });

  final LanSyncServer server;
  final LanSyncState state;
  final void Function(String message, {bool error, bool success}) onMessage;

  @override
  Widget build(BuildContext context) {
    return StudySection(
      title: 'Local network sync host',
      description:
          'Share learning progress with an approved compatible client on the same private network.',
      icon: Icons.wifi_tethering_rounded,
      trailing: StudyStatusBadge(
        label: state.running ? 'Host running' : 'Host stopped',
        icon: state.running
            ? Icons.check_circle_outline_rounded
            : Icons.pause_circle_outline_rounded,
        tone: state.running ? StudyStatusTone.success : StudyStatusTone.neutral,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (state.error != null) ...[
            const ContentState(
              icon: Icons.wifi_off_rounded,
              title: 'The sync host could not start',
              message:
                  'Check local-network permissions and whether the selected port is available.',
              tone: ContentStateTone.error,
              compact: true,
            ),
            const SizedBox(height: AppSpace.md),
          ],
          if (state.running) ...[
            LayoutBuilder(
              builder: (context, constraints) {
                final code = _PairingCode(code: state.pairingCode);
                final addresses = FutureBuilder<List<String>>(
                  future: _localAddresses(state.port!),
                  builder: (context, snapshot) => _NetworkAddress(
                    addresses:
                        snapshot.data ??
                        ['http://${Platform.localHostname}:${state.port}'],
                  ),
                );
                if (constraints.maxWidth < 700) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      code,
                      const SizedBox(height: AppSpace.sm),
                      addresses,
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: code),
                    const SizedBox(width: AppSpace.sm),
                    Expanded(child: addresses),
                  ],
                );
              },
            ),
            const SizedBox(height: AppSpace.md),
          ],
          Container(
            padding: const EdgeInsets.all(AppSpace.md),
            decoration: BoxDecoration(
              color: context.studyColors.warningContainer,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.security_rounded,
                  color: context.studyColors.warning,
                ),
                const SizedBox(width: AppSpace.sm),
                Expanded(
                  child: Text(
                    'Use this only on a network you trust. StudyStream hosts data; this app does not include a companion client.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpace.md),
          Wrap(
            spacing: AppSpace.xs,
            runSpacing: AppSpace.xs,
            children: [
              FilledButton.icon(
                onPressed: () async {
                  try {
                    state.running ? await server.stop() : await server.start();
                    onMessage(
                      state.running ? 'Sync host stopped' : 'Sync host started',
                      success: true,
                    );
                  } catch (_) {
                    onMessage(
                      'The sync host could not start. Check local-network access.',
                      error: true,
                    );
                  }
                },
                icon: Icon(
                  state.running
                      ? Icons.stop_circle_outlined
                      : Icons.wifi_tethering_rounded,
                ),
                label: Text(state.running ? 'Stop host' : 'Start host'),
              ),
              if (state.running)
                OutlinedButton.icon(
                  onPressed: server.regeneratePairingCode,
                  icon: const Icon(Icons.password_rounded),
                  label: const Text('New pairing code'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  static Future<List<String>> _localAddresses(int port) async {
    final interfaces = await NetworkInterface.list(
      type: InternetAddressType.IPv4,
      includeLoopback: false,
    );
    final values = {
      for (final interface in interfaces)
        for (final address in interface.addresses)
          'http://${address.address}:$port',
    }.toList();
    if (values.isEmpty) {
      values.add('http://${Platform.localHostname}:$port');
    }
    return values;
  }
}

class _PairingCode extends StatelessWidget {
  const _PairingCode({required this.code});

  final String? code;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpace.md),
      decoration: BoxDecoration(
        color: context.studyColors.surfaceSubtle,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: context.studyColors.outlineSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'One-time pairing code',
            style: Theme.of(context).textTheme.labelMedium,
          ),
          const SizedBox(height: AppSpace.xs),
          SelectableText(
            code ?? 'Expired',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              letterSpacing: code == null ? 0 : 5,
            ),
          ),
        ],
      ),
    );
  }
}

class _NetworkAddress extends StatelessWidget {
  const _NetworkAddress({required this.addresses});

  final List<String> addresses;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpace.md),
      decoration: BoxDecoration(
        color: context.studyColors.surfaceSubtle,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: context.studyColors.outlineSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Host address', style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: AppSpace.xs),
          SelectableText(
            addresses.join('\n'),
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ],
      ),
    );
  }
}

class _DevicesSection extends StatelessWidget {
  const _DevicesSection({required this.database, required this.onRevoke});

  final AppDatabase database;
  final ValueChanged<KnownDevice> onRevoke;

  @override
  Widget build(BuildContext context) {
    return StudySection(
      title: 'Approved devices',
      description: 'Devices that have been allowed to use the local sync host.',
      icon: Icons.devices_rounded,
      child: StreamBuilder<List<KnownDevice>>(
        stream: database.watchKnownDevices(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Text('Approved devices are temporarily unavailable.');
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const StudySkeleton(height: 64);
          }
          final devices = snapshot.data ?? const [];
          if (devices.isEmpty) {
            return const _InformationRow(
              icon: Icons.phonelink_off_rounded,
              title: 'No approved devices',
              description:
                  'A device appears here after it pairs successfully with the host.',
            );
          }
          return Column(
            children: [
              for (var i = 0; i < devices.length; i++) ...[
                _DeviceRow(device: devices[i], onRevoke: onRevoke),
                if (i != devices.length - 1) const Divider(),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _DeviceRow extends StatelessWidget {
  const _DeviceRow({required this.device, required this.onRevoke});

  final KnownDevice device;
  final ValueChanged<KnownDevice> onRevoke;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: device.revoked
              ? Theme.of(context).colorScheme.errorContainer
              : Theme.of(context).colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Icon(
          device.revoked ? Icons.block_rounded : Icons.devices_rounded,
          color: device.revoked
              ? Theme.of(context).colorScheme.onErrorContainer
              : Theme.of(context).colorScheme.onPrimaryContainer,
        ),
      ),
      title: Text(device.name),
      subtitle: StudyMeta(
        items: [
          device.revoked ? 'Access revoked' : device.lastAddress ?? 'Approved',
          if (device.lastSyncAt != null)
            'Last sync ${_relativeTime(device.lastSyncAt!)}',
        ],
      ),
      trailing: device.revoked
          ? const StudyStatusBadge(
              label: 'Revoked',
              tone: StudyStatusTone.error,
            )
          : TextButton(
              onPressed: () => onRevoke(device),
              child: const Text('Revoke'),
            ),
    );
  }

  static String _relativeTime(int milliseconds) {
    final difference = DateTime.now().difference(
      DateTime.fromMillisecondsSinceEpoch(milliseconds),
    );
    if (difference.inMinutes < 1) return 'just now';
    if (difference.inHours < 1) return '${difference.inMinutes} min ago';
    if (difference.inDays < 1) return '${difference.inHours} hr ago';
    return '${difference.inDays} d ago';
  }
}

class _InformationRow extends StatelessWidget {
  const _InformationRow({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: AppSpace.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: AppSpace.xxs),
              Text(description, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ],
    );
  }
}

class _KeyboardSection extends StatelessWidget {
  const _KeyboardSection();

  @override
  Widget build(BuildContext context) {
    return const StudySection(
      title: 'Keyboard shortcuts',
      description: 'Fast controls for desktop learning sessions.',
      icon: Icons.keyboard_outlined,
      child: Column(
        children: [
          _ShortcutRow(label: 'Play or pause', keys: 'Space'),
          Divider(),
          _ShortcutRow(label: 'Seek backward / forward', keys: '←  →'),
          Divider(),
          _ShortcutRow(label: 'Previous / next lesson', keys: 'P  N'),
          Divider(),
          _ShortcutRow(label: 'Mute', keys: 'M'),
          Divider(),
          _ShortcutRow(label: 'Navigate app', keys: 'Alt + 1–5'),
          Divider(),
          _ShortcutRow(label: 'Focus search', keys: '/'),
        ],
      ),
    );
  }
}

class _ShortcutRow extends StatelessWidget {
  const _ShortcutRow({required this.label, required this.keys});

  final String label;
  final String keys;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpace.xxs),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          const SizedBox(width: AppSpace.sm),
          StudyShortcutHint(keys: keys),
        ],
      ),
    );
  }
}

class _DiagnosticsSection extends StatelessWidget {
  const _DiagnosticsSection();

  @override
  Widget build(BuildContext context) {
    return const StudySection(
      title: 'Storage, diagnostics & about',
      description: 'Technical context, kept out of the everyday experience.',
      icon: Icons.info_outline_rounded,
      child: Column(
        children: [
          _InformationRow(
            icon: Icons.storage_outlined,
            title: 'Local app data',
            description:
                'Progress, notes, bookmarks, and preferences are stored on this device.',
          ),
          SizedBox(height: AppSpace.md),
          _InformationRow(
            icon: Icons.folder_outlined,
            title: 'External source files',
            description:
                'StudyStream indexes your folders but does not move or duplicate them.',
          ),
          SizedBox(height: AppSpace.md),
          _InformationRow(
            icon: Icons.play_arrow_rounded,
            title: 'StudyStream 1.0',
            description: 'Private, folder-based media learning.',
          ),
        ],
      ),
    );
  }
}
