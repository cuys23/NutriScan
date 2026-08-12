import 'package:flutter/material.dart';
import 'package:nutriscan/config/app_colors.dart';
import 'package:nutriscan/config/app_localizations.dart';
import 'package:nutriscan/providers/theme/language_provider.dart';
import 'package:nutriscan/providers/theme/theme_provider.dart';
import 'package:provider/provider.dart';

/// Reusable widget for backup status indicator
class BackupStatusIndicator extends StatelessWidget {
  final bool isSignedIn;

  const BackupStatusIndicator({super.key, required this.isSignedIn});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final languageProvider = Provider.of<LanguageProvider>(context);
    final currentLanguage = languageProvider.currentLanguage;
    final d = themeProvider.isDarkMode;
    final color = isSignedIn ? AppColors.skSage(d) : AppColors.skMuted(d);

    return Container(
      margin: const EdgeInsets.only(right: 16),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.skSurface(d),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isSignedIn ? Icons.check_circle : Icons.cancel,
            color: color,
            size: 12,
          ),
          const SizedBox(width: 4),
          Text(
            isSignedIn
                ? AppLocalizations.getString('signed_in', currentLanguage)
                : AppLocalizations.getString('not_signed_in', currentLanguage),
            style: themeProvider.getBodyFont(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Reusable widget for the "Premium" ribbon on gated sections
class PremiumBadge extends StatelessWidget {
  const PremiumBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final languageProvider = Provider.of<LanguageProvider>(context);
    final currentLanguage = languageProvider.currentLanguage;
    final d = themeProvider.isDarkMode;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.skAccent(d),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        AppLocalizations.getString('premium_badge', currentLanguage),
        style: themeProvider.getBodyFont(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: AppColors.skPaper(d),
        ),
      ),
    );
  }
}
