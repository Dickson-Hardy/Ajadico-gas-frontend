import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_colors.dart';

class AppTheme {
  /// Daytime Forecourt Light Theme
  static ThemeData get lightTheme {
    final baseTextTheme = ThemeData.light().textTheme;
    final manropeTextTheme = GoogleFonts.manropeTextTheme(baseTextTheme).copyWith(
      headlineLarge: GoogleFonts.manrope(fontWeight: FontWeight.w700, color: AppColors.ink),
      headlineMedium: GoogleFonts.manrope(fontWeight: FontWeight.w700, color: AppColors.ink),
      headlineSmall: GoogleFonts.manrope(fontWeight: FontWeight.w700, color: AppColors.ink),
      titleLarge: GoogleFonts.manrope(fontWeight: FontWeight.w600, color: AppColors.ink),
      titleMedium: GoogleFonts.manrope(fontWeight: FontWeight.w600, color: AppColors.ink),
      titleSmall: GoogleFonts.manrope(fontWeight: FontWeight.w600, color: AppColors.muted),
      bodyLarge: GoogleFonts.manrope(color: AppColors.ink),
      bodyMedium: GoogleFonts.manrope(color: AppColors.ink),
      bodySmall: GoogleFonts.manrope(color: AppColors.muted),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.background,
      textTheme: manropeTextTheme,
      colorScheme: const ColorScheme.light(
        primary: AppColors.ok,
        onPrimary: Colors.white,
        surface: AppColors.card,
        onSurface: AppColors.ink,
        error: AppColors.bad,
        onError: Colors.white,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.ink,
        foregroundColor: AppColors.background,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.manrope(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: AppColors.background,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.card,
        elevation: 0,
        margin: const EdgeInsets.only(bottom: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.line),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.background,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.bank, width: 2),
        ),
        labelStyle: GoogleFonts.manrope(color: AppColors.muted, fontSize: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.ok,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 48),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: GoogleFonts.manrope(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.ink,
          minimumSize: const Size(double.infinity, 48),
          side: const BorderSide(color: AppColors.line),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: GoogleFonts.manrope(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        titleTextStyle: GoogleFonts.manrope(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: AppColors.ink,
        ),
      ),
    );
  }

  /// Night Shift Forecourt Dark Theme
  static ThemeData get darkTheme {
    final baseTextTheme = ThemeData.dark().textTheme;
    final manropeTextTheme = GoogleFonts.manropeTextTheme(baseTextTheme).copyWith(
      headlineLarge: GoogleFonts.manrope(fontWeight: FontWeight.w700, color: AppColors.darkInk),
      headlineMedium: GoogleFonts.manrope(fontWeight: FontWeight.w700, color: AppColors.darkInk),
      headlineSmall: GoogleFonts.manrope(fontWeight: FontWeight.w700, color: AppColors.darkInk),
      titleLarge: GoogleFonts.manrope(fontWeight: FontWeight.w600, color: AppColors.darkInk),
      titleMedium: GoogleFonts.manrope(fontWeight: FontWeight.w600, color: AppColors.darkInk),
      titleSmall: GoogleFonts.manrope(fontWeight: FontWeight.w600, color: AppColors.darkMuted),
      bodyLarge: GoogleFonts.manrope(color: AppColors.darkInk),
      bodyMedium: GoogleFonts.manrope(color: AppColors.darkInk),
      bodySmall: GoogleFonts.manrope(color: AppColors.darkMuted),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.darkBackground,
      textTheme: manropeTextTheme,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.emerald,
        onPrimary: AppColors.darkBackground,
        surface: AppColors.darkCard,
        onSurface: AppColors.darkInk,
        error: AppColors.bad,
        onError: Colors.white,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: AppColors.darkInk,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.manrope(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: AppColors.darkInk,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.darkCard,
        elevation: 0,
        margin: const EdgeInsets.only(bottom: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.darkLine),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.darkInput,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.darkLine),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.darkLine),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.emerald, width: 2),
        ),
        labelStyle: GoogleFonts.manrope(color: AppColors.darkMuted, fontSize: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.emerald,
          foregroundColor: const Color(0xFF064E3B),
          minimumSize: const Size(double.infinity, 48),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: GoogleFonts.manrope(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.darkInk,
          minimumSize: const Size(double.infinity, 48),
          side: const BorderSide(color: AppColors.darkLine),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: GoogleFonts.manrope(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.darkCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        titleTextStyle: GoogleFonts.manrope(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: AppColors.darkInk,
        ),
      ),
    );
  }
}
