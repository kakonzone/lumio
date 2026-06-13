// lib/screens/onboarding/source_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lumio_tv/l10n/strings.dart';
import 'package:lumio_tv/screens/onboarding/onboarding_controller.dart';
import 'package:lumio_tv/theme/tokens/colors.dart' as tokens;
import 'package:lumio_tv/theme/tokens/radius.dart' as tokens;
import 'package:lumio_tv/theme/tokens/spacing.dart' as tokens;
import 'package:lumio_tv/theme/tokens/typography.dart' as tokens;
import 'package:lumio_tv/widgets/common/pressable.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// Add source screen - Screen 2 of onboarding
///
/// Features:
/// - Heading: "Add your first playlist"
/// - Three large option cards (M3U URL, Xtream Codes, Upload file)
/// - Each card: Surface2, radius lg, 80px height, icon left, title + description, chevron right
/// - "I'll do this later" text button below
class SourceScreen extends StatelessWidget {
  final Function(OnboardingSourceType) onSourceSelected;
  final VoidCallback onSkip;

  const SourceScreen({
    super.key,
    required this.onSourceSelected,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: tokens.AppTokens.background,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: tokens.SpacingTokens.s24,
          ),
          child: Column(
            children: [
              // Heading
              Padding(
                padding: EdgeInsets.only(
                  top: tokens.SpacingTokens.s40,
                  bottom: tokens.SpacingTokens.s32,
                ),
                child: Text(
                  Strings.onboardingAddSourceTitle,
                  style: tokens.TypographyTokens.headingPrimary,
                  textAlign: TextAlign.center,
                ),
              ),

              // Source options
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _SourceOptionCard(
                      icon: PhosphorIcons.link(),
                      title: Strings.onboardingSourceM3U,
                      description: Strings.onboardingSourceM3UDesc,
                      onTap: () {
                        HapticFeedback.lightImpact();
                        onSourceSelected(OnboardingSourceType.m3u);
                      },
                    ),
                    SizedBox(height: tokens.SpacingTokens.s16),
                    _SourceOptionCard(
                      icon: PhosphorIcons.database(),
                      title: Strings.onboardingSourceXtream,
                      description: Strings.onboardingSourceXtreamDesc,
                      onTap: () {
                        HapticFeedback.lightImpact();
                        onSourceSelected(OnboardingSourceType.xtream);
                      },
                    ),
                    SizedBox(height: tokens.SpacingTokens.s16),
                    _SourceOptionCard(
                      icon: PhosphorIcons.uploadSimple(),
                      title: Strings.onboardingSourceUpload,
                      description: Strings.onboardingSourceUploadDesc,
                      onTap: () {
                        HapticFeedback.lightImpact();
                        onSourceSelected(OnboardingSourceType.upload);
                      },
                    ),
                  ],
                ),
              ),

              // Skip button
              Pressable(
                onTap: () {
                  HapticFeedback.lightImpact();
                  onSkip();
                },
                child: Text(
                  Strings.onboardingAddSourceLater,
                  style: tokens.TypographyTokens.labelSecondary,
                ),
              ),

              SizedBox(height: tokens.SpacingTokens.s24),
            ],
          ),
        ),
      ),
    );
  }
}

/// Source option card widget
class _SourceOptionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  const _SourceOptionCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Container(
        height: 80,
        decoration: BoxDecoration(
          color: tokens.AppTokens.surface2,
          borderRadius: BorderRadius.circular(tokens.RadiusTokens.lg),
          border: Border.all(
            color: tokens.AppTokens.border,
            width: 1,
          ),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: tokens.SpacingTokens.s16,
          ),
          child: Row(
            children: [
              // Icon
              Icon(
                icon,
                size: 32,
                color: tokens.AppTokens.accent,
              ),
              SizedBox(width: tokens.SpacingTokens.s16),

              // Title and description
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: tokens.TypographyTokens.bodyPrimary,
                    ),
                    SizedBox(height: tokens.SpacingTokens.s4),
                    Text(
                      description,
                      style: tokens.TypographyTokens.captionSecondary,
                    ),
                  ],
                ),
              ),

              // Chevron
              Icon(
                PhosphorIcons.caretRight(),
                size: 20,
                color: tokens.AppTokens.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
