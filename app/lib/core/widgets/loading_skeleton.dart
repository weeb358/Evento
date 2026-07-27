import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Shimmering placeholder blocks for list/card loading states. Use
/// [SkeletonBox] directly for a single shape, or [EventCardSkeleton] /
/// [SkeletonList] for the common list-of-cards case.
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({
    super.key,
    this.width,
    this.height = 16,
    this.borderRadius = AppRadius.input,
  });

  final double? width;
  final double height;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: isDark ? AppColors.bgSurfaceRaisedDark : AppColors.bgSurfaceLight,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }
}

class EventCardSkeleton extends StatelessWidget {
  const EventCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SkeletonBox(height: 160, borderRadius: AppRadius.card),
          const SizedBox(height: AppSpacing.sm),
          SkeletonBox(width: MediaQuery.sizeOf(context).width * 0.6, height: 18),
          const SizedBox(height: AppSpacing.xs),
          SkeletonBox(width: MediaQuery.sizeOf(context).width * 0.4, height: 14),
        ],
      ),
    );
  }
}

class SkeletonList extends StatelessWidget {
  const SkeletonList({super.key, this.itemCount = 4, this.itemBuilder});

  final int itemCount;
  final Widget Function(BuildContext context, int index)? itemBuilder;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Shimmer.fromColors(
      baseColor: isDark ? AppColors.bgSurfaceDark : AppColors.borderLight,
      highlightColor: isDark ? AppColors.bgSurfaceRaisedDark : AppColors.bgSurfaceLight,
      child: ListView.builder(
        padding: const EdgeInsets.all(AppSpacing.lg),
        itemCount: itemCount,
        itemBuilder: itemBuilder ?? (context, index) => const EventCardSkeleton(),
      ),
    );
  }
}
