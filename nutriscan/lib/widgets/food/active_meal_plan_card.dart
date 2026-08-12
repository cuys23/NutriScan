import 'package:flutter/material.dart';
import 'package:nutriscan/config/app_colors.dart';
import 'package:nutriscan/config/app_localizations.dart';
import 'package:nutriscan/models/meal_plan.dart';
import 'package:nutriscan/providers/theme/theme_provider.dart';

/// ─────────────────────────────────────────────────────────────
/// Slow Kitchen — Active Meal Plan Card
/// Shown on the Today tab when the user has a generated meal plan.
/// Uses SK typography (serif headings, DM Sans body) and
/// warm earthy borders / muted palette.
/// ─────────────────────────────────────────────────────────────
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

  ThemeProvider get tp => themeProvider;
  bool get d => isDarkMode;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.skSurface(d),
          border: Border.all(color: AppColors.skRule(d)),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header row: badge + dismiss ──
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.skSage(d), width: 1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: Text(
                    AppLocalizations.getString('active_meal_plan', language)
                        .toUpperCase(),
                    style: tp.getBodyFont(
                      fontSize: 10,
                      letterSpacing: 1.4,
                      fontWeight: FontWeight.w500,
                      color: AppColors.skSage(d),
                    ),
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: onDismiss,
                  child: Icon(
                    Icons.close,
                    size: 18,
                    color: AppColors.skMuted(d),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // ── Plan title (Instrument Serif) ──
            Text(
              plan.planTitle,
              style: tp.getSerifFont(
                fontSize: 26,
                height: 1.15,
                color: AppColors.skInk(d),
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),

            // ── Goal summary ──
            if (plan.goalSummary.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                plan.goalSummary,
                style: tp.getBodyFont(
                  fontSize: 14,
                  height: 1.45,
                  color: AppColors.skBody(d),
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 14),

            // ── Divider ──
            Divider(color: AppColors.skRule(d), height: 1),

            // ── Meal list ──
            ...plan.meals.map((meal) {
              return Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: AppColors.skRuleSoft(d)),
                  ),
                ),
                child: Row(
                  children: [
                    // Meal type label (MORNING / MIDDAY / SNACK / EVENING)
                    SizedBox(
                      width: 78,
                      child: Text(
                        _getMealTypeLabel(meal.type),
                        style: tp.getBodyFont(
                          fontSize: 11,
                          letterSpacing: 1.2,
                          color: AppColors.skMuted(d),
                        ),
                      ),
                    ),
                    // Title (Serif font as in image 1)
                    Expanded(
                      child: Text(
                        meal.title,
                        style: tp.getSerifFont(
                          fontSize: 17,
                          color: AppColors.skInk(d),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Calories (Serif number + sans unit)
                    Text(
                      meal.calories.toStringAsFixed(0),
                      style: tp.getSerifFont(
                        fontSize: 18,
                        color: AppColors.skInk(d),
                      ),
                    ),
                    const SizedBox(width: 3),
                    Text(
                      'kcal',
                      style: tp.getBodyFont(
                        fontSize: 12,
                        color: AppColors.skMuted(d),
                      ),
                    ),
                  ],
                ),
              );
            }),

            const SizedBox(height: 14),

            // ── Footer row: Total + View Details ──
            Row(
              children: [
                Text(
                  '${AppLocalizations.getString('total', language)}: ',
                  style: tp.getBodyFont(
                    fontSize: 14,
                    color: AppColors.skMuted(d),
                  ),
                ),
                Text(
                  plan.nutrition.totalCalories.toStringAsFixed(0),
                  style: tp.getSerifFont(
                    fontSize: 20,
                    color: AppColors.skInk(d),
                  ),
                ),
                Text(
                  ' kcal',
                  style: tp.getBodyFont(
                    fontSize: 14,
                    color: AppColors.skInk(d),
                  ),
                ),
                const Spacer(),
                Text(
                  AppLocalizations.getString('view_meal_plan', language),
                  style: tp.getSerifFont(
                    fontSize: 16,
                    color: AppColors.skAccent(d),
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.chevron_right,
                  size: 16,
                  color: AppColors.skAccent(d),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Convert meal type string to uppercase label
  String _getMealTypeLabel(String type) {
    final normalized = type.toLowerCase().trim();
    if (normalized.contains('breakfast') || normalized.contains('morning')) {
      return 'MORNING';
    }
    if (normalized.contains('lunch') || normalized.contains('noon')) {
      return 'MIDDAY';
    }
    if (normalized.contains('dinner') || normalized.contains('supper')) {
      return 'EVENING';
    }
    if (normalized.contains('snack')) {
      return 'SNACK';
    }
    return type.toUpperCase();
  }
}
