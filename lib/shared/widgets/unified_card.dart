import 'package:flutter/material.dart';

/// The single shared card component used across all PocketPulse pages.
/// Ensures consistent padding, radius, elevation, and hover lift.
class UnifiedCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final double elevation;
  final double radius;

  const UnifiedCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(14),
    this.color,
    this.elevation = 0,
    this.radius = 16,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bg = color ?? cs.surfaceContainerHighest.withValues(alpha: 0.35);

    return MouseRegion(
      cursor: onTap != null ? SystemMouseCursors.click : MouseCursor.defer,
      child: GestureDetector(
        onTap: onTap,
        child: Card(
          elevation: elevation,
          shadowColor: Colors.black.withValues(alpha: 0.04),
          color: bg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius),
          ),
          margin: EdgeInsets.zero,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}
