import 'package:flutter/material.dart';

import 'app_theme.dart';

/// Single source for channel row colors — used by [ChannelListTile] everywhere.
class ChannelListStyle {
  ChannelListStyle._();

  static Color categoryAccent(String category) {
    switch (category.toLowerCase()) {
      case 'sports':
        return const Color(0xFF5C6BC0);
      case 'bangladesh':
        return const Color(0xFF26A69A);
      case 'pakistan':
        return const Color(0xFF43A047);
      case 'india':
        return const Color(0xFFFF8F00);
      case 'entertainment':
        return const Color(0xFFAB47BC);
      case 'movies':
        return const Color(0xFFEF5350);
      case 'kdrama':
        return const Color(0xFFEC407A);
      case 'english':
        return const Color(0xFF42A5F5);
      case 'kids':
        return const Color(0xFF66BB6A);
      default:
        return AppColors.accent;
    }
  }

  static BoxDecoration card({
    required BuildContext context,
    required bool showLive,
    required bool isPendingTap,
  }) {
    final bg = showLive ? context.liveCardTint : context.cardSurface;
    return BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(
        color: isPendingTap
            ? AppColors.accent
            : (showLive ? context.liveCardBorder : context.brd),
        width: isPendingTap ? 1.5 : 1,
      ),
      boxShadow: [
        BoxShadow(
          color: context.shadowColor,
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    );
  }

  static BoxDecoration liveBadge() {
    return BoxDecoration(
      color: AppColors.liveRed,
      borderRadius: BorderRadius.circular(6),
    );
  }

  static BoxDecoration categoryChip(
    BuildContext context,
    String category,
  ) {
    final accent = categoryAccent(category);
    return BoxDecoration(
      color: context.isDark
          ? accent.withValues(alpha: 0.14)
          : accent.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(6),
      border: Border.all(
        color: accent.withValues(alpha: context.isDark ? 0.35 : 0.28),
      ),
    );
  }
}
