// lib/widgets/common/skeleton_loaders.dart
import 'package:flutter/material.dart';
import 'package:lumio_tv/theme/tokens/colors.dart' as tokens;
import 'package:lumio_tv/theme/tokens/spacing.dart' as tokens;
import 'package:lumio_tv/theme/tokens/radius.dart' as tokens;
import 'package:lumio_tv/widgets/common/skeleton.dart';

/// Additional skeleton loaders for specific UI patterns
/// 
/// These are specialized skeleton patterns for the Lumio app's
/// specific UI components like movie cards, channel rows, etc.
class SkeletonLoaders {
  /// Movie card skeleton (for home screen)
  static Widget movieCard() {
    return SizedBox(
      width: 160,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Poster thumbnail
          SkeletonShapes.thumbnail(width: 160),
          SizedBox(height: tokens.SpacingTokens.s8),
          // Title
          SkeletonShapes.title(height: 16),
          SizedBox(height: tokens.SpacingTokens.s4),
          // Subtitle
          SkeletonShapes.textLine(height: 12),
        ],
      ),
    );
  }

  /// Channel row skeleton (for live TV screen)
  static Widget channelRow() {
    return Container(
      height: 64,
      padding: EdgeInsets.symmetric(horizontal: tokens.SpacingTokens.s16),
      child: Row(
        children: [
          // Channel logo
          Skeleton(
            width: 48,
            height: 48,
            borderRadius: BorderRadius.circular(tokens.RadiusTokens.sm),
          ),
          SizedBox(width: tokens.SpacingTokens.s12),
          // Channel info
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonShapes.title(height: 16),
                SizedBox(height: tokens.SpacingTokens.s4),
                SkeletonShapes.textLine(height: 12),
              ],
            ),
          ),
          // Favorite icon placeholder
          Skeleton(
            width: 20,
            height: 20,
            borderRadius: BorderRadius.circular(tokens.RadiusTokens.xs),
          ),
        ],
      ),
    );
  }

  /// EPG program block skeleton
  static Widget epgProgramBlock() {
    return Container(
      margin: EdgeInsets.symmetric(
        vertical: tokens.SpacingTokens.s4,
        horizontal: tokens.SpacingTokens.s4,
      ),
      padding: EdgeInsets.symmetric(
        horizontal: tokens.SpacingTokens.s8,
        vertical: tokens.SpacingTokens.s8,
      ),
      decoration: BoxDecoration(
        color: tokens.AppTokens.surface2,
        borderRadius: BorderRadius.circular(tokens.RadiusTokens.sm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          SkeletonShapes.title(height: 14),
          SizedBox(height: tokens.SpacingTokens.s4),
          SkeletonShapes.textLine(height: 12, width: 100),
        ],
      ),
    );
  }

  /// Settings row skeleton
  static Widget settingsRow() {
    return Container(
      height: 56,
      padding: EdgeInsets.symmetric(horizontal: tokens.SpacingTokens.s16),
      child: Row(
        children: [
          // Icon placeholder
          Skeleton(
            width: 24,
            height: 24,
            borderRadius: BorderRadius.circular(tokens.RadiusTokens.xs),
          ),
          SizedBox(width: tokens.SpacingTokens.s16),
          // Text
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonShapes.title(height: 16),
                SizedBox(height: tokens.SpacingTokens.s4),
                SkeletonShapes.textLine(height: 12),
              ],
            ),
          ),
          // Trailing placeholder
          Skeleton(
            width: 20,
            height: 20,
            borderRadius: BorderRadius.circular(tokens.RadiusTokens.xs),
          ),
        ],
      ),
    );
  }

  /// Search result skeleton
  static Widget searchResult() {
    return Container(
      height: 80,
      padding: EdgeInsets.symmetric(horizontal: tokens.SpacingTokens.s16),
      child: Row(
        children: [
          // Thumbnail
          SkeletonShapes.thumbnail(width: 100),
          SizedBox(width: tokens.SpacingTokens.s12),
          // Content
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonShapes.title(height: 16),
                SizedBox(height: tokens.SpacingTokens.s8),
                SkeletonShapes.textLine(height: 12),
                SizedBox(height: tokens.SpacingTokens.s4),
                SkeletonShapes.textLine(height: 12, width: 150),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Full page loading skeleton
  static Widget fullPage() {
    return Padding(
      padding: EdgeInsets.all(tokens.SpacingTokens.s16),
      child: Column(
        children: [
          // Header
          SkeletonShapes.title(height: 32),
          SizedBox(height: tokens.SpacingTokens.s24),
          // Cards
          ...List.generate(3, (index) => Column(
            children: [
              SkeletonShapes.card(height: 120),
              SizedBox(height: tokens.SpacingTokens.s16),
            ],
          )),
        ],
      ),
    );
  }

  /// List of movie cards skeleton
  static Widget movieCardList({int count = 6}) {
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      itemCount: count,
      itemBuilder: (context, index) {
        return Padding(
          padding: EdgeInsets.only(right: tokens.SpacingTokens.s12),
          child: movieCard(),
        );
      },
    );
  }

  /// Vertical list skeleton
  static Widget verticalList({int count = 5}) {
    return ListView.builder(
      itemCount: count,
      itemBuilder: (context, index) {
        return Column(
          children: [
            SkeletonShapes.card(height: 80),
            SizedBox(height: tokens.SpacingTokens.s16),
          ],
        );
      },
    );
  }
}