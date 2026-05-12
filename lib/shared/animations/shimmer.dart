import 'package:flutter/material.dart';

/// A lightweight shimmer skeleton loader used while data streams are resolving.
/// The gradient sweep repeats smoothly — stops automatically when the parent
/// rebuilds with real data.
class Shimmer extends StatefulWidget {
  final Widget child;

  const Shimmer({super.key, required this.child});

  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final baseColor = Theme.of(context).colorScheme.surfaceContainerHighest;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ShaderMask(
          shaderCallback: (bounds) {
            return LinearGradient(
              colors: [
                baseColor.withValues(alpha: 0.4),
                baseColor.withValues(alpha: 0.8),
                baseColor.withValues(alpha: 0.4),
              ],
              stops: const [0.0, 0.5, 1.0],
              begin: Alignment(-1.2 + _controller.value * 2.4, 0),
              end: Alignment(-0.2 + _controller.value * 2.4, 0),
            ).createShader(bounds);
          },
          blendMode: BlendMode.srcATop,
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

/// Convenience builder that shows a shimmer placeholder while [loading] is true.
class ShimmerLoading extends StatelessWidget {
  final bool loading;
  final Widget child;
  final Widget placeholder;

  const ShimmerLoading({
    super.key,
    required this.loading,
    required this.child,
    required this.placeholder,
  });

  @override
  Widget build(BuildContext context) {
    if (!loading) return child;
    return Shimmer(child: placeholder);
  }
}
