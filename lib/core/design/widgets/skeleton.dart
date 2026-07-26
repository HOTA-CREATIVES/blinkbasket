import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../app_tokens.dart';

/// Shimmering placeholder shown while content streams in.
class SkeletonBox extends StatelessWidget {
  final double? width;
  final double? height;
  final double radius;

  const SkeletonBox({super.key, this.width, this.height, this.radius = AppTokens.rMd});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

class _ShimmerWrap extends StatelessWidget {
  final Widget child;
  const _ShimmerWrap({required this.child});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return RepaintBoundary(
      child: Shimmer.fromColors(
        baseColor: scheme.surfaceContainerHighest,
        highlightColor: scheme.surface,
        child: child,
      ),
    );
  }
}

/// Product-grid skeleton for the shop tab.
class SkeletonProductGrid extends StatelessWidget {
  const SkeletonProductGrid({super.key});

  @override
  Widget build(BuildContext context) {
    return _ShimmerWrap(
      child: GridView.builder(
        padding: const EdgeInsets.all(AppTokens.s16),
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.68,
          crossAxisSpacing: AppTokens.s12,
          mainAxisSpacing: AppTokens.s12,
        ),
        itemCount: 6,
        itemBuilder: (_, __) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Expanded(child: SkeletonBox(width: double.infinity, radius: AppTokens.rLg)),
            SizedBox(height: AppTokens.s8),
            SkeletonBox(width: 110, height: 14),
            SizedBox(height: AppTokens.s4 + 2),
            SkeletonBox(width: 70, height: 12),
            SizedBox(height: AppTokens.s8),
            SkeletonBox(width: double.infinity, height: 34),
          ],
        ),
      ),
    );
  }
}

/// Card-list skeleton for order lists.
class SkeletonList extends StatelessWidget {
  const SkeletonList({super.key});

  @override
  Widget build(BuildContext context) {
    return _ShimmerWrap(
      child: ListView.separated(
        padding: const EdgeInsets.all(AppTokens.s16),
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 4,
        separatorBuilder: (_, __) => const SizedBox(height: AppTokens.s12),
        itemBuilder: (_, __) =>
            const SkeletonBox(width: double.infinity, height: 130, radius: AppTokens.rLg),
      ),
    );
  }
}
