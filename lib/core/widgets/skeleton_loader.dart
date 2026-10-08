import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// Lightweight, 60fps shimmer animation wrapper for async skeleton loading states.
class Shimmer extends StatefulWidget {
  final Widget child;
  final Duration duration;

  const Shimmer({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 1500),
  });

  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration)..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0);
    final highlightColor = isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              stops: [
                (_controller.value - 0.3).clamp(0.0, 1.0),
                _controller.value.clamp(0.0, 1.0),
                (_controller.value + 0.3).clamp(0.0, 1.0),
              ],
              colors: [
                baseColor,
                highlightColor,
                baseColor,
              ],
            ).createShader(bounds);
          },
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

/// Generic skeleton rectangle box
class SkeletonBox extends StatelessWidget {
  final double? width;
  final double height;
  final double borderRadius;

  const SkeletonBox({
    super.key,
    this.width,
    required this.height,
    this.borderRadius = 8,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }
}

/// Skeleton placeholder for dashboard metric cards
class SkeletonCard extends StatelessWidget {
  final double? width;
  final double height;

  const SkeletonCard({
    super.key,
    this.width,
    this.height = 120,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Shimmer(
      child: Container(
        width: width,
        height: height,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : AppColors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isDark ? AppColors.darkLine : AppColors.line),
        ),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            SkeletonBox(width: 80, height: 12),
            SkeletonBox(width: 140, height: 26),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                SkeletonBox(width: 60, height: 10),
                SkeletonBox(width: 40, height: 10),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Skeleton placeholder for transaction and submission tables
class SkeletonTableRows extends StatelessWidget {
  final int count;

  const SkeletonTableRows({super.key, this.count = 4});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Shimmer(
      child: Column(
        children: List.generate(count, (index) {
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : AppColors.card,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: isDark ? AppColors.darkLine : AppColors.line),
            ),
            child: const Row(
              children: [
                SkeletonBox(width: 36, height: 36, borderRadius: 18),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SkeletonBox(width: 120, height: 14),
                      SizedBox(height: 6),
                      SkeletonBox(width: 80, height: 10),
                    ],
                  ),
                ),
                SizedBox(width: 12),
                SkeletonBox(width: 70, height: 18),
              ],
            ),
          );
        }),
      ),
    );
  }
}
