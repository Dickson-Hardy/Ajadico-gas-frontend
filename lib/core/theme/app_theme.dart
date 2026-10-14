import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// Shared component styling for the operational workspace and all forms.
class AppTheme {
  static ThemeData get lightTheme => _build(Brightness.light);
  static ThemeData get darkTheme => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final surface = dark ? const Color(0xFF172622) : Colors.white;
    final ink = dark ? AppColors.darkInk : AppColors.ink;
    final muted = dark ? AppColors.darkMuted : AppColors.muted;
    final line = dark ? AppColors.darkLine : AppColors.line;
    final primary = dark ? const Color(0xFF65CEB3) : AppColors.primary;
    final scheme = ColorScheme.fromSeed(
            seedColor: AppColors.primary, brightness: brightness)
        .copyWith(
      primary: primary,
      onPrimary: dark ? const Color(0xFF092E24) : Colors.white,
      surface: surface,
      onSurface: ink,
      onSurfaceVariant: muted,
      outlineVariant: line,
      error: AppColors.bad,
    );
    final base = ThemeData(
        useMaterial3: true,
        brightness: brightness,
        colorScheme: scheme,
        fontFamily: 'Roboto');
    final shape =
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(6));
    final border = OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: BorderSide(color: line));
    final text =
        base.textTheme.apply(bodyColor: ink, displayColor: ink).copyWith(
              headlineMedium: TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.7,
                  color: ink),
              titleLarge: TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: ink),
              titleMedium: TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: ink),
              bodyMedium: TextStyle(
                  fontFamily: 'Roboto', fontSize: 14, height: 1.45, color: ink),
              bodySmall: TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 12,
                  height: 1.45,
                  color: muted),
            );
    return base.copyWith(
      scaffoldBackgroundColor:
          dark ? AppColors.darkBackground : AppColors.background,
      textTheme: text.apply(fontFamily: 'Roboto'),
      splashFactory: InkRipple.splashFactory,
      dividerTheme: DividerThemeData(color: line, thickness: 1, space: 1),
      appBarTheme: AppBarTheme(
        backgroundColor: surface,
        foregroundColor: ink,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        toolbarHeight: 72,
        titleTextStyle: TextStyle(
            fontFamily: 'Roboto',
            fontSize: 19,
            fontWeight: FontWeight.w600,
            color: ink),
        iconTheme: IconThemeData(color: muted, size: 21),
        actionsIconTheme: IconThemeData(color: muted, size: 21),
        shape: Border(bottom: BorderSide(color: line)),
      ),
      cardTheme: CardThemeData(
        color: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: const EdgeInsets.only(bottom: 16),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: line)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: dark ? AppColors.darkInput : Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        border: border,
        enabledBorder: border,
        focusedBorder:
            border.copyWith(borderSide: BorderSide(color: primary, width: 1.5)),
        errorBorder:
            border.copyWith(borderSide: const BorderSide(color: AppColors.bad)),
        focusedErrorBorder: border.copyWith(
            borderSide: const BorderSide(color: AppColors.bad, width: 1.5)),
        labelStyle: TextStyle(fontFamily: 'Roboto', color: muted, fontSize: 13),
        hintStyle: TextStyle(fontFamily: 'Roboto', color: muted, fontSize: 13),
        errorStyle:
            const TextStyle(fontFamily: 'Roboto', fontSize: 12, height: 1.4),
        errorMaxLines: 3,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: scheme.onPrimary,
        minimumSize: const Size(48, 46),
        elevation: 0,
        shape: shape,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        textStyle: const TextStyle(
            fontFamily: 'Roboto', fontSize: 13, fontWeight: FontWeight.w600),
      )),
      outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
        foregroundColor: ink,
        minimumSize: const Size(48, 46),
        side: BorderSide(color: line),
        shape: shape,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        textStyle: const TextStyle(
            fontFamily: 'Roboto', fontSize: 13, fontWeight: FontWeight.w500),
      )),
      textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
        foregroundColor: primary,
        minimumSize: const Size(44, 44),
        textStyle: const TextStyle(
            fontFamily: 'Roboto', fontSize: 13, fontWeight: FontWeight.w600),
      )),
      iconButtonTheme: IconButtonThemeData(
          style: IconButton.styleFrom(minimumSize: const Size(44, 44))),
      dataTableTheme: DataTableThemeData(
        headingRowColor: WidgetStatePropertyAll(
            dark ? AppColors.darkInput : const Color(0xFFF6F8F7)),
        headingTextStyle: TextStyle(
            fontFamily: 'Roboto',
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: muted),
        dataTextStyle:
            TextStyle(fontFamily: 'Roboto', fontSize: 13, color: ink),
        headingRowHeight: 44,
        dataRowMinHeight: 56,
        dataRowMaxHeight: 72,
        horizontalMargin: 20,
        columnSpacing: 24,
        dividerThickness: 1,
      ),
      chipTheme: base.chipTheme.copyWith(
        side: BorderSide(color: line),
        shape: shape,
        labelStyle: TextStyle(fontFamily: 'Roboto', fontSize: 12, color: ink),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        titleTextStyle: TextStyle(
            fontFamily: 'Roboto',
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: ink),
        contentTextStyle: TextStyle(
            fontFamily: 'Roboto', fontSize: 14, height: 1.5, color: muted),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: shape,
        contentTextStyle: const TextStyle(
            fontFamily: 'Roboto', fontSize: 13, color: Colors.white),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: primary),
    );
  }
}
