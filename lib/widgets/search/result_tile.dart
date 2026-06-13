// lib/widgets/search/result_tile.dart
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:lumio_tv/l10n/strings.dart';
import 'package:lumio_tv/theme/tokens/colors.dart' as tokens;
import 'package:lumio_tv/theme/tokens/radius.dart' as tokens;
import 'package:lumio_tv/theme/tokens/spacing.dart' as tokens;
import 'package:lumio_tv/theme/tokens/typography.dart' as tokens;
import 'package:lumio_tv/widgets/common/pressable.dart';
import 'package:lumio_tv/widgets/common/skeleton.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// Type of search result
enum SearchResultType {
  channel,
  movie,
  series,
  epg,
}

/// Search result data model
class SearchResult {
  final String id;
  final String title;
  final String? subtitle;
  final String? thumbnail;
  final SearchResultType type;
  final bool isLive;
  final String? metadata; // e.g., "2024 • 2h 30m"
  final String? matchedQuery; // for highlighting

  SearchResult({
    required this.id,
    required this.title,
    this.subtitle,
    this.thumbnail,
    required this.type,
    this.isLive = false,
    this.metadata,
    this.matchedQuery,
  });
}

/// A search result tile with thumbnail, title, metadata, and optional LIVE badge
class ResultTile extends StatelessWidget {
  final SearchResult result;
  final VoidCallback? onTap;

