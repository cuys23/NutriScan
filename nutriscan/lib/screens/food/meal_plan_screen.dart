import 'package:flutter/material.dart';
import 'package:nutriscan/config/app_colors.dart';
import 'package:nutriscan/config/app_localizations.dart';
import 'package:nutriscan/config/exports/providers.dart';
import 'package:nutriscan/config/exports/widgets.dart';
import 'package:nutriscan/utils/page_transition.dart';
import 'package:nutriscan/widgets/common/sk_snackbar.dart';
import 'package:provider/provider.dart';


class MealPlanPreferencesScreen extends StatelessWidget {
  const MealPlanPreferencesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer2<ThemeProvider, LanguageProvider>(
      builder: (context, themeProvider, languageProvider, child) {
        final d = themeProvider.isDarkMode;
        final currentLanguage = languageProvider.currentLanguage;

        return Scaffold(
          backgroundColor: AppColors.skPaper(d),
          appBar: AppBar(
            title: Text(
              AppLocalizations.getString(
                'meal_plan_settings_title',
                currentLanguage,
              ),
              style: themeProvider.getSerifFont(
                fontSize: 22,
                color: AppColors.skInk(d),
              ),
            ),
            backgroundColor: AppColors.skPaper(d),
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.arrow_back, color: AppColors.skInk(d)),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          body: Column(
            children: [
              Expanded(
                child: MealPlanGenerator(
                  showPreferences: true,
                  showResults: false,
                  onPlanGenerated: () {
                    if (!context.mounted) return;
                    Navigator.push(
                      context,
                      PageTransition(child: const MealPlanResultScreen()),
                    );
                  },
                ),
              ),
              const AdaptiveBannerAd(),
            ],
          ),
        );
      },
    );
  }
}

class MealPlanResultScreen extends StatelessWidget {
  const MealPlanResultScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer3<ThemeProvider, LanguageProvider, MealPlanProvider>(
      builder:
          (context, themeProvider, languageProvider, mealPlanProvider, child) {
        final d = themeProvider.isDarkMode;
        final currentLanguage = languageProvider.currentLanguage;

        return Scaffold(
          backgroundColor: AppColors.skPaper(d),
          appBar: AppBar(
            title: Text(
              AppLocalizations.getString(
                'meal_plan_result_title',
                currentLanguage,
              ),
              style: themeProvider.getSerifFont(
                fontSize: 22,
                color: AppColors.skInk(d),
              ),
            ),
            backgroundColor: AppColors.skPaper(d),
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.arrow_back, color: AppColors.skInk(d)),
              onPressed: () => Navigator.of(context).pop(),
            ),
            actions: [
              IconButton(
                icon: Icon(Icons.refresh, color: AppColors.skInk(d)),
                onPressed: mealPlanProvider.isLoading
                    ? null
                    : () async {
                        final attempted = await mealPlanProvider
                            .generateMealPlan(languageCode: currentLanguage);
                        if (!attempted && context.mounted) {
                          SkSnackBar.show(
                            context,
                            message: mealPlanProvider.cooldownMessage(
                              currentLanguage,
                            ),
                          );
                        }
                      },
                tooltip: AppLocalizations.getString(
                  'refresh',
                  currentLanguage,
                ),
              ),
            ],
          ),
          body: Column(
            children: const [
              Expanded(
                child: MealPlanGenerator(
                  showPreferences: false,
                  showResults: true,
                ),
              ),
              AdaptiveBannerAd(),
            ],
          ),
        );
      },
    );
  }
}
