import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers/device_runtime_provider.dart';
import '../../domain/models/device_configuration.dart';
import '../home/home_screen.dart';
import '../server/server_screen.dart';
import 'mode_selection_screen.dart';

class DeviceHome extends ConsumerWidget {
  const DeviceHome({super.key, this.tab});
  final String? tab;

  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(deviceRuntimeProvider)
      .when(
        loading: () =>
            const Scaffold(body: Center(child: CircularProgressIndicator())),
        error: (_, _) => Scaffold(
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Device settings could not be opened. Your media has been kept.',
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => ref.invalidate(deviceRuntimeProvider),
                  child: const Text('Try again'),
                ),
              ],
            ),
          ),
        ),
        data: (configuration) => switch (configuration.role) {
          AppRole.player => HomeScreen(
            initialDestination: switch (tab) {
              'libraries' => 1,
              'search' => 2,
              'settings' => 3,
              _ => 0,
            },
          ),
          AppRole.server => const ServerScreen(),
          null => const ModeSelectionScreen(),
        },
      );
}
