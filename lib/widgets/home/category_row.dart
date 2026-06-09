// lib/widgets/home/category_row.dart
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:lumio_tv/l10n/strings.dart' as strings;
import 'package:lumio_tv/theme/tokens/colors.dart' as tokens;
import 'package:lumio_tv/theme/tokens/spacing.dart' as tokens;
import 'package:lumio_tv/theme/tokens/typography.dart' as tokens;
import 'package:lumio_tv/utils/haptic_helpers.dart';

/// Category row widget for home screen with horizontal scroll.
/// 
/// Features:
/// - Section title with "See all" link
/// - Horizontal scrolling content
/// - Variable tile dimensions per section
/// - Surface cards for tiles
class CategoryRow extends StatelessWidget {
  final String title;
  final List<CategoryTile> tiles;
  final double tileWidth;
  final double tileHeight;
  final VoidCallback? onSeeAll;
  final VoidCallback Function(CategoryTile tile)? onTileTap;

  const CategoryRow({
    super.key,
    required this.title,
    required this.tiles,
    required this.tileWidth,
    required this.tileHeight,
    this.onSeeAll,
    this.onTileTap,
  });

  @override
  Widget build(BuildContext context) {
    if (tiles.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Padding(
          padding: const EdgeInsets.only(
            top: tokens.SpacingTokens.s32,
            bottom: tokens.SpacingTokens.s16,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: tokens.TypographyTokens.titlePrimary,
              ),
              if (onSeeAll != null)
                GestureDetector(
                  onTap: () {
                    Haptics.buttonPress();
                    onSeeAll!();
                  },
                  child: Text(
                    'See all',
                    style: tokens.TypographyTokens.labelAccent,
                  ),
                ),
            ],
          ),
        ),
        
        // Horizontal scroll content
        SizedBox(
          height: tileHeight,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(
              horizontal: tokens.SpacingTokens.s16,
            ),
            itemCount: tiles.length,
            separatorBuilder: (context, index) => const SizedBox(
              width: tokens.SpacingTokens.s12,
            ),
            itemBuilder: (context, index) {
              final tile = tiles[index];
              return SizedBox(
                width: tileWidth,
                child: _CategoryTile(
                  tile: tile,
                  onTap: () {
                    if (onTileTap != null) {
                      Haptics.buttonPress();
                      onTileTap!(tile);
                    }
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _CategoryTile extends StatelessWidget {
  final CategoryTile tile;
  final VoidCallback? onTap;

  const _CategoryTile({
    required this.tile,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Thumbnail
          Expanded(
            child: ClipRRect(
              borderRadius: tokens.RadiusTokens.circularMd,
              child: CachedNetworkImage(
                imageUrl: tile.imageUrl,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  color: tokens.AppTokens.surface2,
                ),
                errorWidget: (context, url, error) => Container(
                  color: tokens.AppTokens.surface2,
                ),
              ),
            ),
          ),
          
          const SizedBox(height: tokens.SpacingTokens.s8),
          
          // Title
          Text(
            tile.title,
            style: tokens.TypographyTokens.bodyPrimary,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          
          if (tile.subtitle != null) ...[
            const SizedBox(height: tokens.SpacingTokens.s4),
            Text(
              tile.subtitle!,
              style: tokens.TypographyTokens.captionSecondary,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          
          // Live badge
          if (tile.isLive) ...[
            const SizedBox(height: tokens.SpacingTokens.s4),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: tokens.SpacingTokens.s8,
                vertical: tokens.SpacingTokens.s4,
              ),
              decoration: BoxDecoration(
                color: tokens.AppTokens.liveRed,
                borderRadius: tokens.RadiusTokens.circularSm,
              ),
              child: Text(
                strings.Strings.liveIndicator,
                style: tokens.TypographyTokens.captionPrimary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Category tile data model
class CategoryTile {
  final String title;
  final String? subtitle;
  final String imageUrl;
  final bool isLive;
  final String? channelId;
  final String? contentId;

  const CategoryTile({
    required this.title,
    this.subtitle,
    required this.imageUrl,
    this.isLive = false,
    this.channelId,
    this.contentId,
  });
}
