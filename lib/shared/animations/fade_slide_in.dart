import 'package:flutter/material.dart';
import 'app_animations.dart';

/// A reusable entrance animation that combines a gentle fade with a
/// vertical slide. Used across all list-based pages for a cohesive feel.
class FadeSlideIn extends StatefulWidget {
  final Widget child;
  final Duration delay;
  final Duration duration;
  final double slideOffset;
  final Curve curve;

  const FadeSlideIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = AppAnimationDurations.normal,
    this.slideOffset = 18,
    this.curve = AppAnimationCurves.entrance,
  });

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<double> _translate;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );
    _opacity = CurvedAnimation(parent: _controller, curve: widget.curve);
    _translate = Tween<double>(begin: widget.slideOffset, end: 0).animate(
      CurvedAnimation(parent: _controller, curve: widget.curve),
    );

    Future.delayed(widget.delay, () {
      if (mounted) _controller.forward();
    });
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
        return Opacity(
          opacity: _opacity.value.clamp(0, 1),
          child: Transform.translate(
            offset: Offset(0, _translate.value),
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}

/// Wraps a list of children with staggered [FadeSlideIn] animations.
class StaggeredList extends StatelessWidget {
  final List<Widget> children;
  final Duration baseDelay;
  final Duration step;
  final EdgeInsets padding;

  const StaggeredList({
    super.key,
    required this.children,
    this.baseDelay = Duration.zero,
    this.step = AppAnimationDurations.staggerStep,
    this.padding = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < children.length; i++)
            FadeSlideIn(
              delay: baseDelay + step * i,
              child: children[i],
            ),
        ],
      ),
    );
  }
}
