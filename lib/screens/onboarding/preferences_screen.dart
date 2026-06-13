// lib/screens/onboarding/preferences_screen.dart
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

/// Preferences screen - Screen 4 of onboarding
///
/// Features:
/// - Quick preference selection
/// - Preferred language (chips)
/// - Content interests (multi-select chips)
/// - Adult content (toggle, default off)
/// - "Finish setup" button
class PreferencesScreen extends StatefulWidget {
  final VoidCallback onFinish;

  const PreferencesScreen({
    super.key,
    required this.onFinish,
  });

  @override
  State<PreferencesScreen> createState() => _PreferencesScreenState();
}

class _PreferencesScreenState extends State<PreferencesScreen> {
  String _selectedLanguage = Strings.languageEnglish;
  final Set<String> _selectedInterests = {};
  bool _adultContentEnabled = false;

  final List<String> _languages = [
    Strings.languageEnglish,
    Strings.languageSpanish,
    Strings.languageFrench,
    Strings.languageGerman,
    Strings.languagePortuguese,
    Strings.languageArabic,
    Strings.languageHindi,
    Strings.languageBengali,
  ];

  final List<String> _interests = [
    Strings.interestSports,
    Strings.interestMovies,
    Strings.interestNews,
    Strings.interestKids,
    Strings.interestMusic,
    Strings.interestDocumentaries,
    Strings.interestEntertainment,
  ];

  Future<void> _handleFinish() async {
    HapticFeedback.mediumImpact();

    // Save preferences
    await OnboardingController.savePreferences(
      language: _selectedLanguage,
      interests: _selectedInterests.toList(),
      adultContentEnabled: _adultContentEnabled,
    );

    // Mark onboarding as complete
    await OnboardingController.complete();

    widget.onFinish();
  }

  void _toggleInterest(String interest) {
    setState(() {
      if (_selectedInterests.contains(interest)) {
        _selectedInterests.remove(interest);
      } else {
        _selectedInterests.add(interest);
      }
    });
    HapticFeedback.lightImpact();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: tokens.AppTokens.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          Strings.onboardingPreferencesTitle,
          style: tokens.TypographyTokens.titlePrimary,
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: tokens.SpacingTokens.s24,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: tokens.SpacingTokens.s16),

              // Language selection
              Text(
                Strings.onboardingLanguageLabel,
                style: tokens.TypographyTokens.labelPrimary,
              ),
              SizedBox(height: tokens.SpacingTokens.s12),
              Wrap(
                spacing: tokens.SpacingTokens.s8,
                runSpacing: tokens.SpacingTokens.s8,
                children: _languages.map((language) {
                  final isSelected = _selectedLanguage == language;
                  return Pressable(
                    onTap: () {
                      setState(() {
                        _selectedLanguage = language;
                      });
                      HapticFeedback.selectionClick();
                    },
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: tokens.SpacingTokens.s16,
                        vertical: tokens.SpacingTokens.s8,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? tokens.AppTokens.accentMuted
                            : tokens.AppTokens.surface2,
                        borderRadius: BorderRadius.circular(
                          tokens.RadiusTokens.md,
                        ),
                        border: Border.all(
                          color: isSelected
                              ? tokens.AppTokens.accent
                              : tokens.AppTokens.border,
                          width: 1,
                        ),
                      ),
                      child: Text(
                        language,
                        style: isSelected
                            ? tokens.TypographyTokens.labelAccent
                            : tokens.TypographyTokens.labelPrimary,
                      ),
                    ),
                  );
                }).toList(),
              ),

              SizedBox(height: tokens.SpacingTokens.s32),

              // Content interests
              Text(
                Strings.onboardingInterestsLabel,
                style: tokens.TypographyTokens.labelPrimary,
              ),
              SizedBox(height: tokens.SpacingTokens.s12),
              Wrap(
                spacing: tokens.SpacingTokens.s8,
                runSpacing: tokens.SpacingTokens.s8,
                children: _interests.map((interest) {
                  final isSelected = _selectedInterests.contains(interest);
                  return Pressable(
                    onTap: () => _toggleInterest(interest),
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: tokens.SpacingTokens.s16,
                        vertical: tokens.SpacingTokens.s8,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? tokens.AppTokens.accentMuted
                            : tokens.AppTokens.surface2,
                        borderRadius: BorderRadius.circular(
                          tokens.RadiusTokens.md,
                        ),
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
                          if (isSelected) ...[
                            Icon(
                              PhosphorIcons.check(),
                              size: 14,
                              color: tokens.AppTokens.accent,
                            ),
                            SizedBox(width: tokens.SpacingTokens.s4),
                          ],
                          Text(
                            interest,
                            style: isSelected
                                ? tokens.TypographyTokens.labelAccent
                                : tokens.TypographyTokens.labelPrimary,
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),

              SizedBox(height: tokens.SpacingTokens.s32),

              // Adult content toggle
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          Strings.onboardingAdultContentLabel,
                          style: tokens.TypographyTokens.bodyPrimary,
                        ),
                        SizedBox(height: tokens.SpacingTokens.s4),
                        Text(
                          Strings.onboardingAdultContentDesc,
                          style: tokens.TypographyTokens.captionSecondary,
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _adultContentEnabled,
                    onChanged: (value) {
                      setState(() {
                        _adultContentEnabled = value;
                      });
                      HapticFeedback.lightImpact();
                    },
                  ),
                ],
              ),

              SizedBox(height: tokens.SpacingTokens.s40),

              // Finish button
              Pressable(
                onTap: _handleFinish,
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
                    Strings.onboardingFinish,
                    style: tokens.TypographyTokens.labelPrimary,
                    textAlign: TextAlign.center,
                  ),
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
