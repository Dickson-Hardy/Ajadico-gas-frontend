import 'package:flutter/material.dart';

class AppColors {
  // Light mode surfaces & neutrals
  static const Color ink = Color(0xFF16202A);
  static const Color muted = Color(0xFF5B6773);
  static const Color background = Color(0xFFEEF1F4);
  static const Color card = Color(0xFFFFFFFF);
  static const Color line = Color(0xFFD5DBE1);

  // Dark mode surfaces & neutrals (Forecourt Night Mode)
  static const Color darkBackground = Color(0xFF0B132B); // Deep petrol night
  static const Color darkCard = Color(0xFF1C2541);       // Rich night slate card
  static const Color darkSurface = Color(0xFF1C2541);    // Elevated surface
  static const Color darkLine = Color(0xFF3A506B);       // Subtle midnight stroke
  static const Color darkInk = Color(0xFFF8FAFC);        // Crisp off-white text
  static const Color darkMuted = Color(0xFF94A3B8);      // Muted slate text
  static const Color darkInput = Color(0xFF111D36);      // Inset input field
  
  // Status & semantic colors
  static const Color ok = Color(0xFF0F7B6C);      // Green: confirmed / verified / positive
  static const Color warn = Color(0xFF8A5F00);    // Amber: action required / pending
  static const Color bad = Color(0xFFC23B2E);     // Red: discrepancy / overdue / shortage
  static const Color bank = Color(0xFF2F6FB5);    // Blue: bank deposit / focus state
  static const Color draft = Color(0xFF64748B);   // Slate: not started / draft

  // Brand, UI Surface & Layout Aliases
  static const Color primary = Color(0xFF0F7B6C);         // Deep Teal brand
  static const Color brandPrimary = Color(0xFF0F7B6C);    // Brand primary alias
  static const Color border = Color(0xFFD5DBE1);          // Form & card border alias
  static const Color cardSurface = Color(0xFFFFFFFF);     // Clean card surface
  static const Color lightBackground = Color(0xFFF8FAFC); // Subtle light container tint
  static const Color slate = Color(0xFF64748B);           // Medium slate neutral
  static const Color mutedSlate = Color(0xFF94A3B8);      // Light slate neutral
  static const Color amber = Color(0xFFD97706);           // High-contrast warning amber
  static const Color emerald = Color(0xFF10B981);         // Vibrant success emerald
  static const Color lightEmerald = Color(0xFFD1FAE5);    // Soft success tint
  static const Color cherry = Color(0xFFC23B2E);          // High-contrast alert crimson
  static const Color accent = Color(0xFF0284C7);          // Informational sky accent
  static const Color pos = Color(0xFF5A58E8);             // POS / card terminal branding indigo (AA white-text 5.26)
  static const Color gold = Color(0xFFEAA023);           // Ajadico logo gold — decorative accent on dark surfaces only (not AA on white)

  // Soft status surfaces (light mode)
  static const Color okSurface = Color(0xFFF0FDF4);       // Soft success tint
  static const Color warnSurface = Color(0xFFFFFBEB);     // Soft warning tint
  static const Color badSurface = Color(0xFFFEF2F2);      // Soft error tint
  static const Color lightCherry = Color(0xFFFEE2E2);     // Error banner / destructive tint
  static const Color warnInk = Color(0xFF92400E);         // AA text/icon on warnSurface
  static const Color okInk = Color(0xFF047857);           // AA text/icon on okSurface

  // Soft status surfaces (dark mode)
  static const Color darkOkSurface = Color(0xFF064E3B);
  static const Color darkWarnSurface = Color(0xFF78350F);
  static const Color darkBadSurface = Color(0xFF7F1D1D);

  // Executive Duotone & Gradient Palettes
  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF0D5C52), // Deep Ajadico Petrol Green
      Color(0xFF0F3A4A), // Marine Blue
      Color(0xFF16202A), // Dark Midnight Ink
    ],
  );

  static const LinearGradient executiveEmeraldGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF0F7B6C),
      Color(0xFF059669),
    ],
  );

  static const LinearGradient nightCardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF1E293B),
      Color(0xFF0F172A),
    ],
  );

  static const LinearGradient sparklineGradientPMS = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0x8010B981), // Emerald 50%
      Color(0x0010B981), // Emerald 0%
    ],
  );

  static const LinearGradient sparklineGradientAGO = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0x800284C7), // Sky 50%
      Color(0x000284C7), // Sky 0%
    ],
  );
}
