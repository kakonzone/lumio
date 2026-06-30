// lib/widgets/live/category_rail.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lumio_tv/l10n/strings.dart';
import 'package:lumio_tv/theme/tokens/colors.dart' as tokens;
import 'package:lumio_tv/theme/tokens/spacing.dart' as tokens;
import 'package:lumio_tv/theme/tokens/typography.dart' as tokens;
import 'package:lumio_tv/widgets/common/pressable.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// Category rail widget for left panel in Live TV screen
///
/// Features:
/// - 240px wide (fixed)
/// - Surface1 background
/// - Category list, vertical scroll
/// - Each row: icon + label, 44px height
/// - Active row: accent left border (3px), accent text
/// - Tap reloads channel list
class CategoryRail extends StatelessWidget {
  final List<CategoryItem> categories;
  final String selectedCategoryId;
  final Function(String) onCategoryTap;

  const CategoryRail({
    super.key,
    required this.categories,
    required this.selectedCategoryId,
    required this.onCategoryTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 240,
      decoration: const BoxDecoration(
        color: tokens.AppTokens.surface1,
        border: Border(
          right: BorderSide(
            color: tokens.AppTokens.border,
            width: 1,
          ),
        ),
      ),
      child: ListView.builder(
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final category = categories[index];
          final isSelected = category.id == selectedCategoryId;

          return Pressable(
            key: ValueKey(category.id),
            onTap: () {
              HapticFeedback.selectionClick();
              onCategoryTap(category.id);
            },
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color:
                    isSelected ? tokens.AppTokens.surface2 : Colors.transparent,
                border: Border(
                  left: BorderSide(
                    color: isSelected
                        ? tokens.AppTokens.accent
                        : Colors.transparent,
                    width: 3,
                  ),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: tokens.SpacingTokens.s16,
                ),
                child: Row(
                  children: [
                    // Icon
                    Icon(
                      category.icon,
                      size: 20,
                      color: isSelected
                          ? tokens.AppTokens.accent
                          : tokens.AppTokens.textSecondary,
                    ),
                    const SizedBox(width: tokens.SpacingTokens.s12),

                    // Label
                    Text(
                      category.label,
                      style: isSelected
                          ? tokens.TypographyTokens.labelAccent
                          : tokens.TypographyTokens.labelPrimary,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Category item data model
class CategoryItem {
  final String id;
  final String label;
  final IconData icon;

  CategoryItem({
    required this.id,
    required this.label,
    required this.icon,
  });

  /// Create predefined categories
  static List<CategoryItem> getDefaultCategories() {
    return [
      CategoryItem(
        id: 'all',
        label: Strings.categoryAll,
        icon: PhosphorIcons.television(),
      ),
      CategoryItem(
        id: 'sports',
        label: Strings.categorySports,
        icon: PhosphorIcons.soccerBall(),
      ),
      CategoryItem(
        id: 'movies',
        label: Strings.categoryMovies,
        icon: PhosphorIcons.filmStrip(),
      ),
      CategoryItem(
        id: 'news',
        label: Strings.categoryNews,
        icon: PhosphorIcons.newspaper(),
      ),
      CategoryItem(
        id: 'entertainment',
        label: Strings.categoryEntertainment,
        icon: PhosphorIcons.maskHappy(),
      ),
      CategoryItem(
        id: 'kids',
        label: Strings.categoryKids,
        icon: PhosphorIcons.baby(),
      ),
      CategoryItem(
        id: 'music',
        label: Strings.categoryMusic,
        icon: PhosphorIcons.musicNote(),
      ),
      CategoryItem(
        id: 'documentaries',
        label: Strings.categoryDocumentaries,
        icon: PhosphorIcons.bookOpen(),
      ),
      CategoryItem(
        id: 'religious',
        label: Strings.categoryReligious,
        icon: PhosphorIcons.star(),
      ),
    ];
  }
}
