import 'package:flutter/material.dart';

typedef _Background = ({Color first, Color second, bool vertical});

/// Two complete layers; a new request during a fade replaces the queued target.
/// This bounds residency and preserves the in-progress blend without a flash.
class ReaderBackgroundSurface extends StatefulWidget {
  const ReaderBackgroundSurface({
    super.key,
    required this.first,
    required this.second,
    this.vertical = false,
  });
  final Color first, second;
  final bool vertical;
  @override
  State<ReaderBackgroundSurface> createState() => _ReaderBackgroundState();
}

class _ReaderBackgroundState extends State<ReaderBackgroundSurface>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fade;
  late _Background _current;
  _Background? _target;
  bool _reduced = false;
  _Background get _requested =>
      (first: widget.first, second: widget.second, vertical: widget.vertical);
  @override
  void initState() {
    super.initState();
    _current = _requested;
    _fade =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 300),
        )..addStatusListener((status) {
          if (status != AnimationStatus.completed || !mounted) return;
          setState(() {
            _current = _target ?? _current;
            _target = null;
            _update();
          });
        });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduced = MediaQuery.disableAnimationsOf(context);
    _update();
  }

  @override
  void didUpdateWidget(covariant ReaderBackgroundSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    _update();
  }

  void _update() {
    if (_reduced) {
      _fade.stop();
      _current = _requested;
      _target = null;
    } else if (_target == null && _current != _requested) {
      _target = _requested;
      _fade.forward(from: 0);
    }
  }

  Widget _layer(_Background value) => DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: value.vertical ? Alignment.topCenter : Alignment.centerLeft,
        end: value.vertical ? Alignment.bottomCenter : Alignment.centerRight,
        colors: [value.first, value.first, value.second, value.second],
      ),
    ),
    child: const SizedBox.expand(),
  );
  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Stack(
      fit: StackFit.expand,
      children: [
        _layer(_current),
        if (_target != null)
          FadeTransition(opacity: _fade, child: _layer(_target!)),
      ],
    ),
  );
  @override
  void dispose() {
    _fade.dispose();
    super.dispose();
  }
}
