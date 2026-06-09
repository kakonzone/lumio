// lib/utils/haptic_helpers.dart
import 'package:flutter/services.dart';

/// Haptic feedback helpers for different interaction types.
/// 
/// Usage:
/// ```dart
/// Haptics.selectionChange();
/// Haptics.buttonPress();
/// Haptics.toggleOn();
/// ```
class Haptics {
  Haptics._();

  /// Selection change (tab switch, dropdown selection, etc.)
  static void selectionChange() {
    HapticFeedback.selectionClick();
  }

  /// Button press (general button tap)
  static void buttonPress() {
    HapticFeedback.lightImpact();
  }

  /// Toggle on (switch enabled, checkbox checked)
  static void toggleOn() {
    HapticFeedback.mediumImpact();
  }

  /// Toggle off (switch disabled, checkbox unchecked)
  static void toggleOff() {
    HapticFeedback.lightImpact();
  }

  /// Error state (validation error, failure)
  static void error() {
    HapticFeedback.heavyImpact();
  }

  /// Long press (context menu, drag start)
  static void longPress() {
    HapticFeedback.mediumImpact();
  }

  /// Success state (operation completed)
  static void success() {
    HapticFeedback.mediumImpact();
  }

  /// Warning state (caution, attention needed)
  static void warning() {
    HapticFeedback.lightImpact();
  }

  /// Notification (alert, reminder)
  static void notification() {
    HapticFeedback.mediumImpact();
  }

  /// Delete action (destructive operation)
  static void delete() {
    HapticFeedback.heavyImpact();
  }

  /// Check if haptic feedback is supported
  static Future<bool> get isSupported async {
    // Most modern devices support haptic feedback
    // This can be enhanced with platform-specific checks if needed
    return true;
  }

  /// Conditional haptic feedback (only if supported and enabled)
  static Future<void> conditional(VoidCallback hapticCallback) async {
    if (await isSupported) {
      hapticCallback();
    }
  }
}
