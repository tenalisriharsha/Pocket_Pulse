import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'app_animations.dart';

/// Smooth shared-axis style transition for GoRouter pages.
CustomTransitionPage<void> slideFadePage({
  required Widget child,
  required LocalKey key,
  String? name,
  Object? arguments,
}) {
  return CustomTransitionPage<void>(
    key: key,
    name: name,
    arguments: arguments,
    child: child,
    transitionDuration: AppAnimationDurations.normal,
    reverseTransitionDuration: AppAnimationDurations.fast,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final fade = CurvedAnimation(
        parent: animation,
        curve: AppAnimationCurves.entrance,
      );
      final slide = Tween<Offset>(
        begin: const Offset(0.04, 0),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: animation,
        curve: AppAnimationCurves.entrance,
      ));
      return FadeTransition(
        opacity: fade,
        child: SlideTransition(
          position: slide,
          child: child,
        ),
      );
    },
  );
}

/// Bottom-sheet style slide-up for modal pages (add transaction, etc.).
CustomTransitionPage<void> slideUpPage({
  required Widget child,
  required LocalKey key,
  String? name,
}) {
  return CustomTransitionPage<void>(
    key: key,
    name: name,
    child: child,
    transitionDuration: AppAnimationDurations.slow,
    reverseTransitionDuration: AppAnimationDurations.normal,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final slide = Tween<Offset>(
        begin: const Offset(0, 0.08),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: animation,
        curve: AppAnimationCurves.entrance,
      ));
      final fade = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOut,
      );
      return FadeTransition(
        opacity: fade,
        child: SlideTransition(
          position: slide,
          child: child,
        ),
      );
    },
  );
}
