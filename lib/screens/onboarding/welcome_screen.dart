// lib/screens/onboarding/welcome_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lumio_tv/l10n/strings.dart';
import 'package:lumio_tv/theme/tokens/colors.dart' as tokens;
import 'package:lumio_tv/theme/tokens/motion.dart' as tokens;
import 'package:lumio_tv/theme/tokens/radius.dart' as tokens;
import 'package:lumio_tv/theme/tokens/spacing.dart' as tokens;
import 'package:lumio_tv/theme/tokens/typography.dart' as tokens;
import 'package:lumio_tv/widgets/common/pressable.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// Welcome screen - Screen 1 of onboarding
/// 
/// Features:
/// - Display size heading: "Welcome to Lumio"
/// - Body: "Your IPTV, finally with taste."
/// - Animated illustration
/// - Continue button (full width, accent, bottom)
class WelcomeScreen extends StatelessWidget {
  final VoidCallback onContinue;

  const WelcomeScreen({
    super.key,
    required this.onContinue,
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
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Animated illustration
                    _AnimatedIllustration(),

                    SizedBox(height: tokens.SpacingTokens.s40),

                    // Heading
                    Text(
                      Strings.onboardingWelcomeTitle,
                      style: tokens.TypographyTokens.displayPrimary,
                      textAlign: TextAlign.center,
                    ),

                    SizedBox(height: tokens.SpacingTokens.s16),

                    // Body text
                    Text(
                      Strings.onboardingWelcomeBody,
                      style: tokens.TypographyTokens.bodySecondary,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),

              // Continue button
              Pressable(
                onTap: () {
                  HapticFeedback.mediumImpact();
                  onContinue();
                },
                child: Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(
                    vertical: tokens.SpacingTokens.s16,
                  ),
                  decoration: BoxDecoration(
                    color: tokens.AppTokens.accent,
                    borderRadius: BorderRadius.circular(tokens.RadiusTokens.md),
                  ),
                  child: Text(
                    Strings.onboardingContinue,
                    style: tokens.TypographyTokens.labelPrimary,
                    textAlign: TextAlign.center,
                  ),
                ),
              ),

              SizedBox(height: tokens.SpacingTokens.s16),
            ],
          ),
        ),
      ),
    );
  }
}

/// Animated illustration for welcome screen
class _AnimatedIllustration extends StatefulWidget {
  @override
  State<_AnimatedIllustration> createState() => _AnimatedIllustrationState();
}

class _AnimatedIllustrationState extends State<_AnimatedIllustration>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: tokens.MotionTokens.curveSpring,
    ));

    _opacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: tokens.MotionTokens.curveDefault,
    ));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = tokens.MotionTokens.reduceMotion(context);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.scale(
          scale: reduceMotion ? 1.0 : _scaleAnimation.value,
          child: Opacity(
            opacity: reduceMotion ? 1.0 : _opacityAnimation.value,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                color: tokens.AppTokens.surface2,
                borderRadius: BorderRadius.circular(tokens.RadiusTokens.lg),
                border: Border.all(
                  color: tokens.AppTokens.accent,
                  width: 2,
                ),
              ),
              child: Icon(
                PhosphorIcons.televisionSimple(),
                size: 100,
                color: tokens.AppTokens.accent,
              ),
            ),
          ),
        );
      },
    );
  }
}