import 'package:flutter/material.dart';
import 'app_animations.dart';

/// Desktop-optimized hover effect that subtly lifts and scales a card
/// when the mouse enters. On touch devices it gracefully degrades to
/// a simple [ScaleTap] behavior.
class HoverCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double hoverScale;
  final double hoverElevation;
  final BorderRadius? borderRadius;

  const HoverCard({
    super.key,
    required this.child,
    this.onTap,
    this.hoverScale = 1.015,
    this.hoverElevation = 2,
    this.borderRadius,
  });

  @override
  State<HoverCard> createState() => _HoverCardState();
}

class _HoverCardState extends State<HoverCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _hover = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppAnimationDurations.fast,
      value: 0,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onEnter(_) {
    setState(() => _hover = true);
    _controller.forward();
  }

  void _onExit(_) {
    setState(() => _hover = false);
    _controller.reverse();
  }

  void _onTapDown(_) => _controller.animateTo(0.5);
  void _onTapUp(_) => _controller.animateTo(1.0);
  void _onTapCancel() => _controller.reverse();

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: _onEnter,
      onExit: _onExit,
      child: GestureDetector(
        onTap: widget.onTap,
        onTapDown: _onTapDown,
        onTapUp: _onTapUp,
        onTapCancel: _onTapCancel,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final scale = Tween<double>(begin: 1.0, end: widget.hoverScale)
                .evaluate(_controller);
            return Transform.scale(
              scale: scale,
              child: Material(
                color: Colors.transparent,
                elevation: _hover ? widget.hoverElevation : 0,
                borderRadius: widget.borderRadius,
                child: child,
              ),
            );
          },
          child: widget.child,
        ),
      ),
    );
  }
}
