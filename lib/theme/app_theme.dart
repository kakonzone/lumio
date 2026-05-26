// lib/theme/app_theme.dart
import 'package:flutter/material.dart';

class AppColors {
  // Dark mode
  static const bgDark = Color(0xFF0C0C0E);
  static const bg2Dark = Color(0xFF131318);
  static const bg3Dark = Color(0xFF1A1A22);
  static const bg4Dark = Color(0xFF1E1E2A);
  static const txtDark = Color(0xFFFFFFFF);
  static const txt2Dark = Color(0xFFAAAAAA);
  static const txt3Dark = Color(0xFF555555);
  static const borderDark = Color(0xFF1E1E2A);

  // Light mode — clean surfaces, strong readable contrast
  static const bgLight = Color(0xFFF0F2F7);
  static const bg2Light = Color(0xFFFFFFFF);
  static const bg3Light = Color(0xFFE8EBF2);
  static const bg4Light = Color(0xFFD4D9E6);
  static const txtLight = Color(0xFF12141C);
  static const txt2Light = Color(0xFF3A4052);
  static const txt3Light = Color(0xFF6B7385);
  static const borderLight = Color(0xFFD8DEEA);

  // Brand
  static const accent = Color(0xFFFF6B1A);
  static const accentDim = Color(0x1FFF6B1A);
  static const accentLight = Color(0xFFFFF0E8);
  static const liveRed = Color(0xFFE53935);
  static const liveRedDim = Color(0x14E53935);
  static const green = Color(0xFF4CAF50);
  static const blue = Color(0xFF7B9FFF);
  static const red = Color(0xFFE53935);
}

class AppTheme {
  static ThemeData get dark {
    final base = ThemeData.dark();
    return base.copyWith(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.bgDark,
      primaryColor: AppColors.accent,
      textTheme: base.textTheme.apply(
        fontFamily: 'Barlow',
        bodyColor: AppColors.txtDark,
        displayColor: AppColors.txtDark,
      ),
      colorScheme: const ColorScheme.dark(
        primary: AppColors.accent,
        surface: AppColors.bg2Dark,
        onSurface: AppColors.txtDark,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.bgDark,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.txtDark),
        titleTextStyle: GF.head(
          fontSize: 22,
          fontWeight: FontWeight.w800,
          color: AppColors.txtDark,
          letterSpacing: 0.5,
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.bg2Dark,
        selectedItemColor: AppColors.accent,
        unselectedItemColor: AppColors.txt3Dark,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: AppColors.accent,
        unselectedLabelColor: AppColors.txt3Dark,
        indicatorColor: AppColors.accent,
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
      scaffoldBackgroundColor: AppColors.bgLight,
      primaryColor: AppColors.accent,
      textTheme: base.textTheme.apply(
        fontFamily: 'Barlow',
        bodyColor: AppColors.txtLight,
        displayColor: AppColors.txtLight,
      ),
      colorScheme: const ColorScheme.light(
        primary: AppColors.accent,
        surface: AppColors.bg2Light,
        onSurface: AppColors.txtLight,
        outline: AppColors.borderLight,
      ),
      cardTheme: CardThemeData(
        color: AppColors.bg2Light,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: AppColors.borderLight),
        ),
      ),
      dividerColor: AppColors.borderLight,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.bgLight,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.txtLight),
        titleTextStyle: GF.head(
          fontSize: 22,
          fontWeight: FontWeight.w800,
          color: AppColors.txtLight,
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.bg2Light,
        selectedItemColor: AppColors.accent,
        unselectedItemColor: AppColors.txt3Light,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: AppColors.accent,
        unselectedLabelColor: AppColors.txt3Light,
        indicatorColor: AppColors.accent,
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
  Color get bg => isDark ? AppColors.bgDark : AppColors.bgLight;
  Color get bg2 => isDark ? AppColors.bg2Dark : AppColors.bg2Light;
  Color get bg3 => isDark ? AppColors.bg3Dark : AppColors.bg3Light;
  Color get bg4 => isDark ? AppColors.bg4Dark : AppColors.bg4Light;
  Color get txt => isDark ? AppColors.txtDark : AppColors.txtLight;
  Color get txt2 => isDark ? AppColors.txt2Dark : AppColors.txt2Light;
  Color get txt3 => isDark ? AppColors.txt3Dark : AppColors.txt3Light;
  Color get brd => isDark ? AppColors.borderDark : AppColors.borderLight;

  Color get cardSurface => bg2;

  Color get shadowColor => isDark
      ? Colors.black.withValues(alpha: 0.4)
      : const Color(0xFF12141C).withValues(alpha: 0.07);

  Color get navActiveBg =>
      isDark ? AppColors.accent.withValues(alpha: 0.16) : AppColors.accentLight;

  Color get liveCardTint =>
      isDark ? const Color(0xFF1A1216) : const Color(0xFFFFF6F3);

  Color get liveCardBorder => isDark
      ? AppColors.liveRed.withValues(alpha: 0.55)
      : AppColors.liveRed.withValues(alpha: 0.32);

  Color get scoreLive => isDark ? AppColors.accent : const Color(0xFFD84315);
}

/// Bundled Barlow fonts (assets/fonts) — no runtime google_fonts download.
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
