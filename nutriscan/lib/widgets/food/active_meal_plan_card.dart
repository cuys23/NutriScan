import 'package:flutter/material.dart';
import 'package:nutriscan/config/app_colors.dart';
import 'package:nutriscan/config/app_localizations.dart';
import 'package:nutriscan/models/meal_plan.dart';
import 'package:nutriscan/providers/theme/theme_provider.dart';

/// Compact card shown on the home screen when the user has an active meal plan.
/// Displays meal thumbnails (type icon + title + calories) in a horizontal row,
/// total calories, and a "View Details" link.
class ActiveMealPlanCard extends StatelessWidget {
  const ActiveMealPlanCard({
    super.key,
    required this.plan,
    required this.language,
    required this.themeProvider,
    required this.isDarkMode,
    required this.onTap,
    required this.onDismiss,
  });

  final MealPlan plan;
  final String language;
  final ThemeProvider themeProvider;
  final bool isDarkMode;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDarkMode ? AppColors.surfaceDark : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.2),
            width: 1.5,
          ),
          boxShadow: isDarkMode
              ? null
              : [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row: title + dismiss button
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.restaurant_menu,
                    color: AppColors.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppLocalizations.getString(
                          'active_meal_plan',
                          language,
                        ),
                        style: themeProvider.getFontForCurrentLanguage(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        plan.planTitle,
                        style: themeProvider.getFontForCurrentLanguage(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: isDarkMode
                              ? AppColors.textPrimaryDark
                              : AppColors.textPrimaryLight,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                // Dismiss button
                GestureDetector(
                  onTap: onDismiss,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: isDarkMode
                          ? AppColors.grey800
                          : AppColors.grey100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.close,
                      size: 16,
                      color: isDarkMode
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Meal chips in a horizontal scroll
            SizedBox(
              height: 80,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: plan.meals.length,
                separatorBuilder: (context, index) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  return _buildMealChip(plan.meals[index]);
                },
              ),
            ),
            const SizedBox(height: 14),

            // Footer: total calories + view details
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${AppLocalizations.getString('total', language)}: '
                  '${plan.nutrition.totalCalories.toStringAsFixed(0)} '
                  '${AppLocalizations.getString('cal', language)}',
                  style: themeProvider.getFontForCurrentLanguage(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDarkMode
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
                ),
                Row(
                  children: [
                    Text(
                      AppLocalizations.getString('view_meal_plan', language),
                      style: themeProvider.getFontForCurrentLanguage(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.arrow_forward_ios,
                      size: 12,
                      color: AppColors.primary,
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMealChip(MealPlanMeal meal) {
    return Container(
      width: 80,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: isDarkMode
            ? AppColors.grey800
            : AppColors.grey50,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _getMealIcon(meal.type),
            size: 20,
            color: AppColors.primary,
          ),
          const SizedBox(height: 4),
          Text(
            meal.title,
            style: themeProvider.getFontForCurrentLanguage(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: isDarkMode
                  ? AppColors.textPrimaryDark
                  : AppColors.textPrimaryLight,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 2),
          Text(
            '${meal.calories.toStringAsFixed(0)} cal',
            style: themeProvider.getFontForCurrentLanguage(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: isDarkMode
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getMealIcon(String type) {
    final normalized = type.toLowerCase().trim();
    if (normalized.contains('breakfast') || normalized.contains('morning')) {
      return Icons.wb_sunny_outlined;
    }
    if (normalized.contains('lunch') || normalized.contains('noon')) {
      return Icons.wb_cloudy_outlined;
    }
    if (normalized.contains('dinner') || normalized.contains('supper')) {
      return Icons.nights_stay_outlined;
    }
    if (normalized.contains('snack')) {
      return Icons.cookie_outlined;
    }
    return Icons.restaurant;
  }
}
