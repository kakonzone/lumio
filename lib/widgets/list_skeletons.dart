import 'package:flutter/material.dart';

import 'common/widgets.dart';

/// Vertical list of channel-row skeletons (HOME / LIVE / SPORTS / category drill-down).
class ChannelListSkeleton extends StatelessWidget {
  const ChannelListSkeleton({
    super.key,
    this.count = 6,
    this.padding = const EdgeInsets.only(top: 8, bottom: 24),
  });

  final int count;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Column(
        children: List.generate(
          count,
          (_) => const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: ChannelCardShimmer(),
          ),
        ),
      ),
    );
  }
}

/// Horizontal score-card skeleton strip (NEWS live scores).
class ScoreRowSkeleton extends StatelessWidget {
  const ScoreRowSkeleton({super.key, this.count = 3});

  final int count;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 132,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: count,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, __) => const ScoreCardShimmer(),
      ),
    );
  }
}

/// Category grid placeholder (2-column).
class CategoryGridSkeleton extends StatelessWidget {
  const CategoryGridSkeleton({
    super.key,
    this.count = 6,
    this.crossAxisCount = 2,
  });

  final int count;
  final int crossAxisCount;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.45,
        ),
        itemCount: count,
        itemBuilder: (_, __) => const ShimmerBox(
          width: double.infinity,
          height: double.infinity,
          radius: 14,
        ),
      ),
    );
  }
}
