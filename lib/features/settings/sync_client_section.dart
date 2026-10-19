import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../data/providers/app_providers.dart';
import '../../data/sync/lan_discovery.dart';
import '../../data/sync/lan_sync_client.dart';
import '../../shared/widgets/study_ui.dart';

class SyncClientSection extends ConsumerStatefulWidget {
  const SyncClientSection({super.key});
  @override
  ConsumerState<SyncClientSection> createState() => _SyncClientSectionState();
}

class _SyncClientSectionState extends ConsumerState<SyncClientSection> {
  final _address = TextEditingController();
  final _code = TextEditingController();
  final _name = TextEditingController(text: Platform.localHostname);
  bool _busy = false;
  bool _discovering = false;
  String? _error;
  Map<Uri, String> _hosts = {};

  @override
  void dispose() {
    _address.dispose();
    _code.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _pair() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(lanSyncClientProvider)
          .pair(address: _address.text, code: _code.text, name: _name.text);
      _code.clear();
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Pairing failed. Check the host address, device name, and current six-digit code.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _discover() async {
    setState(() {
      _discovering = true;
      _error = null;
    });
    try {
      final hosts = await LanDiscovery.discover();
      if (mounted) {
        setState(() {
          _hosts = hosts;
          if (hosts.isEmpty) {
            _error =
                'No servers responded. Start Server mode on another device or enter its address manually.';
          }
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Discovery is unavailable on this network. Enter the host address manually.',
        );
      }
    } finally {
      if (mounted) setState(() => _discovering = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final client = ref.watch(lanSyncClientProvider);
    return StreamBuilder<SyncClientState>(
      stream: client.states,
      initialData: client.state,
      builder: (context, snapshot) {
        final state = snapshot.data ?? client.state;
        final connected = state.address != null;
        return StudySection(
          title: 'Connect to a media server',
          description:
              'Browse and play a paired server’s library here. Notes, bookmarks, completion, and progress sync automatically while connected.',
          icon: Icons.devices_rounded,
          trailing: StudyStatusBadge(
            label: switch (state.phase) {
              ConnectionPhase.disconnected => 'Disconnected',
              ConnectionPhase.connecting => 'Connecting',
              ConnectionPhase.connected => 'Connected',
              ConnectionPhase.retrying => 'Retrying',
              ConnectionPhase.error => 'Needs attention',
            },
            tone: state.phase == ConnectionPhase.connected
                ? StudyStatusTone.success
                : StudyStatusTone.neutral,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (connected) ...[
                SelectableText(state.address!),
                const SizedBox(height: AppSpace.xs),
                Text(
                  state.lastSyncAt == null
                      ? 'Waiting for the first successful sync'
                      : 'Last successful sync: ${DateTime.fromMillisecondsSinceEpoch(state.lastSyncAt!).toLocal()}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: AppSpace.sm),
                Wrap(
                  spacing: AppSpace.xs,
                  runSpacing: AppSpace.xs,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => client.sync(),
                      icon: const Icon(Icons.sync_rounded),
                      label: const Text('Sync now'),
                    ),
                    TextButton(
                      onPressed: () => client.disconnect(forget: true),
                      child: const Text('Disconnect & forget'),
                    ),
                  ],
                ),
              ] else ...[
                OutlinedButton.icon(
                  onPressed: _discovering ? null : _discover,
                  icon: const Icon(Icons.radar_rounded),
                  label: Text(
                    _discovering ? 'Discovering…' : 'Find nearby servers',
                  ),
                ),
                for (final host in _hosts.entries)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.desktop_windows_outlined),
                    title: Text(host.value),
                    subtitle: Text(host.key.toString()),
                    onTap: () => _address.text = host.key.toString(),
                  ),
                const SizedBox(height: AppSpace.sm),
                TextField(
                  controller: _address,
                  keyboardType: TextInputType.url,
                  autocorrect: false,
                  decoration: const InputDecoration(
                    labelText: 'Server address',
                    hintText: 'http://192.168.1.20:45831',
                  ),
                ),
                const SizedBox(height: AppSpace.sm),
                TextField(
                  controller: _name,
                  decoration: const InputDecoration(
                    labelText: 'This device’s name',
                  ),
                ),
                const SizedBox(height: AppSpace.sm),
                TextField(
                  controller: _code,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  decoration: const InputDecoration(
                    labelText: 'Pairing code',
                    helperText: 'Shown on the other device’s Server screen',
                  ),
                ),
                const SizedBox(height: AppSpace.sm),
                Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton.icon(
                    onPressed: _busy ? null : _pair,
                    icon: const Icon(Icons.link_rounded),
                    label: Text(_busy ? 'Pairing…' : 'Pair this device'),
                  ),
                ),
              ],
              if (_error != null || state.message != null)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpace.sm),
                  child: Semantics(
                    liveRegion: true,
                    child: Text(
                      _error ?? state.message!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: AppSpace.sm),
              Text(
                'HTTP pairing and streaming use bearer tokens but are not encrypted. Use a trusted private network. Offline study edits are kept on this device; remote media needs the host online.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        );
      },
    );
  }
}
