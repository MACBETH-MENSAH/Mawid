import 'package:flutter/material.dart';

/// Single source of truth for MAWID's dark navy/blue palette.
/// Matches the Stitch design system — do not hardcode colors elsewhere,
/// reference these constants so a palette change only happens in one place.
class AppColors {
  AppColors._();

  // Backgrounds
  static const Color background = Color(0xFF05070D);
  static const Color surface = Color(0xFF10142A);
  static const Color surfaceElevated = Color(0xFF151A33);

  // Accent
  static const Color accent = Color(0xFF5B7CFA);
  static const Color accentDark = Color(0xFF4C6FFF);

  // Text
  static const Color textPrimary = Color(0xFFF4F6FC);
  static const Color textSecondary = Color(0xFF8A90A6);
  static const Color textMuted = Color(0xFF5C6178);

  // Status (no green, per brand guideline)
  static const Color statusLive = accent;
  static const Color statusWarning = Color(0xFFE0A458);
  static const Color statusDanger = Color(0xFFE0678A);
  static const Color statusNeutral = Color(0xFF8A90A6);

  // Borders / dividers
  static const Color border = Color(0xFF1E2340);
}
