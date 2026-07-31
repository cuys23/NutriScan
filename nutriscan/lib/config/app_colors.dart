import 'package:flutter/material.dart';

/// "Calm Wellness Minimal" palette. Field names are kept stable even where
/// the concept shifted (e.g. secondary/accent) so existing call sites don't
/// need a mass rename — only values changed, plus a few additive fields
/// (border*, AppNutrientColors).
class AppColors {
  // Primary / accent — single sage-green accent, replacing the seed blue.
  static const Color primary = Color(0xFF5C7A5E);
  static const Color primaryLight = Color(0xFFE4EAE3); // tint for chips/selected states
  static const Color primaryDark = Color(0xFF46614A); // pressed state

  // Secondary Colors (kept distinct from primary; used sparingly)
  static const Color secondary = Color(0xFF26A69A);
  static const Color secondaryLight = Color(0xFF4DB6AC);
  static const Color secondaryDark = Color(0xFF00897B);

  // Accent Colors
  static const Color accent = Color(0xFF00BCD4);
  static const Color accentLight = Color(0xFF4DD0E1);
  static const Color accentDark = Color(0xFF0097A7);

  // Background Colors
  static const Color backgroundLight = Color(0xFFF7F5F0); // warm off-white
  static const Color backgroundDark = Color(0xFF1E1E1B);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color surfaceDark = Color(0xFF262622);

  // Text Colors
  static const Color textPrimaryLight = Color(0xFF2A2A28); // warm charcoal
  static const Color textSecondaryLight = Color(0xFF6B6B66);
  static const Color textPrimaryDark = Color(0xFFF0EEE6);
  static const Color textSecondaryDark = Color(0xFFA8A69E);

  // Borders — thin-border replacement for hand-rolled shadows.
  static const Color borderLight = Color(0xFFE5E2DB);
  static const Color borderDark = Color(0xFF3A3934);

  // Status Colors — muted, desaturated tones (not saturated Material defaults).
  // Kept distinct from `primary` even though both are green-leaning: primary
  // is the brand/interactive color, success is a status signal.
  static const Color success = Color(0xFF4C8C5B);
  static const Color warning = Color(0xFFC08A3E);
  static const Color error = Color(0xFFB3493C);
  static const Color info = Color(0xFF5B7C99);

  // Neutral Colors
  static const Color grey50 = Color(0xFFFAFAFA);
  static const Color grey100 = Color(0xFFF5F5F5);
  static const Color grey200 = Color(0xFFEEEEEE);
  static const Color grey300 = Color(0xFFE0E0E0);
  static const Color grey400 = Color(0xFFBDBDBD);
  static const Color grey500 = Color(0xFF9E9E9E);
  static const Color grey600 = Color(0xFF757575);
  static const Color grey700 = Color(0xFF616161);
  static const Color grey800 = Color(0xFF424242);
  static const Color grey900 = Color(0xFF212121);
}

/// Deliberate multi-color exception: distinguishing nutrients by color is
/// functional (scannable at a glance), not decorative, so it stays outside
/// the single-accent rule. Replaces raw Colors.orange/blue/green/red/purple/pink
/// previously hardcoded in food_detail_card.dart.
class AppNutrientColors {
  static const Color calories = Color(0xFFC97A3D);
  static const Color protein = Color(0xFF4A7A9E);
  static const Color carbs = Color(0xFF7A9E5B);
  static const Color fat = Color(0xFFB3493C); // shares tone with AppColors.error
  static const Color fiber = Color(0xFF8A6FA3);
  static const Color sugar = Color(0xFFC06A8C);
}
