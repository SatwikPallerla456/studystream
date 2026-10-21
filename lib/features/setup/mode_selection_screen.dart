import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../data/providers/device_runtime_provider.dart';
import '../../domain/models/device_configuration.dart';
import '../../shared/widgets/study_ui.dart';

class ModeSelectionScreen extends ConsumerStatefulWidget {
  const ModeSelectionScreen({super.key});

  @override
  ConsumerState<ModeSelectionScreen> createState() =>
      _ModeSelectionScreenState();
}

class _ModeSelectionScreenState extends ConsumerState<ModeSelectionScreen> {
  bool _busy = false;
  String? _error;

  Future<void> _choose(AppRole role) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(deviceRuntimeProvider.notifier).chooseRole(role);
      if (mounted) context.go('/');
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Your selection could not be saved. Check available storage and try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: ref.watch(deviceRuntimeProvider).asData?.value.role == null
        ? null
        : AppBar(
            title: const Text('Device mode'),
            leading: IconButton(
              tooltip: 'Back',
              icon: const Icon(Icons.arrow_back),
              onPressed: _busy
                  ? null
                  : () {
                      if (context.canPop()) {
                        context.pop();
                      } else {
                        context.go('/?tab=home');
                      }
                    },
            ),
          ),
    body: SafeArea(
      child: Center(
        child: StudyPage(
          maxWidth: 1050,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppSpace.md),
              if (ref.watch(deviceRuntimeProvider).asData?.value.role ==
                  null) ...[
                Image.asset(
                  'assets/brand/tangerine.png',
                  width: 48,
                  height: 48,
                  excludeFromSemantics: true,
                ),
                const SizedBox(height: AppSpace.md),
                Text(
                  'Tangerine',
                  style: Theme.of(context).textTheme.displaySmall,
                ),
                const SizedBox(height: AppSpace.xs),
                Text(
                  'Choose a device mode',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: AppSpace.sm),
              ],
              Text(
                'Play your media here, or share a library with your other devices.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: AppSpace.xl),
              LayoutBuilder(
                builder: (context, constraints) {
                  final cards = [
                    _ModeCard(
                      icon: Icons.play_arrow_rounded,
                      title: 'Player',
                      description:
                          'Watch, listen, read, and learn. Open local media or stream from your Tangerine server.',
                      features: const [
                        'Video & music',
                        'Documents & study tools',
                        'Local files & server libraries',
                      ],
                      action: 'Use as player',
                      onPressed: _busy ? null : () => _choose(AppRole.player),
                    ),
                    _ModeCard(
                      icon: Icons.dns_outlined,
                      title: 'Server',
                      description:
                          'Set up a media server on this device. Share your local libraries with paired players.',
                      features: const [
                        'Guided server setup',
                        'Private network streaming',
                        'Device pairing & synced progress',
                      ],
                      action: 'Set up server',
                      onPressed: _busy ? null : () => _choose(AppRole.server),
                    ),
                  ];
                  if (constraints.maxWidth < 650) {
                    return Column(
                      children: [
                        cards[0],
                        const SizedBox(height: AppSpace.md),
                        cards[1],
                      ],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: cards[0]),
                      const SizedBox(width: AppSpace.md),
                      Expanded(child: cards[1]),
                    ],
                  );
                },
              ),
              const SizedBox(height: AppSpace.lg),
              const Text(
                'You can switch modes later. Your media, notes, and progress stay with you.',
              ),
              if (_busy)
                const Padding(
                  padding: EdgeInsets.only(top: AppSpace.md),
                  child: LinearProgressIndicator(),
                ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpace.md),
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.features,
    required this.action,
    this.onPressed,
  });
  final IconData icon;
  final String title;
  final String description;
  final List<String> features;
  final String action;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(AppSpace.lg),
    decoration: BoxDecoration(
      color: context.studyColors.surfaceRaised,
      border: Border.all(color: context.studyColors.outlineSoft),
      borderRadius: BorderRadius.circular(AppRadius.md),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 36, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: AppSpace.md),
        Text(title, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: AppSpace.xs),
        Text(description),
        const SizedBox(height: AppSpace.md),
        for (final feature in features)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpace.xxs),
            child: Row(
              children: [
                const Icon(Icons.check_rounded, size: 18),
                const SizedBox(width: AppSpace.xs),
                Expanded(child: Text(feature)),
              ],
            ),
          ),
        const SizedBox(height: AppSpace.lg),
        SizedBox(
          width: double.infinity,
          child: FilledButton(onPressed: onPressed, child: Text(action)),
        ),
      ],
    ),
  );
}
