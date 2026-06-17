// lib/widgets/player/buffering_skeleton.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:lumio_tv/l10n/strings.dart' as strings;
import 'package:lumio_tv/theme/tokens.dart' as tokens;

/// Buffering skeleton overlay for video player.
///
/// Features:
/// - Skeleton shimmer over video area (not centered spinner)
/// - Subtitle text: "Catching up..."
/// - Uses Surface2 base, Surface3 highlight
/// - 1200ms shimmer cycle, easeInOut curve
class BufferingSkeleton extends StatelessWidget {
  final double? width;
  final double? height;

  const BufferingSkeleton({
    super.key,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width ?? double.infinity,
      height: height ?? double.infinity,
      child: Stack(
        children: [
          // Skeleton shimmer layer
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    tokens.AppTokens.surface2,
                    tokens.AppTokens.surface3,
                    tokens.AppTokens.surface2,
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            )
                .animate(
                  onPlay: (controller) => controller.repeat(),
                )
                .shimmer(
                  duration: tokens.MotionTokens.shimmerCycle,
                  curve: tokens.MotionTokens.shimmerCurve,
                  color: tokens.AppTokens.surface3,
                  angle: 45,
                ),
          ),

          // Subtitle text at center
          Center(
            child: Text(
              strings.Strings.playerBuffering,
              style: tokens.TypographyTokens.bodySecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Error state widget for video player.
///
/// Features:
/// - Centered: icon + "Stream dropped" heading + "Tap to reconnect" body + retry button
/// - NOT a red error toast
/// - Surface2 background card
class PlayerErrorState extends StatelessWidget {
  final VoidCallback onRetry;
  final String? errorMessage;

  const PlayerErrorState({
    super.key,
    required this.onRetry,
    this.errorMessage,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: tokens.AppTokens.background,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(tokens.SpacingTokens.s32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icon
              Container(
                padding: const EdgeInsets.all(tokens.SpacingTokens.s16),
                decoration: BoxDecoration(
                  color: tokens.AppTokens.surface2,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  PhosphorIcons.warning(),
                  size: 48,
                  color: tokens.AppTokens.textTertiary,
                ),
              ),

              const SizedBox(height: tokens.SpacingTokens.s24),

              // Heading
              Text(
                errorMessage ?? strings.Strings.streamDroppedTitle,
                style: tokens.TypographyTokens.titlePrimary,
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: tokens.SpacingTokens.s8),

              // Body
              Text(
                strings.Strings.streamDroppedSubtitle,
                style: tokens.TypographyTokens.bodySecondary,
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: tokens.SpacingTokens.s32),

              // Retry button
              ElevatedButton(
                onPressed: () {
                  HapticFeedback.mediumImpact();
                  onRetry();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: tokens.AppTokens.accent,
                  foregroundColor: tokens.AppTokens.textPrimary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: tokens.SpacingTokens.s32,
                    vertical: tokens.SpacingTokens.s16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: tokens.RadiusTokens.circularMd,
                  ),
                ),
                child: Text(strings.Strings.tryAgain),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
