import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app.dart';
import '../../core/theme/app_theme.dart';
import 'tangerine_opening_screen.dart';

/// Owns startup once per process, before mounting routes that need the database.
class TangerineStartup extends StatefulWidget {
  const TangerineStartup({super.key, required this.initialize});
  static const splashDuration = Duration(milliseconds: 2150);
  static const revealFraction = 1150 / 2150;
  final Future<ProviderContainer> Function(ValueChanged<String> phase)
  initialize;
  @override
  State<TangerineStartup> createState() => _TangerineStartupState();
}

class _TangerineStartupState extends State<TangerineStartup>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late final _intro = AnimationController(
    vsync: this,
    duration: TangerineStartup.splashDuration,
  )..addStatusListener(_introStatus);
  late final _reveal = _intro.drive(
    CurveTween(curve: const Interval(0, TangerineStartup.revealFraction)),
  );
  final _navigator = GlobalKey<NavigatorState>();
  late final _activity = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );
  ProviderContainer? _container;
  String _phase = 'Opening Tangerine';
  bool _failed = false, _working = false, _ready = false;
  bool _openingShown = false;
  bool get _reduced => WidgetsBinding
      .instance
      .platformDispatcher
      .accessibilityFeatures
      .disableAnimations;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Let the first branded frame paint before native/database initialization.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _start();
    });
  }

  void _introStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed || !mounted || _failed) return;
    if (_container != null) {
      _showOpening();
    } else if (!_reduced) {
      _activity.repeat();
    }
  }

  void _showOpening() {
    if (_openingShown || _container == null || _failed) return;
    _openingShown = true;
    _activity.stop();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _navigator.currentState!.pushReplacement(
        tangerineOpeningRoute(
          reducedMotion: _reduced,
          child: UncontrolledProviderScope(
            container: _container!,
            child: TangerineOpeningScreen(
              onContinue: () {
                if (mounted) setState(() => _ready = true);
              },
            ),
          ),
        ),
      );
    });
  }

  Future<void> _start() async {
    if (_working) return;
    setState(() {
      _working = true;
      _failed = false;
      _phase = 'Opening Tangerine';
    });
    _activity.reset();
    if (_reduced) {
      _intro.value = 1;
    } else {
      _intro.forward(from: 0);
    }
    try {
      final container = await widget.initialize((phase) {
        if (mounted) setState(() => _phase = phase);
      });
      if (!mounted) {
        container.dispose();
        return;
      }
      setState(() {
        _container = container;
        _working = false;
        _phase = 'Your library is ready';
      });
      if (_intro.isCompleted || _reduced) _showOpening();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _failed = true;
        _working = false;
      });
      _intro.value = 1;
      _activity.stop();
    }
  }

  @override
  void didChangeAccessibilityFeatures() {
    if (_reduced) {
      _activity.stop();
      _intro.value = 1;
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _intro.dispose();
    _activity.dispose();
    _container?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.ltr,
    child: SizedBox.expand(
      child: AnimatedSwitcher(
        layoutBuilder: (currentChild, previousChildren) => Stack(
          fit: StackFit.expand,
          children: [...previousChildren, ?currentChild],
        ),
        duration: _reduced ? Duration.zero : AppMotion.emphasized,
        child: _ready
            ? UncontrolledProviderScope(
                key: const ValueKey('app'),
                container: _container!,
                child: const StudyMediaPlayerApp(),
              )
            : MaterialApp(
                key: const ValueKey('opening'),
                title: 'Tangerine',
                navigatorKey: _navigator,
                debugShowCheckedModeBanner: false,
                theme: AppTheme.light(),
                darkTheme: AppTheme.dark(),
                home: TangerineSplashScreen(
                  intro: _reveal,
                  activity: _activity,
                  phase: _phase,
                  failed: _failed,
                  onRetry: _start,
                ),
              ),
      ),
    ),
  );
}

