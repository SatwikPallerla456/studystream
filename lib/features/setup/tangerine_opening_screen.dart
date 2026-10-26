import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../data/providers/device_runtime_provider.dart';
import '../../domain/models/device_configuration.dart';

const _markTag = 'tangerine-opening-mark';

/// Same image on both routes lets the logo travel rather than disappear/reappear.
class TangerineOpeningMark extends StatelessWidget {
  const TangerineOpeningMark({super.key, required this.size});
  final double size;
  @override
  Widget build(BuildContext context) => Hero(
    tag: _markTag,
    createRectTween: (begin, end) =>
        MaterialRectArcTween(begin: begin, end: end),
    child: Image.asset(
      'assets/brand/tangerine.png',
      width: size,
      height: size,
      excludeFromSemantics: true,
    ),
  );
}

Route<void> tangerineOpeningRoute({
  required Widget child,
  bool reducedMotion = false,
}) => PageRouteBuilder<void>(
  transitionDuration: reducedMotion
      ? Duration.zero
      : const Duration(milliseconds: 850),
  reverseTransitionDuration: AppMotion.emphasized,
  pageBuilder: (_, _, _) => child,
  transitionsBuilder: (_, animation, _, child) => FadeTransition(
    opacity: CurvedAnimation(parent: animation, curve: Curves.easeInOutCubic),
    child: child,
  ),
);

class TangerineOpeningScreen extends ConsumerStatefulWidget {
  const TangerineOpeningScreen({super.key, required this.onContinue});
  final VoidCallback onContinue;
  @override
  ConsumerState<TangerineOpeningScreen> createState() =>
      _TangerineOpeningState();
}

class _TangerineOpeningState extends ConsumerState<TangerineOpeningScreen> {
  bool _busy = false;
  String? _error;
  Future<void> _choose(AppRole role) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(deviceRuntimeProvider.notifier).chooseRole(role);
      if (mounted) widget.onContinue();
    } catch (_) {
      if (mounted)
        setState(() {
          _busy = false;
          _error =
              'This mode could not be opened. Check storage and try again.';
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final runtime = ref.watch(deviceRuntimeProvider);
    return TangerineOpeningView(
      lastRole: runtime.asData?.value.role,
      loading: runtime.isLoading,
      busy: _busy,
      error:
          _error ??
          (runtime.hasError
              ? 'Device settings could not be opened. Your library has been kept.'
              : null),
      onRetry: runtime.hasError
          ? () => ref.invalidate(deviceRuntimeProvider)
          : null,
      onChoose: runtime.hasValue ? _choose : null,
    );
  }
}

/// Shared with the isolated visual preview; it performs no configuration writes.
class TangerineOpeningView extends StatelessWidget {
  const TangerineOpeningView({
    super.key,
    this.lastRole,
    this.loading = false,
    this.busy = false,
    this.error,
    this.onRetry,
    this.onChoose,
  });
  final AppRole? lastRole;
  final bool loading, busy;
  final String? error;
  final VoidCallback? onRetry;
  final ValueChanged<AppRole>? onChoose;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final ink = dark ? const Color(0xfffff6eb) : const Color(0xff302b26);
    return Scaffold(
      backgroundColor: dark ? const Color(0xff191b1a) : const Color(0xfff8f4ee),
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(-.8, -1),
            radius: 1.2,
            colors: [
              const Color(0xffed822b).withValues(alpha: .08),
              Colors.transparent,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
                child: Row(
                  children: [
                    const TangerineOpeningMark(size: 42),
                    const SizedBox(width: 12),
                    Flexible(
                      child: Text(
                        'Tangerine',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: ink,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, box) => SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: box.maxHeight),
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 900),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'How will you use Tangerine?',
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineLarge
                                      ?.copyWith(
                                        color: ink,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: -.8,
                                      ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Choose a mode for this session.',
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context).textTheme.bodyLarge
                                      ?.copyWith(
                                        color: ink.withValues(alpha: .65),
                                      ),
                                ),
                                const SizedBox(height: 24),
                                LayoutBuilder(
                                  builder: (context, size) {
                                    final cards = [
                                      for (final role in AppRole.values)
                                        _OpeningModeCard(
                                          role: role,
                                          lastUsed: role == lastRole,
                                          onPressed:
                                              busy ||
                                                  loading ||
                                                  onChoose == null
                                              ? null
                                              : () => onChoose!(role),
                                        ),
                                    ];
                                    if (size.maxWidth < 640)
                                      return Column(
                                        children: [
                                          cards[0],
                                          const SizedBox(height: 16),
                                          cards[1],
                                        ],
                                      );
                                    return IntrinsicHeight(
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          Expanded(child: cards[0]),
                                          const SizedBox(width: 20),
                                          Expanded(child: cards[1]),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                                const SizedBox(height: 20),
                                Text(
                                  'You can switch modes later. Your media, notes and progress stay with you.',
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: ink.withValues(alpha: .6),
                                      ),
                                ),
                                if (busy || loading) ...[
                                  const SizedBox(height: 16),
                                  const SizedBox(
                                    width: 180,
                                    child: LinearProgressIndicator(),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    busy
                                        ? 'Opening your mode…'
                                        : 'Loading device settings…',
                                  ),
                                ],
                                if (error != null) ...[
                                  const SizedBox(height: 16),
                                  Semantics(
                                    liveRegion: true,
                                    child: Text(
                                      error!,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.error,
                                      ),
                                    ),
                                  ),
                                  if (onRetry != null)
                                    TextButton(
                                      onPressed: onRetry,
                                      child: const Text('Try again'),
                                    ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OpeningModeCard extends StatelessWidget {
  const _OpeningModeCard({
    required this.role,
    required this.lastUsed,
    this.onPressed,
  });
  final AppRole role;
  final bool lastUsed;
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) {
    final player = role == AppRole.player;
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.studyColors.surfaceRaised,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: lastUsed
              ? colors.primary.withValues(alpha: .5)
              : context.studyColors.outlineSoft,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: .1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  player ? Icons.play_arrow_rounded : Icons.dns_outlined,
                  color: colors.primary,
                  size: 28,
                ),
              ),
              if (lastUsed) ...[
                const Spacer(),
                Flexible(
                  child: Text(
                    'Last used',
                    textAlign: TextAlign.right,
                    style: Theme.of(
                      context,
                    ).textTheme.labelMedium?.copyWith(color: colors.primary),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          Text(
            player ? 'Player' : 'Server',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: MediaQuery.textScalerOf(context).scale(42),
            ),
            child: Text(
              player
                  ? 'Watch, listen, read and study your library.'
                  : 'Share this device’s libraries with your other devices.',
            ),
          ),
          const SizedBox(height: 12),
          Text(
            player
                ? 'Local files & connected libraries'
                : 'Sharing, pairing & progress sync',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onPressed,
              icon: const Icon(Icons.arrow_forward_rounded),
              label: Text(player ? 'Open player' : 'Open server'),
            ),
          ),
        ],
      ),
    );
  }
}
