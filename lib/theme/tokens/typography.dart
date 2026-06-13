// lib/theme/tokens/typography.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'colors.dart' as tokens;

class TypographyTokens {
  // Type scale - exactly six sizes, no others
  static TextStyle get caption => GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        letterSpacing: 0,
        height: lineHeightUi,
      );

  static TextStyle get label => GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
        height: lineHeightUi,
      );

  static TextStyle get body => GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        letterSpacing: 0,
        height: lineHeightBody,
      );

  static TextStyle get title => GoogleFonts.inter(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.01,
        height: lineHeightUi,
      );

  static TextStyle get heading => GoogleFonts.inter(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.02,
        height: lineHeightUi,
      );

  static TextStyle get display => GoogleFonts.instrumentSerif(
        fontSize: 40,
        fontWeight: FontWeight.w400,
        letterSpacing: -0.03,
        height: lineHeightDisplay,
      );

  // Line heights
  static const double lineHeightUi = 1.4;
  static const double lineHeightDisplay = 1.1;
  static const double lineHeightBody = 1.6;

  // Color helpers - use these instead of inline color: parameters
  static TextStyle withColor(TextStyle style, Color color) {
    return style.copyWith(color: color);
  }

  // Caption variants
  static TextStyle get captionPrimary =>
      withColor(caption, tokens.AppTokens.textPrimary);
  static TextStyle get captionSecondary =>
      withColor(caption, tokens.AppTokens.textSecondary);
  static TextStyle get captionTertiary =>
      withColor(caption, tokens.AppTokens.textTertiary);
  static TextStyle get captionAccent =>
      withColor(caption, tokens.AppTokens.accent);
  static TextStyle get captionSuccess =>
      withColor(caption, tokens.AppTokens.success);
  static TextStyle get captionDanger =>
      withColor(caption, tokens.AppTokens.danger);
  static TextStyle get captionLive =>
      withColor(caption, tokens.AppTokens.liveRed);

  // Label variants
  static TextStyle get labelPrimary =>
      withColor(label, tokens.AppTokens.textPrimary);
  static TextStyle get labelSecondary =>
      withColor(label, tokens.AppTokens.textSecondary);
  static TextStyle get labelTertiary =>
      withColor(label, tokens.AppTokens.textTertiary);
  static TextStyle get labelAccent => withColor(label, tokens.AppTokens.accent);
  static TextStyle get labelSuccess =>
      withColor(label, tokens.AppTokens.success);
  static TextStyle get labelDanger => withColor(label, tokens.AppTokens.danger);
  static TextStyle get labelLive => withColor(label, tokens.AppTokens.liveRed);

  // Body variants
  static TextStyle get bodyPrimary =>
      withColor(body, tokens.AppTokens.textPrimary);
  static TextStyle get bodySecondary =>
      withColor(body, tokens.AppTokens.textSecondary);
  static TextStyle get bodyTertiary =>
      withColor(body, tokens.AppTokens.textTertiary);
  static TextStyle get bodyAccent => withColor(body, tokens.AppTokens.accent);
  static TextStyle get bodySuccess => withColor(body, tokens.AppTokens.success);
  static TextStyle get bodyDanger => withColor(body, tokens.AppTokens.danger);
  static TextStyle get bodyLive => withColor(body, tokens.AppTokens.liveRed);

  // Title variants
  static TextStyle get titlePrimary =>
      withColor(title, tokens.AppTokens.textPrimary);
  static TextStyle get titleSecondary =>
      withColor(title, tokens.AppTokens.textSecondary);
  static TextStyle get titleTertiary =>
      withColor(title, tokens.AppTokens.textTertiary);
  static TextStyle get titleAccent => withColor(title, tokens.AppTokens.accent);

  // Heading variants
  static TextStyle get headingPrimary =>
      withColor(heading, tokens.AppTokens.textPrimary);
  static TextStyle get headingSecondary =>
      withColor(heading, tokens.AppTokens.textSecondary);
  static TextStyle get headingAccent =>
      withColor(heading, tokens.AppTokens.accent);

  // Display variants
  static TextStyle get displayPrimary =>
      withColor(display, tokens.AppTokens.textPrimary);
  static TextStyle get displaySecondary =>
      withColor(display, tokens.AppTokens.textSecondary);

  // UI font helpers (Inter only)
  static TextStyle inter({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? letterSpacing,
    double? height,
  }) {
    return GoogleFonts.inter(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
      height: height,
    );
  }

  // Display font helper (Instrument Serif only)
  static TextStyle instrumentSerif({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? letterSpacing,
    double? height,
  }) {
    return GoogleFonts.instrumentSerif(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
      height: height,
    );
  }
}
