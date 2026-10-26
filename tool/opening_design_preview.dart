// Isolated visual review of the full launch animation and mode-chooser layout.
// It never initializes the app, opens a database or starts a server.
import 'package:flutter/material.dart';
import 'dart:io';
import '../lib/core/theme/app_theme.dart';
import '../lib/domain/models/device_configuration.dart';
import '../lib/features/setup/tangerine_startup.dart';
import '../lib/features/setup/tangerine_opening_screen.dart';

void main() {
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    try {
      File(
        '${Directory.systemTemp.path}/tangerine-opening-preview.log',
      ).writeAsStringSync('${details.toString()}\n', mode: FileMode.append);
    } catch (_) {}
  };
  runApp(const _Preview());
}

class _Preview extends StatefulWidget {
  const _Preview();
  @override
  State<_Preview> createState() => _PreviewState();
}

class _PreviewState extends State<_Preview> with TickerProviderStateMixin {
  final _navigator = GlobalKey<NavigatorState>();
  late final _intro =
      AnimationController(
        vsync: this,
        duration: TangerineStartup.splashDuration,
      )..addStatusListener((status) {
        if (status != AnimationStatus.completed || !mounted) return;
        _navigator.currentState!.pushReplacement(
          tangerineOpeningRoute(
            child: TangerineOpeningView(
              lastRole: AppRole.player,
              onChoose: (_) {},
            ),
          ),
        );
      });
  late final _reveal = _intro.drive(
    CurveTween(curve: const Interval(0, TangerineStartup.revealFraction)),
  );
  late final _activity = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );
  bool _dark = false;
  Widget _splash() => TangerineSplashScreen(
    intro: _reveal,
    activity: _activity,
    phase: 'Your library is ready',
  );
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _intro.forward();
    });
  }

  void _replay() {
    _intro.reset();
    _navigator.currentState!.pushReplacement(
      PageRouteBuilder<void>(
        transitionDuration: Duration.zero,
        pageBuilder: (_, _, _) => _splash(),
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _intro.forward();
    });
  }

  @override
  void dispose() {
    _intro.dispose();
    _activity.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    navigatorKey: _navigator,
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light(),
    darkTheme: AppTheme.dark(),
    themeMode: _dark ? ThemeMode.dark : ThemeMode.light,
    home: _splash(),
    builder: (context, child) => Stack(
      children: [
        child!,
        Positioned(
          bottom: 4,
          right: 8,
          child: SafeArea(
            child: Material(
              color: Theme.of(
                context,
              ).colorScheme.surface.withValues(alpha: .9),
              borderRadius: BorderRadius.circular(8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Padding(
                    padding: EdgeInsets.all(8),
                    child: Text(
                      'DESIGN PREVIEW · no library access',
                      style: TextStyle(fontSize: 10),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _replay,
                    icon: const Icon(Icons.replay),
                    label: const Text('Replay'),
                  ),
                  TextButton.icon(
                    onPressed: () => setState(() => _dark = !_dark),
                    icon: const Icon(Icons.brightness_6_outlined),
                    label: const Text('Theme'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
