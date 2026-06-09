// lib/theme/tokens/elevation.dart
import 'package:flutter/material.dart';

class ElevationTokens {
  static const double none = 0.0;
  static const double sm = 2.0;
  static const double md = 4.0;
  static const double lg = 8.0;
  static const double xl = 16.0;

  // Shadow colors for dark theme
  static Color shadowColor(BuildContext context) {
    return Colors.black.withValues(alpha: 0.4);
  }

  // Box shadows
  static List<BoxShadow> shadowSm(BuildContext context) {
    return [
      BoxShadow(
        color: shadowColor(context),
        offset: const Offset(0, 1),
        blurRadius: 2,
      ),
    ];
  }

  static List<BoxShadow> shadowMd(BuildContext context) {
    return [
      BoxShadow(
        color: shadowColor(context),
        offset: const Offset(0, 2),
        blurRadius: 4,
      ),
    ];
  }

  static List<BoxShadow> shadowLg(BuildContext context) {
    return [
      BoxShadow(
        color: shadowColor(context),
        offset: const Offset(0, 4),
        blurRadius: 8,
      ),
    ];
  }

  static List<BoxShadow> shadowXl(BuildContext context) {
    return [
      BoxShadow(
        color: shadowColor(context),
        offset: const Offset(0, 8),
        blurRadius: 16,
      ),
    ];
  }
}
