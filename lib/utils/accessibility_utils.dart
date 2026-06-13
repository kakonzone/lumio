// lib/utils/accessibility_utils.dart
import 'package:flutter/material.dart';

/// Accessibility utility functions and extensions
///
/// This file provides helper methods to ensure the app meets
/// WCAG AA accessibility standards.
class AccessibilityUtils {
  /// Create a semantic label for a button with context
  /// Example: "Play video, 2 minutes"
  static String createButtonLabel(String action, String? context) {
    return context != null ? '$action, $context' : action;
  }

  /// Create a semantic label for an image
  static String createImageLabel(String description) {
    return 'Image, $description';
  }

  /// Check if touch target meets minimum size (48x48)
  static bool meetsMinimumTouchTarget(Size size) {
    return size.width >= 48 && size.height >= 48;
  }

  /// Get a semantic merge description for a custom widget
  static String mergeSemanticLabels(List<String> labels) {
    return labels.join(', ');
  }

  /// Create a value label for toggles/switches
  static String createToggleLabel(String label, bool isOn) {
    return '$label, ${isOn ? "On" : "Off"}';
  }
}

/// Extension to add accessibility properties to widgets
extension AccessibilityWidgetExtension on Widget {
  /// Add semantic label to widget
  Widget withAccessibilityLabel(String label) {
    return Semantics(
      label: label,
      child: this,
    );
  }

  /// Add semantic hint to widget
  Widget withAccessibilityHint(String hint) {
    return Semantics(
      hint: hint,
      child: this,
    );
  }

  /// Mark widget as button for screen readers
  Widget asButton(String label) {
    return Semantics(
      button: true,
      label: label,
      child: this,
    );
  }

  /// Mark widget as link for screen readers
  Widget asLink(String label) {
    return Semantics(
      link: true,
      label: label,
      child: this,
    );
  }

  /// Mark widget as switch for screen readers
  Widget asToggleSwitch(String label, bool isOn) {
    return Semantics(
      toggled: isOn,
      label: label,
      value: isOn ? 'On' : 'Off',
      child: this,
    );
  }

  /// Mark widget as text field for screen readers
  Widget asTextField(String label) {
    return Semantics(
      textField: true,
      label: label,
      child: this,
    );
  }

  /// Mark widget as header for screen readers
  Widget asHeader(String label, {int level = 1}) {
    return Semantics(
      header: true,
      label: label,
      textDirection: TextDirection.ltr,
      child: this,
    );
  }

  /// Mark widget as live region for dynamic content
  Widget asLiveRegion({bool live = true}) {
    return Semantics(
      liveRegion: live,
      child: this,
    );
  }

  /// Exclude widget from accessibility tree
  Widget excludeFromAccessibility() {
    return Semantics(
      excludeSemantics: true,
      child: this,
    );
  }
}

/// Extension for text scaling support
extension TextScalingExtension on Text {
  /// Enable system font scaling
  Text enableTextScaling() {
    return Text(
      data!,
      style: style?.copyWith(
        inherit: true,
      ),
    );
  }
}

/// Minimum touch target wrapper for small widgets
class MinimumTouchTarget extends StatelessWidget {
  final Widget child;
  final double minSize;
  final VoidCallback? onTap;

  const MinimumTouchTarget({
    super.key,
    required this.child,
    this.minSize = 48.0,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        constraints: BoxConstraints(
          minWidth: minSize,
          minHeight: minSize,
        ),
        alignment: Alignment.center,
        child: child,
      ),
    );
  }
}
