// lib/theme/app_theme.dart
import 'package:flutter/material.dart';
import 'tokens/colors.dart' as tokens;
import 'tokens/radius.dart' as tokens;
import 'tokens/elevation.dart' as tokens;

class AppTheme {
  static ThemeData get dark {
    final base = ThemeData.dark();
    return base.copyWith(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: tokens.AppTokens.background,
      primaryColor: tokens.AppTokens.accent,
      textTheme: base.textTheme.apply(
        fontFamily: 'Barlow',
        bodyColor: tokens.AppTokens.textPrimary,
        displayColor: tokens.AppTokens.textPrimary,
      ),
      colorScheme: const ColorScheme.dark(
        primary: tokens.AppTokens.accent,
        surface: tokens.AppTokens.surface1,
        onSurface: tokens.AppTokens.textPrimary,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: tokens.AppTokens.background,
        elevation: tokens.ElevationTokens.none,
        iconTheme: const IconThemeData(color: tokens.AppTokens.textPrimary),
        titleTextStyle: GF.head(
          fontSize: 22,
          fontWeight: FontWeight.w800,
          color: tokens.AppTokens.textPrimary,
          letterSpacing: 0.5,
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: tokens.AppTokens.surface1,
        selectedItemColor: tokens.AppTokens.accent,
        unselectedItemColor: tokens.AppTokens.textTertiary,
        type: BottomNavigationBarType.fixed,
        elevation: tokens.ElevationTokens.none,
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: tokens.AppTokens.accent,
        unselectedLabelColor: tokens.AppTokens.textTertiary,
        indicatorColor: tokens.AppTokens.accent,
        labelStyle: GF.body(
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
        unselectedLabelStyle: GF.body(
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
      ),
    );
  }

  static ThemeData get light {
    final base = ThemeData.light();
    return base.copyWith(
      brightness: Brightness.light,
      scaffoldBackgroundColor: tokens.AppTokens.background,
      primaryColor: tokens.AppTokens.accent,
      textTheme: base.textTheme.apply(
        fontFamily: 'Barlow',
        bodyColor: tokens.AppTokens.textPrimary,
        displayColor: tokens.AppTokens.textPrimary,
      ),
      colorScheme: const ColorScheme.light(
        primary: tokens.AppTokens.accent,
        surface: tokens.AppTokens.surface1,
        onSurface: tokens.AppTokens.textPrimary,
        outline: tokens.AppTokens.border,
      ),
      cardTheme: CardThemeData(
        color: tokens.AppTokens.surface1,
        elevation: tokens.ElevationTokens.none,
        shape: RoundedRectangleBorder(
          borderRadius: tokens.RadiusTokens.circularMd,
          side: const BorderSide(color: tokens.AppTokens.border),
        ),
      ),
      dividerColor: tokens.AppTokens.border,
      appBarTheme: AppBarTheme(
        backgroundColor: tokens.AppTokens.background,
        elevation: tokens.ElevationTokens.none,
        iconTheme: const IconThemeData(color: tokens.AppTokens.textPrimary),
        titleTextStyle: GF.head(
          fontSize: 22,
          fontWeight: FontWeight.w800,
          color: tokens.AppTokens.textPrimary,
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: tokens.AppTokens.surface1,
        selectedItemColor: tokens.AppTokens.accent,
        unselectedItemColor: tokens.AppTokens.textTertiary,
        type: BottomNavigationBarType.fixed,
        elevation: tokens.ElevationTokens.none,
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: tokens.AppTokens.accent,
        unselectedLabelColor: tokens.AppTokens.textTertiary,
        indicatorColor: tokens.AppTokens.accent,
        labelStyle: GF.body(
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
        unselectedLabelStyle: GF.body(
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
      ),
    );
  }
}

extension ThemeX on BuildContext {
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
  Color get bg => tokens.AppTokens.background;
  Color get bg2 => tokens.AppTokens.surface1;
  Color get bg3 => tokens.AppTokens.surface2;
  Color get bg4 => tokens.AppTokens.surface3;
  Color get txt => tokens.AppTokens.textPrimary;
  Color get txt2 => tokens.AppTokens.textSecondary;
  Color get txt3 => tokens.AppTokens.textTertiary;
  Color get brd => tokens.AppTokens.border;

  Color get cardSurface => bg2;

  Color get shadowColor => Colors.black.withValues(alpha: 0.4);

  Color get navActiveBg => tokens.AppTokens.accentMuted;

  Color get liveCardTint => const Color(0xFF1A1216);

  Color get liveCardBorder => tokens.AppTokens.liveRed.withValues(alpha: 0.55);

  Color get scoreLive => tokens.AppTokens.accent;
}

/// Legacy typography helpers - use TypographyTokens instead
/// DEPRECATED: Migrate to TypographyTokens for new code
class GF {
  static TextStyle body({
    double fontSize = 14,
    FontWeight fontWeight = FontWeight.w400,
    Color? color,
    double? letterSpacing,
    double? height,
  }) =>
      TextStyle(
        fontFamily: 'Barlow',
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        letterSpacing: letterSpacing,
        height: height,
      );

  static TextStyle head({
    double fontSize = 22,
    FontWeight fontWeight = FontWeight.w800,
    Color? color,
    double? letterSpacing,
    double? height,
  }) =>
      TextStyle(
        fontFamily: 'BarlowCondensed',
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        letterSpacing: letterSpacing,
        height: height,
      );
}
