// lib/screens/onboarding/onboarding_flow.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lumio_tv/l10n/strings.dart';
import 'package:lumio_tv/screens/onboarding/onboarding_controller.dart';
import 'package:lumio_tv/screens/onboarding/welcome_screen.dart';
import 'package:lumio_tv/screens/onboarding/source_screen.dart';
import 'package:lumio_tv/screens/onboarding/source_detail_screen.dart';
import 'package:lumio_tv/screens/onboarding/preferences_screen.dart';
import 'package:lumio_tv/theme/tokens/colors.dart' as tokens;
import 'package:lumio_tv/theme/tokens/spacing.dart' as tokens;
import 'package:lumio_tv/theme/tokens/typography.dart' as tokens;
import 'package:lumio_tv/widgets/common/pressable.dart';

/// Main onboarding flow screen
///
/// Features:
/// - Swipeable page transitions with PageView
/// - Page indicators at bottom (3 dots, accent for current)
/// - Skip functionality (top right)
/// - State management across all screens
/// - SharedPreferences completion flag
class OnboardingFlow extends StatefulWidget {
  final VoidCallback onComplete;

  const OnboardingFlow({
    super.key,
    required this.onComplete,
  });

  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends State<OnboardingFlow> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _showSourceDetail = false;

  // Total number of main screens (excluding source detail which is overlay)
  final int _totalScreens = 3;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _handlePageChanged(int page) {
    setState(() {
      _currentPage = page;
    });
  }

  void _handleNext() {
    if (_currentPage < _totalScreens - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      HapticFeedback.lightImpact();
    } else {
      _handleFinish();
    }
  }

  void _handleSkip() {
    HapticFeedback.lightImpact();
    _finishOnboarding();
  }

  void _handleSourceSelected(OnboardingSourceType sourceType) {
    setState(() {
      _showSourceDetail = true;
    });
  }

  void _handleSourceBack() {
    setState(() {
      _showSourceDetail = false;
    });
    HapticFeedback.lightImpact();
  }

  void _handleSourceSuccess() {
    setState(() {
      _showSourceDetail = false;
    });
    _handleNext();
  }

  void _handleSkipSource() {
    setState(() {
      _showSourceDetail = false;
    });
    _handleNext();
  }

  void _handleFinish() async {
    HapticFeedback.heavyImpact();
    await OnboardingController.complete();
    widget.onComplete();
  }

  void _finishOnboarding() async {
    HapticFeedback.heavyImpact();
    await OnboardingController.complete();
    widget.onComplete();
  }

  @override
  Widget build(BuildContext context) {
    if (_showSourceDetail) {
      // Show source detail as overlay
      return SourceDetailScreen(
        sourceType: _selectedSourceType,
        onSuccess: _handleSourceSuccess,
        onBack: _handleSourceBack,
      );
    }

    return Scaffold(
      backgroundColor: tokens.AppTokens.background,
      body: Stack(
        children: [
          // Main PageView content
          PageView(
            controller: _pageController,
            onPageChanged: _handlePageChanged,
            children: [
              // Screen 1: Welcome
              WelcomeScreen(onContinue: _handleNext),

              // Screen 2: Add Source
              SourceScreen(
                onSourceSelected: _handleSourceSelected,
                onSkip: _handleSkipSource,
              ),

              // Screen 3: Preferences (can skip source)
              PreferencesScreen(onFinish: _handleFinish),
            ],
          ),

          // Skip button (top right)
          Positioned(
            top: tokens.SpacingTokens.s16,
            right: tokens.SpacingTokens.s16,
            child: Pressable(
              onTap: _handleSkip,
              child: Text(
                Strings.onboardingSkip,
                style: tokens.TypographyTokens.labelSecondary,
              ),
            ),
          ),

          // Page indicators (bottom)
          Positioned(
            bottom: tokens.SpacingTokens.s32,
            left: 0,
            right: 0,
            child: _PageIndicators(
              currentPage: _currentPage,
              totalScreens: _totalScreens,
              onTap: (index) {
                _pageController.animateToPage(
                  index,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                );
                HapticFeedback.selectionClick();
              },
            ),
          ),
        ],
      ),
    );
  }

  // Track selected source type for detail screen
  final OnboardingSourceType _selectedSourceType = OnboardingSourceType.m3u;
}

/// Page indicators widget
class _PageIndicators extends StatelessWidget {
  final int currentPage;
  final int totalScreens;
  final Function(int) onTap;

  const _PageIndicators({
    required this.currentPage,
    required this.totalScreens,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(totalScreens, (index) {
        final isCurrent = index == currentPage;
        return Pressable(
          onTap: () => onTap(index),
          child: Container(
            width: isCurrent ? 24 : 8,
            height: 8,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: isCurrent
                  ? tokens.AppTokens.accent
                  : tokens.AppTokens.surface3,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        );
      }),
    );
  }
}
