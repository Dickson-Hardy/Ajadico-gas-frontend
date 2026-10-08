import 'package:flutter/material.dart';

/// Wraps view switches with subtle, 60fps fade-and-slide page transitions.
class PageTransitionSwitcher extends StatelessWidget {
  final Widget child;
  final Duration duration;

  const PageTransitionSwitcher({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 220),
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: duration,
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        final slideAnimation = Tween<Offset>(
          begin: const Offset(0.0, 0.025), // Subtle 2.5% vertical offset
          end: Offset.zero,
        ).animate(animation);

        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: slideAnimation,
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}
