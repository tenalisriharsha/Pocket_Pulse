import 'package:flutter/material.dart';

/// Centralized animation configuration for PocketPulse.
/// All durations are intentionally short to keep the UI feeling snappy
/// and professional (banking-app tier).
class AppAnimationDurations {
  AppAnimationDurations._();

  /// Micro-interactions: button presses, icon toggles
  static const Duration fast = Duration(milliseconds: 150);

  /// Standard transitions: page fades, card slides
  static const Duration normal = Duration(milliseconds: 250);

  /// Emphasis animations: progress bars, counters
  static const Duration slow = Duration(milliseconds: 400);

  /// Celebratory sequences: confetti, achievement toasts
  static const Duration celebration = Duration(milliseconds: 700);

  /// Stagger base delay between list items
  static const Duration staggerStep = Duration(milliseconds: 35);
}

/// Curves that feel secure and professional — mostly ease-out variants
/// so UI elements "land" with confidence.
class AppAnimationCurves {
  AppAnimationCurves._();

  static const Curve standard = Curves.easeOutCubic;
  static const Curve entrance = Curves.easeOutQuart;
  static const Curve exit = Curves.easeInCubic;
  static const Curve elastic = Curves.elasticOut;
  static const Curve bounce = Curves.bounceOut;
  static const Curve decelerate = Curves.decelerate;
}
