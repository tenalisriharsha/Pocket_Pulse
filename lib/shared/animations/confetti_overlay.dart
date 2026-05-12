import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'app_animations.dart';

/// A lightweight confetti burst that celebrates positive financial actions
/// (saving a transaction, hitting a budget goal, marking recurring as paid).
/// Particles are simple colored squares — no images, no heavy physics.
class ConfettiOverlay extends StatefulWidget {
  final VoidCallback? onComplete;

  const ConfettiOverlay({super.key, this.onComplete});

  @override
  State<ConfettiOverlay> createState() => _ConfettiOverlayState();
}

class _ConfettiOverlayState extends State<ConfettiOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  final List<_Particle> _particles = [];
  static const _count = 40;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppAnimationDurations.celebration,
    );

    final rand = math.Random();
    for (var i = 0; i < _count; i++) {
      _particles.add(_Particle(
        color: _colors[i % _colors.length],
        xStart: rand.nextDouble() * 0.6 + 0.2, // center band
        yStart: 0.3 + rand.nextDouble() * 0.2,
        velocityX: (rand.nextDouble() - 0.5) * 1.2,
        velocityY: rand.nextDouble() * 0.8 + 0.3,
        rotationSpeed: (rand.nextDouble() - 0.5) * 10,
        size: rand.nextDouble() * 6 + 4,
      ));
    }

    _controller.forward().then((_) {
      widget.onComplete?.call();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final progress = _controller.value;
          return CustomPaint(
            size: MediaQuery.of(context).size,
            painter: _ConfettiPainter(
              particles: _particles,
              progress: progress,
            ),
          );
        },
      ),
    );
  }
}

const _colors = [
  Color(0xFF4CAF50), // green
  Color(0xFF2196F3), // blue
  Color(0xFFFFC107), // amber
  Color(0xFFE91E63), // pink
  Color(0xFF9C27B0), // purple
  Color(0xFF00BCD4), // cyan
  Color(0xFFFF9800), // orange
];

class _Particle {
  final Color color;
  final double xStart;
  final double yStart;
  final double velocityX;
  final double velocityY;
  final double rotationSpeed;
  final double size;

  _Particle({
    required this.color,
    required this.xStart,
    required this.yStart,
    required this.velocityX,
    required this.velocityY,
    required this.rotationSpeed,
    required this.size,
  });
}

class _ConfettiPainter extends CustomPainter {
  final List<_Particle> particles;
  final double progress;

  _ConfettiPainter({required this.particles, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final x = size.width * p.xStart +
          p.velocityX * size.width * 0.3 * progress;
      final y = size.height * p.yStart +
          p.velocityY * size.height * progress +
          0.5 * 500 * progress * progress; // gravity

      final alpha = ((1 - progress) * 255).toInt().clamp(0, 255);
      final paint = Paint()..color = p.color.withAlpha(alpha);
      final rotation = p.rotationSpeed * progress;

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(rotation);
      canvas.drawRect(
        Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size * 0.6),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter old) => old.progress != progress;
}

/// Helper to trigger a confetti burst from anywhere via an Overlay.
class ConfettiHelper {
  static void burst(BuildContext context) {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => ConfettiOverlay(
        onComplete: () => entry.remove(),
      ),
    );
    overlay.insert(entry);
  }
}
