// lib/widgets/search/search_chips.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lumio_tv/theme/tokens/colors.dart' as tokens;
import 'package:lumio_tv/theme/tokens/radius.dart' as tokens;
import 'package:lumio_tv/theme/tokens/spacing.dart' as tokens;
import 'package:lumio_tv/theme/tokens/typography.dart' as tokens;
import 'package:lumio_tv/widgets/common/pressable.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// A search chip widget with optional remove button
class SearchChip extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final VoidCallback? onRemove;
  final bool isSelected;

  const SearchChip({
    super.key,
    required this.label,
    this.onTap,
    this.onRemove,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: tokens.SpacingTokens.s16,
          vertical: tokens.SpacingTokens.s12,
        ),
        decoration: BoxDecoration(
          color: isSelected 
              ? tokens.AppTokens.accentMuted 
              : tokens.AppTokens.surface2,
          borderRadius: BorderRadius.circular(tokens.RadiusTokens.lg),
          border: Border.all(
            color: isSelected 
                ? tokens.AppTokens.accent 
                : tokens.AppTokens.border,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (onRemove != null) ...[
              Text(
                label,
                style: isSelected 
                    ? tokens.TypographyTokens.labelAccent 
                    : tokens.TypographyTokens.labelPrimary,
              ),
              SizedBox(width: tokens.SpacingTokens.s8),
              Pressable(
                onTap: onRemove,
                child: Icon(
                  PhosphorIcons.x(),
                  size: 16,
                  color: isSelected 
                      ? tokens.AppTokens.accent 
                      : tokens.AppTokens.textSecondary,
                ),
              ),
            ] else
              Text(
                label,
                style: isSelected 
                    ? tokens.TypographyTokens.labelAccent 
                    : tokens.TypographyTokens.labelPrimary,
              ),
          ],
        ),
      ),
    );
  }
}

/// Section for recent searches with remove functionality
class RecentSearches extends StatelessWidget {
  final List<String> searches;
  final Function(String) onTap;
  final Function(String) onRemove;

  const RecentSearches({
    super.key,
    required this.searches,
    required this.onTap,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    if (searches.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: tokens.SpacingTokens.s24,
            vertical: tokens.SpacingTokens.s16,
          ),
          child: Text(
            'Recent searches',
            style: tokens.TypographyTokens.labelTertiary,
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: tokens.SpacingTokens.s24),
          child: Wrap(
            spacing: tokens.SpacingTokens.s8,
            runSpacing: tokens.SpacingTokens.s8,
            children: searches.map((search) {
              return SearchChip(
                label: search,
                onTap: () => onTap(search),
                onRemove: () {
                  HapticFeedback.lightImpact();
                  onRemove(search);
                },
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

/// Section for trending searches
class TrendingSearches extends StatelessWidget {
  final List<String> trends;
  final Function(String) onTap;

  const TrendingSearches({
    super.key,
    required this.trends,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (trends.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: tokens.SpacingTokens.s24,
            vertical: tokens.SpacingTokens.s16,
          ),
          child: Text(
            'Trending',
            style: tokens.TypographyTokens.labelTertiary,
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: tokens.SpacingTokens.s24),
          child: Wrap(
            spacing: tokens.SpacingTokens.s8,
            runSpacing: tokens.SpacingTokens.s8,
            children: trends.map((trend) {
              return SearchChip(
                label: trend,
                onTap: () => onTap(trend),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

/// Category grid for browsing by category
class CategoryGrid extends StatelessWidget {
  final List<CategoryItem> categories;
  final Function(CategoryItem) onTap;

  const CategoryGrid({
    super.key,
    required this.categories,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (categories.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: tokens.SpacingTokens.s24,
            vertical: tokens.SpacingTokens.s16,
          ),
          child: Text(
            'Browse by category',
            style: tokens.TypographyTokens.labelTertiary,
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: tokens.SpacingTokens.s24),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 16 / 9,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: categories.length,
            itemBuilder: (context, index) {
              final category = categories[index];
              return Pressable(
                onTap: () => onTap(category),
                child: Container(
                  decoration: BoxDecoration(
                    color: tokens.AppTokens.surface2,
                    borderRadius: BorderRadius.circular(tokens.RadiusTokens.md),
                    border: Border.all(
                      color: tokens.AppTokens.border,
                      width: 1,
                    ),
                  ),
                  child: Stack(
                    children: [
                      // Category background/image
                      if (category.image != null)
                        Positioned.fill(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(tokens.RadiusTokens.md),
                            child: Image.network(
                              category.image!,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  color: tokens.AppTokens.surface3,
                                );
                              },
                            ),
                          ),
                        )
                      else
                        Positioned.fill(
                          child: Container(
                            color: tokens.AppTokens.surface3,
                          ),
                        ),
                      
                      // Gradient overlay
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(tokens.RadiusTokens.md),
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withValues(alpha: 0.7),
                              ],
                            ),
                          ),
                        ),
                      ),
                      
                      // Category label
                      Positioned(
                        bottom: tokens.SpacingTokens.s12,
                        left: tokens.SpacingTokens.s12,
                        right: tokens.SpacingTokens.s12,
                        child: Text(
                          category.label,
                          style: tokens.TypographyTokens.labelPrimary,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Data model for category grid items
class CategoryItem {
  final String label;
  final String? image;
  final String? query;

  CategoryItem({
    required this.label,
    this.image,
    this.query,
  });
}