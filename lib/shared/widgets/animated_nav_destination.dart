import 'dart:math' as math;
import 'package:flutter/material.dart';

/// A catchy, bouncy bottom-nav destination with spring animations.
///
/// When selected the icon pops with a scale + slight rotation, a dot
/// bounces in below it, and the label slides up.  Everything uses an
/// elastic/spring curve so it feels alive but controlled.
class AnimatedNavDestination extends StatelessWidget {
  final bool isSelected;
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final VoidCallback onTap;

  const AnimatedNavDestination({
    super.key,
    required this.isSelected,
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        splashColor: cs.primary.withValues(alpha: 0.08),
        highlightColor: cs.primary.withValues(alpha: 0.04),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // ── Icon with pop + rotation ──
              _BouncyIcon(
                isSelected: isSelected,
                icon: icon,
                activeIcon: activeIcon,
                activeColor: cs.primary,
                inactiveColor: cs.onSurfaceVariant,
              ),
              const SizedBox(height: 2),
              // ── Indicator dot ──
              _BouncyDot(isSelected: isSelected, color: cs.primary),
              const SizedBox(height: 2),
              // ── Label ──
              _SlidingLabel(
                isSelected: isSelected,
                label: label,
                activeColor: cs.primary,
                inactiveColor: cs.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Bouncy Icon — scale pop + slight rotation on select
// ═══════════════════════════════════════════════════════════════════

class _BouncyIcon extends StatelessWidget {
  final bool isSelected;
  final IconData icon;
  final IconData activeIcon;
  final Color activeColor;
  final Color inactiveColor;

  const _BouncyIcon({
    required this.isSelected,
    required this.icon,
    required this.activeIcon,
    required this.activeColor,
    required this.inactiveColor,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: isSelected ? 1 : 0),
      duration: const Duration(milliseconds: 450),
      curve: const _SpringCurve(spring: 0.4),
      builder: (context, t, child) {
        final safeT = t.clamp(0.0, 1.0);
        // scale: 1.0 -> 1.22 -> 1.12
        final scale = 1.0 + (0.22 * safeT);
        // rotate: -6° -> 0° (subtle twist on activation)
        final rotation = -0.10 * (1 - safeT);
        return Transform.scale(
          scale: scale,
          child: Transform.rotate(
            angle: rotation,
            child: Icon(
              isSelected ? activeIcon : icon,
              size: 24,
              color: Color.lerp(inactiveColor, activeColor, safeT),
            ),
          ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Bouncy Dot — small indicator that springs up from below
// ═══════════════════════════════════════════════════════════════════

class _BouncyDot extends StatelessWidget {
  final bool isSelected;
  final Color color;

  const _BouncyDot({required this.isSelected, required this.color});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: isSelected ? 1 : 0),
      duration: const Duration(milliseconds: 500),
      curve: const _SpringCurve(spring: 0.35),
      builder: (context, t, _) {
        final safeT = t.clamp(0.0, 1.0);
        return Opacity(
          opacity: safeT,
          child: Transform.scale(
            scale: safeT,
            child: Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
          ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Sliding Label — slides up slightly when selected
// ═══════════════════════════════════════════════════════════════════

class _SlidingLabel extends StatelessWidget {
  final bool isSelected;
  final String label;
  final Color activeColor;
  final Color inactiveColor;

  const _SlidingLabel({
    required this.isSelected,
    required this.label,
    required this.activeColor,
    required this.inactiveColor,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: isSelected ? 1 : 0),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      builder: (context, t, _) {
        final safeT = t.clamp(0.0, 1.0);
        final yOffset = 2.0 * (1 - safeT); // slides up 2px when selected
        return Transform.translate(
          offset: Offset(0, yOffset),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: Color.lerp(inactiveColor, activeColor, safeT),
            ),
          ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Spring Curve — overshoots then settles (elastic but controlled)
// ═══════════════════════════════════════════════════════════════════

class _SpringCurve extends Curve {
  final double spring;
  const _SpringCurve({this.spring = 0.4});

  @override
  double transform(double t) {
    if (t <= 0.0) return 0.0;
    if (t >= 1.0) return 1.0;
    final decay = math.exp(-t * 6.5);
    final oscillation = math.sin(t * 12.0) * spring;
    return (1.0 - decay * (1.0 - t + oscillation)).clamp(0.0, 1.0);
  }
}
