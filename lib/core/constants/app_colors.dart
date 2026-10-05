import 'package:flutter/material.dart';

class AppColors {
  static const Color ink = Color(0xFF16202A);
  static const Color muted = Color(0xFF5B6773);
  static const Color background = Color(0xFFEEF1F4);
  static const Color card = Color(0xFFFFFFFF);
  static const Color line = Color(0xFFD5DBE1);
  
  // Status & semantic colors
  static const Color ok = Color(0xFF0F7B6C);      // Green: confirmed / verified / positive
  static const Color warn = Color(0xFFB77F00);    // Amber: action required / pending
  static const Color bad = Color(0xFFC23B2E);     // Red: discrepancy / overdue / shortage
  static const Color bank = Color(0xFF2F6FB5);    // Blue: bank deposit / focus state
  static const Color draft = Color(0xFF7A8591);   // Slate: not started / draft
}
