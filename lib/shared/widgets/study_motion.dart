import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

/// Animates a selection without remounting the pages or resetting scroll state.
class StudyPageTransition extends StatefulWidget {
  const StudyPageTransition({
    super.key,
    required this.selection,
    required this.child,
  });
  final Object selection;
  final Widget child;
  @override
  State<StudyPageTransition> createState() => _StudyPageTransitionState();
}

class _StudyPageTransitionState extends State<StudyPageTransition>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppMotion.emphasized,
    value: 1,
  );
  @override
  void didUpdateWidget(covariant StudyPageTransition oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selection != widget.selection) {
      _controller.duration = AppMotion.resolve(context, AppMotion.emphasized);
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: Tween<double>(
      begin: .82,
      end: 1,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic)),
    child: widget.child,
  );
}
