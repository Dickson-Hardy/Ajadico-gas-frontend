import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Central typography system for Ajadico Energy.
/// 
/// Pairs Manrope (for editorial hierarchy, brand titles, and legibility)
/// with JetBrains Mono tabular figures (for ₦ currency columns, fuel dials,
/// and tank volume readings to prevent layout jitter).
class AppTypography {
  // Brand & Page Headings (Manrope)
  static TextStyle heading({
    double fontSize = 24,
    FontWeight fontWeight = FontWeight.w700,
    Color? color,
    double letterSpacing = -0.5,
  }) {
    return GoogleFonts.manrope(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
    );
  }

  // Section & Card Titles
  static TextStyle title({
    double fontSize = 16,
    FontWeight fontWeight = FontWeight.w600,
    Color? color,
    double letterSpacing = -0.2,
  }) {
    return GoogleFonts.manrope(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
    );
  }

  // Body Copy & Explanations
  static TextStyle body({
    double fontSize = 14,
    FontWeight fontWeight = FontWeight.w400,
    Color? color,
    double height = 1.4,
  }) {
    return GoogleFonts.manrope(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: height,
    );
  }

  // Small Badges, Chips & Meta Labels
  static TextStyle caption({
    double fontSize = 12,
    FontWeight fontWeight = FontWeight.w600,
    Color? color,
    double letterSpacing = 0.2,
  }) {
    return GoogleFonts.manrope(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
    );
  }

  /// Tabular numeral typography for currency (₦), volumes (L), and financial matrices.
  /// Enforces monospace glyph alignment so table columns and live tickers do not jitter.
  static TextStyle monoNumeric({
    double fontSize = 16,
    FontWeight fontWeight = FontWeight.w700,
    Color? color,
    double letterSpacing = -0.2,
  }) {
    return GoogleFonts.jetBrainsMono(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
  }

  /// Hero KPI typography for the primary station metric
  static TextStyle heroValue({
    double fontSize = 36,
    FontWeight fontWeight = FontWeight.w800,
    Color? color,
  }) {
    return GoogleFonts.jetBrainsMono(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: -1.0,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
  }
}
