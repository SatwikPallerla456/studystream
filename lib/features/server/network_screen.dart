import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../shared/widgets/study_ui.dart';
import '../settings/sync_client_section.dart';

class NetworkScreen extends StatelessWidget {
  const NetworkScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Network')),
    body: StudyPage(
      maxWidth: 1000,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SyncClientSection(),
          const SizedBox(height: AppSpace.md),
          StudySection(
            title: 'Use this device as a server',
            description:
                'Set up sharing from the same app, with your local media and paired devices.',
            icon: Icons.dns_outlined,
            child: Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: () => context.push('/mode'),
                icon: const Icon(Icons.swap_horiz_rounded),
                label: const Text('Change device mode'),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
