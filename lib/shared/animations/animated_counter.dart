import 'package:flutter/material.dart';
import 'app_animations.dart';

/// Animates a number counting up/down to a target value.
/// Gives a satisfying "tallying" feel when financial figures appear.
class AnimatedCounter extends StatefulWidget {
  final int target;
  final String Function(int value) formatter;
  final TextStyle? style;
  final Duration duration;
  final Curve curve;

  const AnimatedCounter({
    super.key,
    required this.target,
    required this.formatter,
    this.style,
    this.duration = AppAnimationDurations.slow,
    this.curve = AppAnimationCurves.standard,
  });

  @override
  State<AnimatedCounter> createState() => _AnimatedCounterState();
}

class _AnimatedCounterState extends State<AnimatedCounter>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late Animation<int> _value;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _initAnimation();
    _controller.forward();
  }

  @override
  void didUpdateWidget(covariant AnimatedCounter old) {
    super.didUpdateWidget(old);
    if (old.target != widget.target) {
      _initAnimation(from: old.target);
      _controller.forward(from: 0);
    }
  }

  void _initAnimation({int from = 0}) {
    _value = IntTween(begin: from, end: widget.target).animate(
      CurvedAnimation(parent: _controller, curve: widget.curve),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _value,
      builder: (context, _) {
        return Text(
          widget.formatter(_value.value),
          style: widget.style,
        );
      },
    );
  }
}
