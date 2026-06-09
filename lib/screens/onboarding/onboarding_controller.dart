// lib/screens/onboarding/onboarding_controller.dart
import 'package:shared_preferences/shared_preferences.dart';

/// Source type for onboarding
enum OnboardingSourceType {
  m3u,
  xtream,
  upload,
}

/// Controller for managing onboarding state and persistence
class OnboardingController {
  static const String _onboardingCompletedKey = 'onboarding_completed';
  static const String _preferredLanguageKey = 'preferred_language';
  static const String _contentInterestsKey = 'content_interests';
  static const String _adultContentEnabledKey = 'adult_content_enabled';

  /// Check if onboarding has been completed
  static Future<bool> isCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_onboardingCompletedKey) ?? false;
  }

  /// Mark onboarding as completed
  static Future<void> complete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboardingCompletedKey, true);
  }

  /// Save user preferences from onboarding
  static Future<void> savePreferences({
    String? language,
    List<String>? interests,
    bool? adultContentEnabled,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    
    if (language != null) {
      await prefs.setString(_preferredLanguageKey, language);
    }
    
    if (interests != null) {
      await prefs.setStringList(_contentInterestsKey, interests);
    }
    
    if (adultContentEnabled != null) {
      await prefs.setBool(_adultContentEnabledKey, adultContentEnabled);
    }
  }

  /// Get saved preferences
  static Future<Map<String, dynamic>> getPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'language': prefs.getString(_preferredLanguageKey),
      'interests': prefs.getStringList(_contentInterestsKey) ?? [],
      'adultContentEnabled': prefs.getBool(_adultContentEnabledKey) ?? false,
    };
  }

  /// Reset onboarding (for testing)
  static Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_onboardingCompletedKey);
  }
}