import 'package:flutter/material.dart';
import 'app_animations.dart';

/// A horizontal shake used for error alerts or budget overruns.
/// The animation plays once and stops — no continuous loop.
class Shake extends StatefulWidget {
  final Widget child;
  final bool shake;
  final Duration duration;
  final double amplitude;

  const Shake({
    super.key,
    required this.child,
    this.shake = false,
    this.duration = AppAnimationDurations.normal,
    this.amplitude = 8,
  });

  @override
  State<Shake> createState() => _ShakeState();
}

class _ShakeState extends State<Shake>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );
  }

  @override
  void didUpdateWidget(covariant Shake old) {
    super.didUpdateWidget(old);
    if (!old.shake && widget.shake) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final progress = _controller.value;
        // Damped sine wave: 3 quick oscillations that settle
        final offset = widget.amplitude *
            (1 - progress) *
            (progress < 0.33
                ? -1
                : progress < 0.66
                    ? 1
                    : -0.5);
        return Transform.translate(
          offset: Offset(offset, 0),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}
