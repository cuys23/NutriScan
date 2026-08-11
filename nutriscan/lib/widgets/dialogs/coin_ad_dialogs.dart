import 'package:flutter/material.dart';
import 'package:nutriscan/config/app_colors.dart';
import 'package:nutriscan/config/app_localizations.dart';
import 'package:nutriscan/providers/theme/language_provider.dart';
import 'package:nutriscan/providers/theme/theme_provider.dart';
import 'package:provider/provider.dart';

class CoinAdDialogs {
  static void showCoinEarnedDialog(BuildContext context, int amount) {
    final tp = context.read<ThemeProvider>();
    final lp = context.read<LanguageProvider>();
    final d = tp.isDarkMode;
    final lang = lp.currentLanguage;

    showDialog(
      context: context,
      builder: (BuildContext ctx) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
          ),
          elevation: 0,
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: AppColors.skPaper(d),
              border: Border.all(color: AppColors.skRule(d)),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icon
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppColors.skSurface(d),
                    border: Border.all(color: AppColors.skRule(d)),
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: Icon(
                    Icons.monetization_on_outlined,
                    size: 28,
                    color: AppColors.skAccent(d),
                  ),
                ),
                const SizedBox(height: 20),

                // Title
                Text(
                  AppLocalizations.getString('coins_earned', lang),
                  style: tp.getSerifFont(
                    fontSize: 22,
                    color: AppColors.skInk(d),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),

                // Description
                Text(
                  AppLocalizations.getString(
                    'you_earned_coins',
                    lang,
                  ).replaceAll('{amount}', amount.toString()),
                  style: tp.getBodyFont(
                    fontSize: 14,
                    color: AppColors.skMuted(d),
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),

                // Divider
                Container(height: 1, color: AppColors.skRule(d)),
                const SizedBox(height: 20),

                // OK button
                GestureDetector(
                  onTap: () => Navigator.of(ctx).pop(),
                  child: Container(
                    width: double.infinity,
                    height: 48,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.skInk(d),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Text(
                      AppLocalizations.getString('ok', lang),
                      style: tp.getBodyFont(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: AppColors.skPaper(d),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static void showAdNotAvailableDialog(BuildContext context) {
    final tp = context.read<ThemeProvider>();
    final lp = context.read<LanguageProvider>();
    final d = tp.isDarkMode;
    final lang = lp.currentLanguage;

    showDialog(
      context: context,
      builder: (BuildContext ctx) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
          ),
          elevation: 0,
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: AppColors.skPaper(d),
              border: Border.all(color: AppColors.skRule(d)),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icon
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppColors.skSurface(d),
                    border: Border.all(color: AppColors.skRule(d)),
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: Icon(
                    Icons.hourglass_empty,
                    size: 24,
                    color: AppColors.skMuted(d),
                  ),
                ),
                const SizedBox(height: 20),

                // Title
                Text(
                  AppLocalizations.getString('ad_not_available', lang),
                  style: tp.getSerifFont(
                    fontSize: 22,
                    color: AppColors.skInk(d),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),

                // Description
                Text(
                  AppLocalizations.getString(
                    'ad_not_available_description',
                    lang,
                  ),
                  style: tp.getBodyFont(
                    fontSize: 14,
                    color: AppColors.skMuted(d),
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),

                // Divider
                Container(height: 1, color: AppColors.skRule(d)),
                const SizedBox(height: 20),

                // OK button
                GestureDetector(
                  onTap: () => Navigator.of(ctx).pop(),
                  child: Container(
                    width: double.infinity,
                    height: 48,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      border: Border.all(color: AppColors.skInk(d)),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Text(
                      AppLocalizations.getString('ok', lang),
                      style: tp.getBodyFont(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: AppColors.skInk(d),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
