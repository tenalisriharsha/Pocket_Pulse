import 'package:flutter/material.dart';
import '../animations/pulse.dart';

/// A small gamified badge that shows a "streak" of consecutive days
/// with activity. Encourages daily budget-checking habits.
class StreakBadge extends StatelessWidget {
  final int days;

  const StreakBadge({super.key, required this.days});

  @override
  Widget build(BuildContext context) {
    return Pulse(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFFA726), Color(0xFFFF7043)],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFF7043).withValues(alpha: 0.25),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.local_fire_department, color: Colors.white, size: 16),
            const SizedBox(width: 4),
            Text(
              '$days day streak',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
