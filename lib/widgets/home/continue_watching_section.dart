// lib/widgets/home/continue_watching_section.dart
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:lumio_tv/theme/tokens.dart' as tokens;
import 'package:lumio_tv/utils/haptic_helpers.dart' as haptics;

/// Continue watching section for home screen.
///
/// Features:
/// - Horizontal scroll
/// - 16:9 thumbnails, 200px wide
/// - Progress bar on bottom of thumbnail (2px, accent color)
/// - Time remaining label below
class ContinueWatchingSection extends StatelessWidget {
  final List<ContinueWatchingItem> items;
  final VoidCallback? onSeeAll;
  final VoidCallback Function(ContinueWatchingItem item)? onItemTap;

  const ContinueWatchingSection({
    super.key,
    required this.items,
    this.onSeeAll,
    this.onItemTap,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
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
                'Continue watching',
                style: tokens.TypographyTokens.titlePrimary,
              ),
              if (onSeeAll != null)
                GestureDetector(
                  onTap: () {
                    haptics.Haptics.buttonPress();
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
          height:
              150, // 16:9 aspect ratio: 200px width = 112.5px height + padding
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(
              horizontal: tokens.SpacingTokens.s16,
            ),
            itemCount: items.length,
            separatorBuilder: (context, index) => const SizedBox(
              width: tokens.SpacingTokens.s12,
            ),
            itemBuilder: (context, index) {
              final item = items[index];
              return SizedBox(
                width: 200,
                child: _ContinueWatchingTile(
                  item: item,
                  onTap: () {
                    if (onItemTap != null) {
                      haptics.Haptics.buttonPress();
                      onItemTap!(item);
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

class _ContinueWatchingTile extends StatelessWidget {
  final ContinueWatchingItem item;
  final VoidCallback? onTap;

  const _ContinueWatchingTile({
    required this.item,
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
          // Thumbnail with progress bar
          Stack(
            children: [
              // Thumbnail (16:9 aspect ratio: 200px width = 112.5px height)
              ClipRRect(
                borderRadius: tokens.RadiusTokens.circularMd,
                child: CachedNetworkImage(
                  imageUrl: item.thumbnailUrl,
                  width: 200,
                  height: 112.5,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    width: 200,
                    height: 112.5,
                    color: tokens.AppTokens.surface2,
                  ),
                  errorWidget: (context, url, error) => Container(
                    width: 200,
                    height: 112.5,
                    color: tokens.AppTokens.surface2,
                  ),
                ),
              ),

              // Progress bar (2px, accent color)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(tokens.RadiusTokens.md),
                    bottomRight: Radius.circular(tokens.RadiusTokens.md),
                  ),
                  child: LinearProgressIndicator(
                    value: item.progress,
                    backgroundColor: tokens.AppTokens.surface3,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      tokens.AppTokens.accent,
                    ),
                    minHeight: 2,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: tokens.SpacingTokens.s8),

          // Title
          Text(
            item.title,
            style: tokens.TypographyTokens.bodyPrimary,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),

          const SizedBox(height: tokens.SpacingTokens.s4),

          // Time remaining
          Text(
            item.timeRemaining,
            style: tokens.TypographyTokens.captionSecondary,
          ),
        ],
      ),
    );
  }
}

/// Continue watching item data model
class ContinueWatchingItem {
  final String title;
  final String thumbnailUrl;
  final double progress; // 0.0 to 1.0
  final String timeRemaining;
  final String? channelId;
  final String? contentId;

  const ContinueWatchingItem({
    required this.title,
    required this.thumbnailUrl,
    required this.progress,
    required this.timeRemaining,
    this.channelId,
    this.contentId,
  });
}
