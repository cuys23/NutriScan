import 'package:flutter/material.dart';

class AppColors {
  // Primary Colors
  static const Color primary = Color(0xFF2563EB);
  static const Color primaryLight = Color(0xFF60A5FA);
  static const Color primaryDark = Color(0xFF1E40AF);

  // Secondary Colors
  static const Color secondary = Color(0xFF26A69A);
  static const Color secondaryLight = Color(0xFF4DB6AC);
  static const Color secondaryDark = Color(0xFF00897B);

  // Accent Colors
  static const Color accent = Color(0xFF00BCD4);
  static const Color accentLight = Color(0xFF4DD0E1);
  static const Color accentDark = Color(0xFF0097A7);

  // Background Colors
  static const Color backgroundLight = Color(0xFFFAFAFA);
  static const Color backgroundDark = Color(0xFF121212);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color surfaceDark = Color(0xFF1E1E1E);

  // Text Colors
  static const Color textPrimaryLight = Color(0xFF212121);
  static const Color textSecondaryLight = Color(0xFF757575);
  static const Color textPrimaryDark = Color(0xFFFFFFFF);
  static const Color textSecondaryDark = Color(0xFFB3B3B3);

  // Status Colors
  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFFF9800);
  static const Color error = Color(0xFFF44336);
  static const Color info = Color(0xFF2196F3);

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

  // ──────────────────────────────────────────────────────────────
  // Slow Kitchen — warm editorial color palette
  // ──────────────────────────────────────────────────────────────

  /// Resolve an SK color for the current brightness.
  static Color sk(Color light, Color dark, bool isDark) => isDark ? dark : light;

  // Light
  static const Color skPaperLight = Color(0xFFF4EFE7);
  static const Color skSurfaceLight = Color(0xFFFBF8F2);
  static const Color skInkLight = Color(0xFF1C1A17);
  static const Color skMutedLight = Color(0xFF8A8578);
  static const Color skRuleLight = Color(0xFFDFD8CB);
  static const Color skRuleSoftLight = Color(0xFFE3DDD2);
  static const Color skImageLight = Color(0xFFEAE4D9);
  static const Color skAccentLight = Color(0xFFC4552F);
  static const Color skSageLight = Color(0xFF6B7F5C);
  static const Color skBodyLight = Color(0xFF57534C);
  static const Color skFaintLight = Color(0xFFC9C1B2);
  static const Color skTabOffLight = Color(0xFFA8A296);

  // Dark
  static const Color skPaperDark = Color(0xFF17150F);
  static const Color skSurfaceDark = Color(0xFF201C15);
  static const Color skInkDark = Color(0xFFF0EAE0);
  static const Color skMutedDark = Color(0xFF9C9484);
  static const Color skRuleDark = Color(0xFF342E24);
  static const Color skRuleSoftDark = Color(0xFF2B261D);
  static const Color skImageDark = Color(0xFF262117);
  static const Color skAccentDark = Color(0xFFE2814F);
  static const Color skSageDark = Color(0xFF9DB487);
  static const Color skBodyDark = Color(0xFFC2BAA9);
  static const Color skFaintDark = Color(0xFF4A4335);
  static const Color skTabOffDark = Color(0xFF6E675A);

  // Convenience getters — pass isDarkMode
  static Color skPaper(bool d) => sk(skPaperLight, skPaperDark, d);
  static Color skSurface(bool d) => sk(skSurfaceLight, skSurfaceDark, d);
  static Color skInk(bool d) => sk(skInkLight, skInkDark, d);
  static Color skMuted(bool d) => sk(skMutedLight, skMutedDark, d);
  static Color skRule(bool d) => sk(skRuleLight, skRuleDark, d);
  static Color skRuleSoft(bool d) => sk(skRuleSoftLight, skRuleSoftDark, d);
  static Color skImage(bool d) => sk(skImageLight, skImageDark, d);
  static Color skAccent(bool d) => sk(skAccentLight, skAccentDark, d);
  static Color skSage(bool d) => sk(skSageLight, skSageDark, d);
  static Color skBody(bool d) => sk(skBodyLight, skBodyDark, d);
  static Color skFaint(bool d) => sk(skFaintLight, skFaintDark, d);
  static Color skTabOff(bool d) => sk(skTabOffLight, skTabOffDark, d);
}
