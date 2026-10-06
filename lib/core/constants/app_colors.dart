import 'package:flutter/material.dart';

class AppColors {
  static const Color ink = Color(0xFF16202A);
  static const Color muted = Color(0xFF5B6773);
  static const Color background = Color(0xFFEEF1F4);
  static const Color card = Color(0xFFFFFFFF);
  static const Color line = Color(0xFFD5DBE1);
  
  // Status & semantic colors
  static const Color ok = Color(0xFF0F7B6C);      // Green: confirmed / verified / positive
  static const Color warn = Color(0xFF8A5F00);    // Amber: action required / pending (AA on white text & as text on light)
  static const Color bad = Color(0xFFC23B2E);     // Red: discrepancy / overdue / shortage
  static const Color bank = Color(0xFF2F6FB5);    // Blue: bank deposit / focus state
  static const Color draft = Color(0xFF64748B);   // Slate: not started / draft (AA on white text)

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
  static const Color pos = Color(0xFF6366F1);             // POS / card terminal branding indigo

  // Soft status surfaces (banners, tinted cards) — pair with the matching ink color
  static const Color okSurface = Color(0xFFF0FDF4);       // Soft success tint
  static const Color warnSurface = Color(0xFFFFFBEB);     // Soft warning tint
  static const Color badSurface = Color(0xFFFEF2F2);      // Soft error tint
  static const Color lightCherry = Color(0xFFFEE2E2);     // Error banner / destructive tint
  static const Color warnInk = Color(0xFF92400E);         // AA text/icon on warnSurface
  static const Color okInk = Color(0xFF047857);           // AA text/icon on okSurface
}
