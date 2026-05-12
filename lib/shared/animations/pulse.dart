import 'package:flutter/material.dart';

/// A subtle repeating pulse used to draw attention to overdue items or
/// important alerts without being aggressive.
class Pulse extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final double minScale;
  final double maxScale;

  const Pulse({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 1500),
    this.minScale = 1.0,
    this.maxScale = 1.04,
  });

  @override
  State<Pulse> createState() => _PulseState();
}

class _PulseState extends State<Pulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );
    _controller.repeat(reverse: true);
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
        final scale = Tween<double>(
          begin: widget.minScale,
          end: widget.maxScale,
        ).evaluate(_controller);
        return Transform.scale(scale: scale, child: child);
      },
      child: widget.child,
    );
  }
}
