// lib/widgets/empty_states/empty_state.dart
import 'package:flutter/material.dart';
import 'package:lumio_tv/l10n/strings.dart';
import 'package:lumio_tv/theme/tokens/colors.dart' as tokens;
import 'package:lumio_tv/theme/tokens/radius.dart' as tokens;
import 'package:lumio_tv/theme/tokens/spacing.dart' as tokens;
import 'package:lumio_tv/theme/tokens/typography.dart' as tokens;
import 'package:lumio_tv/widgets/common/pressable.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// Type of illustration to display in empty state
enum EmptyStateIllustration {
  search,
  favorites,
  history,
  downloads,
  error,
  offline,
}

/// A reusable empty state widget with illustration, title, subtitle, and optional action.
///
/// Features:
/// - Supports SVG illustrations (via flutter_svg) or Phosphor icons as fallback
/// - Proper typography hierarchy (title size for heading, body size for subtitle)
/// - Optional action button with pressable interaction
/// - Design token compliant
/// - Centered layout with proper spacing
class EmptyState extends StatelessWidget {
  /// The illustration to display (icon type for now, SVG path for future)
  final EmptyStateIllustration illustration;

  /// Optional custom SVG asset path (overrides icon if provided)
  final String? customIllustration;

  /// The main heading text (title size)
  final String title;

  /// The supporting subtitle text (body size, TextSecondary)
  final String subtitle;

  /// Optional label for the action button
  final String? actionLabel;

  /// Optional callback when action button is pressed
  final VoidCallback? onAction;

  const EmptyState({
    super.key,
    required this.illustration,
    this.customIllustration,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  /// Create an empty state for search results
  factory EmptyState.search({
    String? customIllustration,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return EmptyState(
      illustration: EmptyStateIllustration.search,
      customIllustration: customIllustration,
      title: Strings.searchEmptyTitle,
      subtitle: Strings.searchEmptySubtitle,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }

  /// Create an empty state for favorites
  factory EmptyState.favorites({
    String? customIllustration,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return EmptyState(
      illustration: EmptyStateIllustration.favorites,
      customIllustration: customIllustration,
      title: Strings.favoritesEmptyTitle,
      subtitle: Strings.favoritesEmptySubtitle,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }

  /// Create an empty state for watch history
  factory EmptyState.history({
    String? customIllustration,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return EmptyState(
      illustration: EmptyStateIllustration.history,
      customIllustration: customIllustration,
      title: Strings.historyEmptyTitle,
      subtitle: Strings.historyEmptySubtitle,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }

  /// Create an empty state for downloads
  factory EmptyState.downloads({
    String? customIllustration,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return EmptyState(
      illustration: EmptyStateIllustration.downloads,
      customIllustration: customIllustration,
      title: Strings.downloadsEmptyTitle,
      subtitle: Strings.downloadsEmptySubtitle,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }

  /// Create an empty state for offline mode
  factory EmptyState.offline({
    String? customIllustration,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return EmptyState(
      illustration: EmptyStateIllustration.offline,
      customIllustration: customIllustration,
      title: Strings.offlineTitle,
      subtitle: Strings.offlineSubtitle,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }

  /// Create an empty state for errors
  factory EmptyState.error({
    String? customIllustration,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return EmptyState(
      illustration: EmptyStateIllustration.error,
      customIllustration: customIllustration,
      title: Strings.errorGeneric,
      subtitle: Strings.offlineSubtitle, // Reuse offline subtitle as generic
      actionLabel: actionLabel ?? Strings.tryAgain,
      onAction: onAction,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: tokens.SpacingTokens.s32,
          vertical: tokens.SpacingTokens.s56,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Illustration
            _buildIllustration(),

            SizedBox(height: tokens.SpacingTokens.s24),

            // Title
            Text(
              title,
              style: tokens.TypographyTokens.titlePrimary,
              textAlign: TextAlign.center,
            ),

            SizedBox(height: tokens.SpacingTokens.s12),

            // Subtitle
            Text(
              subtitle,
              style: tokens.TypographyTokens.bodySecondary,
              textAlign: TextAlign.center,
            ),

            // Action button (if provided)
            if (actionLabel != null && onAction != null) ...[
              SizedBox(height: tokens.SpacingTokens.s24),
              _ActionButton(
                label: actionLabel!,
                onPressed: onAction!,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildIllustration() {
    // If custom SVG path is provided, use it (for future implementation)
    if (customIllustration != null) {
      // ISSUE: Implement SVG rendering once flutter_svg is integrated
      // See: https://github.com/your-repo/issues/XXX
      // For now, fallback to icon
      return _buildIcon();
    }

    // Otherwise, use Phosphor icon with 30% opacity
    return _buildIcon();
  }

  Widget _buildIcon() {
    IconData iconData;

    switch (illustration) {
      case EmptyStateIllustration.search:
        iconData = PhosphorIcons.magnifyingGlass();
        break;
      case EmptyStateIllustration.favorites:
        iconData = PhosphorIcons.heart();
        break;
      case EmptyStateIllustration.history:
        iconData = PhosphorIcons.clock();
        break;
      case EmptyStateIllustration.downloads:
        iconData = PhosphorIcons.cloudArrowDown();
        break;
      case EmptyStateIllustration.error:
        iconData = PhosphorIcons.warningOctagon();
        break;
      case EmptyStateIllustration.offline:
        iconData = PhosphorIcons.wifiSlash();
        break;
    }

    return Opacity(
      opacity: 0.3,
      child: Icon(
        iconData,
        size: 96,
        color: tokens.AppTokens.textPrimary,
      ),
    );
  }
}

/// Action button for empty states
class _ActionButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const _ActionButton({
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onPressed,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: tokens.SpacingTokens.s24,
          vertical: tokens.SpacingTokens.s12,
        ),
        decoration: BoxDecoration(
          color: tokens.AppTokens.accent,
          borderRadius: BorderRadius.circular(tokens.RadiusTokens.md),
        ),
        child: Text(
          label,
          style: tokens.TypographyTokens.labelPrimary,
        ),
      ),
    );
  }
}