  const ResultTile({
    super.key,
    required this.result,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Container(
        height: 88,
        padding: EdgeInsets.symmetric(
          horizontal: tokens.SpacingTokens.s16,
          vertical: tokens.SpacingTokens.s12,
        ),
        decoration: BoxDecoration(
          color: tokens.AppTokens.surface1,
          border: Border(
            bottom: BorderSide(
              color: tokens.AppTokens.border,
              width: 1,
            ),
          ),
        ),
        child: Row(
          children: [
            // Thumbnail
            _Thumbnail(
              imageUrl: result.thumbnail,
              type: result.type,
              isLive: result.isLive,
            ),
            SizedBox(width: tokens.SpacingTokens.s12),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Title with highlighting
                  _HighlightedTitle(
                    title: result.title,
                    matchedQuery: result.matchedQuery,
                  ),

                  if (result.subtitle != null) ...[
                    SizedBox(height: tokens.SpacingTokens.s4),
                    Text(
                      result.subtitle!,
                      style: tokens.TypographyTokens.captionSecondary,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],

                  if (result.metadata != null) ...[
                    SizedBox(height: tokens.SpacingTokens.s4),
                    Text(
                      result.metadata!,
                      style: tokens.TypographyTokens.captionTertiary,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),

            // Type indicator / LIVE badge
            if (result.isLive)
              _LiveBadge()
            else
              _TypeIndicator(type: result.type),
          ],
        ),
      ),
    );
  }
}

/// Thumbnail widget with loading/error states
class _Thumbnail extends StatelessWidget {
  final String? imageUrl;
  final SearchResultType type;
  final bool isLive;

  const _Thumbnail({
    this.imageUrl,
    required this.type,
    required this.isLive,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(tokens.RadiusTokens.sm),
      child: SizedBox(
        width: 120,
        height: 64,
        child: imageUrl != null
            ? CachedNetworkImage(
                imageUrl: imageUrl!,
                fit: BoxFit.cover,
                placeholder: (context, url) => Skeleton(
                  width: 120,
                  height: 64,
                  borderRadius: BorderRadius.circular(tokens.RadiusTokens.sm),
                ),
                errorWidget: (context, url, error) =>
                    _ThumbnailFallback(type: type),
              )
            : _ThumbnailFallback(type: type),
      ),
    );
  }
}

/// Fallback thumbnail when no image or error loading
class _ThumbnailFallback extends StatelessWidget {
  final SearchResultType type;

  const _ThumbnailFallback({required this.type});

  @override
  Widget build(BuildContext context) {
    IconData icon;
    switch (type) {
      case SearchResultType.channel:
        icon = PhosphorIcons.television();
        break;
      case SearchResultType.movie:
        icon = PhosphorIcons.filmStrip();
        break;
      case SearchResultType.series:
        icon = PhosphorIcons.monitor();
        break;
      case SearchResultType.epg:
        icon = PhosphorIcons.calendar();
        break;
    }

    return Container(
      color: tokens.AppTokens.surface3,
      child: Center(
        child: Icon(
          icon,
          size: 24,
          color: tokens.AppTokens.textTertiary,
        ),
      ),
    );
  }
}

/// Title with matched query highlighting
class _HighlightedTitle extends StatelessWidget {
  final String title;
  final String? matchedQuery;

  const _HighlightedTitle({
    required this.title,
    this.matchedQuery,
  });

  @override
  Widget build(BuildContext context) {
    if (matchedQuery == null || matchedQuery!.isEmpty) {
      return Text(
        title,
        style: tokens.TypographyTokens.bodyPrimary,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }

    // Find and highlight matched substring
    final queryLower = matchedQuery!.toLowerCase();
    final titleLower = title.toLowerCase();
    final startIndex = titleLower.indexOf(queryLower);

    if (startIndex == -1) {
      return Text(
        title,
        style: tokens.TypographyTokens.bodyPrimary,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }

    final endIndex = startIndex + matchedQuery!.length;
    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: title.substring(0, startIndex),
            style: tokens.TypographyTokens.bodyPrimary,
          ),
          TextSpan(
            text: title.substring(startIndex, endIndex),
            style: tokens.TypographyTokens.bodyAccent,
          ),
          TextSpan(
            text: title.substring(endIndex),
            style: tokens.TypographyTokens.bodyPrimary,
          ),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

/// LIVE badge for live content
class _LiveBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: tokens.SpacingTokens.s8,
        vertical: tokens.SpacingTokens.s4,
      ),
      decoration: BoxDecoration(
        color: tokens.AppTokens.liveRed,
        borderRadius: BorderRadius.circular(tokens.RadiusTokens.xs),
      ),
      child: Text(
        Strings.liveIndicator,
        style: tokens.TypographyTokens.caption.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Type indicator icon
class _TypeIndicator extends StatelessWidget {
  final SearchResultType type;

  const _TypeIndicator({required this.type});

  @override
  Widget build(BuildContext context) {
    IconData icon;
    switch (type) {
      case SearchResultType.channel:
        icon = PhosphorIcons.television();
        break;
      case SearchResultType.movie:
        icon = PhosphorIcons.filmStrip();
        break;
      case SearchResultType.series:
        icon = PhosphorIcons.monitor();
        break;
      case SearchResultType.epg:
        icon = PhosphorIcons.calendar();
        break;
    }

    return Icon(
      icon,
      size: 20,
      color: tokens.AppTokens.textTertiary,
    );
  }
}

/// Skeleton tile for loading state
class ResultTileSkeleton extends StatelessWidget {
  const ResultTileSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 88,
      padding: EdgeInsets.symmetric(
        horizontal: tokens.SpacingTokens.s16,
        vertical: tokens.SpacingTokens.s12,
      ),
      decoration: BoxDecoration(
        color: tokens.AppTokens.surface1,
        border: Border(
          bottom: BorderSide(
            color: tokens.AppTokens.border,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Skeleton(
            width: 120,
            height: 64,
            borderRadius: BorderRadius.circular(tokens.RadiusTokens.sm),
          ),
          SizedBox(width: tokens.SpacingTokens.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                SkeletonShapes.title(width: 150),
                SizedBox(height: tokens.SpacingTokens.s4),
                SkeletonShapes.textLine(width: 100),
                SizedBox(height: tokens.SpacingTokens.s4),
                SkeletonShapes.textLine(width: 80),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