/// Brand-only presentation: no files, player, navigation or application state.
class TangerineSplashScreen extends StatelessWidget {
  const TangerineSplashScreen({
    super.key,
    required this.intro,
    required this.activity,
    this.phase = 'Opening your library',
    this.failed = false,
    this.onRetry,
  });
  final Animation<double> intro, activity;
  final String phase;
  final bool failed;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final ink = dark ? const Color(0xfffff6eb) : const Color(0xff302b26);
    const orange = Color(0xffed822b);
    return Scaffold(
      backgroundColor: dark ? const Color(0xff191b1a) : const Color(0xfff8f4ee),
      body: AnimatedBuilder(
        animation: Listenable.merge([intro, activity]),
        builder: (context, _) {
          final reduced = MediaQuery.disableAnimationsOf(context);
          final t = reduced ? 1.0 : intro.value;
          final mark = Curves.easeOutCubic.transform((t / .65).clamp(0, 1));
          final words = Curves.easeOutCubic.transform(
            ((t - .2) / .55).clamp(0, 1),
          );
          final line = Curves.easeOut.transform(((t - .4) / .5).clamp(0, 1));
          return Stack(
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(0, -.2),
                      radius: .85,
                      colors: [
                        orange.withValues(alpha: .11 * mark),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              SafeArea(
                child: LayoutBuilder(
                  builder: (context, box) => SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: box.maxHeight),
                      child: Padding(
                        padding: const EdgeInsets.all(28),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 420),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Opacity(
                                  opacity: mark,
                                  child: Transform.scale(
                                    scale: .8 + .2 * mark,
                                    child: Transform.rotate(
                                      angle: -.12 * (1 - mark),
                                      child: SizedBox.square(
                                        dimension: 174,
                                        child: CustomPaint(
                                          painter: _OpeningOrbit(mark, orange),
                                          child: Center(
                                            child: const TangerineOpeningMark(
                                              size: 108,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 20),
                                Opacity(
                                  opacity: words,
                                  child: Transform.translate(
                                    offset: Offset(0, 12 * (1 - words)),
                                    child: Text(
                                      'Tangerine',
                                      style: Theme.of(context)
                                          .textTheme
                                          .displaySmall
                                          ?.copyWith(
                                            color: ink,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: -1.2,
                                          ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Opacity(
                                  opacity: line,
                                  child: Text(
                                    'Watch. Read. Learn.',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(
                                          color: ink.withValues(alpha: .65),
                                          letterSpacing: 1.1,
                                        ),
                                  ),
                                ),
                                const SizedBox(height: 56),
                                if (failed) ...[
                                  Text(
                                    'Tangerine couldn’t finish opening',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: ink,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Check available storage and folder permissions, then try again. Your library has been kept.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: ink.withValues(alpha: .7),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  FilledButton.icon(
                                    onPressed: onRetry,
                                    icon: const Icon(Icons.refresh),
                                    label: const Text('Try again'),
                                  ),
                                ] else ...[
                                  ExcludeSemantics(
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        for (var i = 0; i < 3; i++)
                                          Padding(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 4,
                                            ),
                                            child: Opacity(
                                              opacity: reduced
                                                  ? .6
                                                  : .3 +
                                                        .7 *
                                                            (.5 +
                                                                .5 *
                                                                    math.cos(
                                                                      2 *
                                                                          math.pi *
                                                                          (activity.value -
                                                                              i / 3),
                                                                    )),
                                              child: const SizedBox.square(
                                                dimension: 5,
                                                child: DecoratedBox(
                                                  decoration: BoxDecoration(
                                                    color: orange,
                                                    shape: BoxShape.circle,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  Semantics(
                                    liveRegion: true,
                                    child: Text(
                                      phase,
                                      textAlign: TextAlign.center,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: ink.withValues(alpha: .6),
                                          ),
                                    ),
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
          );
        },
      ),
    );
  }
}

class _OpeningOrbit extends CustomPainter {
  const _OpeningOrbit(this.progress, this.color);
  final double progress;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final ring = (Offset.zero & size).deflate(5);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    stroke.color = color.withValues(alpha: .22);
    canvas.drawArc(ring, -.8, math.pi * 1.1 * progress, false, stroke);
    stroke.color = color.withValues(alpha: .55);
    canvas.drawArc(
      ring.deflate(7),
      2.6,
      math.pi * .2 * progress,
      false,
      stroke,
    );
    if (progress > 0) {
      final angle = -.8 + math.pi * 1.1 * progress;
      canvas.drawCircle(
        ring.center + Offset(math.cos(angle), math.sin(angle)) * ring.width / 2,
        3,
        Paint()..color = const Color(0xff83a666),
      );
    }
  }

  @override
  bool shouldRepaint(_OpeningOrbit old) =>
      old.progress != progress || old.color != color;
}
