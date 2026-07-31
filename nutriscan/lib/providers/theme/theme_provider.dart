import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:nutriscan/config/app_colors.dart';
import 'package:nutriscan/config/radii.dart';
import 'package:nutriscan/config/spacing.dart';
import 'package:nutriscan/providers/theme/language_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  bool _isDarkMode = false;

  bool get isDarkMode => _isDarkMode;
  SharedPreferences? _prefs;
  LanguageProvider? _languageProvider;

  void setLanguageProvider(LanguageProvider languageProvider) {
    _languageProvider = languageProvider;
    // Listen to language changes
    _languageProvider!.addListener(() {
      notifyListeners();
    });
    notifyListeners();
  }

  // Get current font family based on language
  String get currentFontFamily => 'Poppins';

  // Get real font family names from GoogleFonts to ensure they are registered for fallback
  List<String> get _fontFallbacks {
    final List<String> fallbacks = [];
    
    // Add current language font first after Poppins if it's not English
    if (_languageProvider != null && _languageProvider!.currentLanguage != 'en') {
      try {
        final langFont = _languageProvider!.currentFontFamily;
        // We use a dummy TextStyle to trigger GoogleFonts to register the font family name
        final style = GoogleFonts.getFont(langFont);
        if (style.fontFamily != null) {
          fallbacks.add(style.fontFamily!);
        }
      } catch (e) {
        debugPrint('Error getting language font: $e');
      }
    }

    // Add other common fonts as extras
    try {
      fallbacks.addAll([
        GoogleFonts.hindSiliguri().fontFamily!,
        GoogleFonts.amiko().fontFamily!,
        GoogleFonts.notoSansSc().fontFamily!,
        GoogleFonts.cairo().fontFamily!,
      ]);
    } catch (e) {
      debugPrint('Error loading font fallbacks: $e');
      // Fallback to string names if something goes wrong
      fallbacks.addAll(['Hind Siliguri', 'Amiko', 'Noto Sans SC', 'Cairo']);
    }

    // Remove duplicates
    return fallbacks.toSet().toList();
  }

  // Helper method to apply font fallbacks to a TextTheme
  TextTheme _applyFontToTextTheme(TextTheme base) {
    return base.copyWith(
      displayLarge: base.displayLarge?.copyWith(
        fontFamily: 'Poppins',
        fontFamilyFallback: _fontFallbacks,
      ),
      displayMedium: base.displayMedium?.copyWith(
        fontFamily: 'Poppins',
        fontFamilyFallback: _fontFallbacks,
      ),
      displaySmall: base.displaySmall?.copyWith(
        fontFamily: 'Poppins',
        fontFamilyFallback: _fontFallbacks,
      ),
      headlineLarge: base.headlineLarge?.copyWith(
        fontFamily: 'Poppins',
        fontFamilyFallback: _fontFallbacks,
      ),
      headlineMedium: base.headlineMedium?.copyWith(
        fontFamily: 'Poppins',
        fontFamilyFallback: _fontFallbacks,
      ),
      headlineSmall: base.headlineSmall?.copyWith(
        fontFamily: 'Poppins',
        fontFamilyFallback: _fontFallbacks,
      ),
      titleLarge: base.titleLarge?.copyWith(
        fontFamily: 'Poppins',
        fontFamilyFallback: _fontFallbacks,
      ),
      titleMedium: base.titleMedium?.copyWith(
        fontFamily: 'Poppins',
        fontFamilyFallback: _fontFallbacks,
      ),
      titleSmall: base.titleSmall?.copyWith(
        fontFamily: 'Poppins',
        fontFamilyFallback: _fontFallbacks,
      ),
      bodyLarge: base.bodyLarge?.copyWith(
        fontFamily: 'Poppins',
        fontFamilyFallback: _fontFallbacks,
      ),
      bodyMedium: base.bodyMedium?.copyWith(
        fontFamily: 'Poppins',
        fontFamilyFallback: _fontFallbacks,
      ),
      bodySmall: base.bodySmall?.copyWith(
        fontFamily: 'Poppins',
        fontFamilyFallback: _fontFallbacks,
      ),
      labelLarge: base.labelLarge?.copyWith(
        fontFamily: 'Poppins',
        fontFamilyFallback: _fontFallbacks,
      ),
      labelMedium: base.labelMedium?.copyWith(
        fontFamily: 'Poppins',
        fontFamilyFallback: _fontFallbacks,
      ),
      labelSmall: base.labelSmall?.copyWith(
        fontFamily: 'Poppins',
        fontFamilyFallback: _fontFallbacks,
      ),
    );
  }

  /// Shared type scale (Calm Wellness Minimal) — same size/weight/letter
  /// spacing in light and dark, only the color differs by brightness. Feeds
  /// into `_applyFontToTextTheme`, which still injects Poppins + the
  /// per-language fallback chain on top of this.
  TextTheme _typeScale({required Color primaryColor, required Color secondaryColor}) {
    return TextTheme(
      displayLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.w700, letterSpacing: -0.5, color: primaryColor),
      displayMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: -0.5, color: primaryColor),
      displaySmall: TextStyle(fontSize: 24, fontWeight: FontWeight.w600, letterSpacing: -0.25, color: primaryColor),
      headlineLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: primaryColor),
      headlineMedium: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: primaryColor),
      headlineSmall: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: primaryColor),
      titleLarge: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: primaryColor),
      titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: 0.1, color: primaryColor),
      titleSmall: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 0.1, color: primaryColor),
      bodyLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w400, height: 1.5, color: primaryColor),
      bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w400, height: 1.4, color: secondaryColor),
      bodySmall: TextStyle(fontSize: 12, fontWeight: FontWeight.w400, letterSpacing: 0.1, color: secondaryColor),
      labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, letterSpacing: 0.2, color: primaryColor),
      labelMedium: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, letterSpacing: 0.2, color: secondaryColor),
      labelSmall: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, letterSpacing: 0.3, color: secondaryColor),
    );
  }

  TextStyle getFontForCurrentLanguage({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? height,
    TextDecoration? decoration,
    double? letterSpacing,
    FontStyle? fontStyle,
    Color? backgroundColor,
  }) {
    return GoogleFonts.poppins(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: height,
      decoration: decoration,
      letterSpacing: letterSpacing,
      fontStyle: fontStyle,
      backgroundColor: backgroundColor,
    ).copyWith(fontFamilyFallback: _fontFallbacks);
  }

  ThemeProvider() {
    _loadThemePreference();
  }

  Future<void> _loadThemePreference() async {
    _prefs = await SharedPreferences.getInstance();
    _isDarkMode = _prefs?.getBool('dark_mode_enabled') ?? false;
    notifyListeners();
  }

  Future<void> toggleTheme() async {
    // Immediately update UI
    _isDarkMode = !_isDarkMode;
    notifyListeners();

    // Save to storage in background
    try {
      if (_prefs != null) {
        await _prefs!.setBool('dark_mode_enabled', _isDarkMode);
      } else {
        _prefs = await SharedPreferences.getInstance();
        await _prefs!.setBool('dark_mode_enabled', _isDarkMode);
      }
    } catch (e) {
      debugPrint('Error saving theme preference: $e');
      _isDarkMode = !_isDarkMode;
      notifyListeners();
    }
  }

  ThemeData get lightTheme {
    return ThemeData(
      primarySwatch: Colors.blue,
      primaryColor: AppColors.primary,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        brightness: Brightness.light,
      ),
      useMaterial3: true,
      fontFamily: currentFontFamily,
      fontFamilyFallback: _fontFallbacks,
      textTheme: _applyFontToTextTheme(
        _typeScale(primaryColor: AppColors.textPrimaryLight, secondaryColor: AppColors.textSecondaryLight),
      ),
      primaryTextTheme: _applyFontToTextTheme(ThemeData.light().primaryTextTheme),
      scaffoldBackgroundColor: AppColors.backgroundLight,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.backgroundLight,
        foregroundColor: AppColors.textPrimaryLight,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimaryLight,
          fontFamily: currentFontFamily,
          fontFamilyFallback: _fontFallbacks,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: Radii.smRadius,
          ),
          textStyle: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.2,
            fontFamily: currentFontFamily,
            fontFamilyFallback: _fontFallbacks,
          ),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: Radii.lgRadius,
          side: const BorderSide(color: AppColors.borderLight),
        ),
        color: AppColors.surfaceLight,
      ),
      listTileTheme: ListTileThemeData(
        tileColor: AppColors.surfaceLight,
        shape: RoundedRectangleBorder(borderRadius: Radii.smRadius),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.primary;
          }
          return Colors.grey;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.primary.withValues(alpha: 0.5);
          }
          return Colors.grey.withValues(alpha: 0.5);
        }),
      ),
      inputDecorationTheme: InputDecorationThemeData(
        filled: true,
        fillColor: AppColors.surfaceLight,
        contentPadding: const EdgeInsets.symmetric(horizontal: Spacing.lg, vertical: Spacing.md),
        border: OutlineInputBorder(
          borderRadius: Radii.smRadius,
          borderSide: const BorderSide(color: AppColors.borderLight),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: Radii.smRadius,
          borderSide: const BorderSide(color: AppColors.borderLight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: Radii.smRadius,
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surfaceLight,
        shape: RoundedRectangleBorder(borderRadius: Radii.lgRadius),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: AppColors.surfaceLight,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textSecondaryLight,
        type: BottomNavigationBarType.fixed,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.primaryLight,
        labelStyle: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w500),
        shape: RoundedRectangleBorder(borderRadius: Radii.smRadius),
        side: BorderSide.none,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.textPrimaryLight,
        contentTextStyle: const TextStyle(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: Radii.smRadius),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  ThemeData get darkTheme {
    return ThemeData(
      primarySwatch: Colors.blue,
      primaryColor: AppColors.primary,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        brightness: Brightness.dark,
      ),
      useMaterial3: true,
      fontFamily: currentFontFamily,
      fontFamilyFallback: _fontFallbacks,
      textTheme: _applyFontToTextTheme(
        _typeScale(primaryColor: AppColors.textPrimaryDark, secondaryColor: AppColors.textSecondaryDark),
      ),
      primaryTextTheme: _applyFontToTextTheme(ThemeData.dark().primaryTextTheme),
      scaffoldBackgroundColor: AppColors.backgroundDark,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.backgroundDark,
        foregroundColor: AppColors.textPrimaryDark,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimaryDark,
          fontFamily: currentFontFamily,
          fontFamilyFallback: _fontFallbacks,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: Radii.smRadius,
          ),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.2,
            fontFamily: 'Poppins',
          ),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: Radii.lgRadius,
          side: const BorderSide(color: AppColors.borderDark),
        ),
        color: AppColors.surfaceDark,
      ),
      listTileTheme: ListTileThemeData(
        tileColor: AppColors.surfaceDark,
        shape: RoundedRectangleBorder(borderRadius: Radii.smRadius),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.primary;
          }
          return Colors.grey;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.primary.withValues(alpha: 0.5);
          }
          return Colors.grey.withValues(alpha: 0.5);
        }),
      ),
      inputDecorationTheme: InputDecorationThemeData(
        filled: true,
        fillColor: AppColors.surfaceDark,
        contentPadding: const EdgeInsets.symmetric(horizontal: Spacing.lg, vertical: Spacing.md),
        border: OutlineInputBorder(
          borderRadius: Radii.smRadius,
          borderSide: const BorderSide(color: AppColors.borderDark),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: Radii.smRadius,
          borderSide: const BorderSide(color: AppColors.borderDark),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: Radii.smRadius,
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surfaceDark,
        shape: RoundedRectangleBorder(borderRadius: Radii.lgRadius),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: AppColors.surfaceDark,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textSecondaryDark,
        type: BottomNavigationBarType.fixed,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.primary.withValues(alpha: 0.18),
        labelStyle: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w500),
        shape: RoundedRectangleBorder(borderRadius: Radii.smRadius),
        side: BorderSide.none,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.surfaceDark,
        contentTextStyle: TextStyle(color: AppColors.textPrimaryDark),
        shape: RoundedRectangleBorder(borderRadius: Radii.smRadius),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
