// Manual visual preview only. No startup, database, media or device access.
import 'package:flutter/material.dart';
import '../lib/core/theme/app_theme.dart';
import '../lib/features/setup/tangerine_startup.dart';

void main() => runApp(const _Preview());

class _Preview extends StatefulWidget {
  const _Preview();
  @override
  State<_Preview> createState() => _PreviewState();
}

class _PreviewState extends State<_Preview> with TickerProviderStateMixin {
  late final _intro = AnimationController(
    vsync: this,
    duration: TangerineStartup.splashDuration,
  )..forward();
  late final _reveal = _intro.drive(
    CurveTween(curve: const Interval(0, TangerineStartup.revealFraction)),
  );
  late final _activity = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();
  bool _dark = false, _failed = false;
  @override
  void dispose() {
    _intro.dispose();
    _activity.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light(),
    darkTheme: AppTheme.dark(),
    themeMode: _dark ? ThemeMode.dark : ThemeMode.light,
    home: Stack(
      children: [
        TangerineSplashScreen(
          intro: _reveal,
          activity: _activity,
          failed: _failed,
          onRetry: () => setState(() => _failed = false),
        ),
        SafeArea(
          child: Material(
            color: Colors.transparent,
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text('DESIGN PREVIEW · no library access'),
                ),
                IconButton(
                  tooltip: 'Replay animation',
                  onPressed: () => _intro.forward(from: 0),
                  icon: const Icon(Icons.replay),
                ),
                IconButton(
                  tooltip: 'Toggle preview theme',
                  onPressed: () => setState(() => _dark = !_dark),
                  icon: const Icon(Icons.brightness_6_outlined),
                ),
                IconButton(
                  tooltip: 'Toggle error layout preview',
                  onPressed: () => setState(() => _failed = !_failed),
                  icon: const Icon(Icons.error_outline),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}
