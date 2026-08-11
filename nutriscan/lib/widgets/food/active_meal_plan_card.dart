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
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: AppColors.skSurface(d),
          border: Border.all(color: AppColors.skRule(d)),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header row: label + dismiss ──
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.skSage(d)),
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: Text(
                    AppLocalizations.getString('active_meal_plan', language)
                        .toUpperCase(),
                    style: tp.getBodyFont(
                      fontSize: 10,
                      letterSpacing: 1.4,
                      color: AppColors.skSage(d),
                    ),
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: onDismiss,
                  child: Icon(
                    Icons.close,
                    size: 16,
                    color: AppColors.skMuted(d),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // ── Plan title (serif) ──
            Text(
              plan.planTitle,
              style: tp.getSerifFont(
                fontSize: 22,
                color: AppColors.skInk(d),
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),

            // ── Goal summary ──
            if (plan.goalSummary.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                plan.goalSummary,
                style: tp.getBodyFont(
                  fontSize: 13,
                  height: 1.5,
                  color: AppColors.skBody(d),
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 18),

            // ── Meal list (vertical, each meal is a row) ──
            ...plan.meals.asMap().entries.map((entry) {
              final i = entry.key;
              final meal = entry.value;
              return Container(
                padding: const EdgeInsets.symmetric(vertical: 13),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: i == 0
                          ? AppColors.skRule(d)
                          : AppColors.skRuleSoft(d),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    // Meal type label
                    SizedBox(
                      width: 72,
                      child: Text(
                        _getMealTypeLabel(meal.type),
                        style: tp.getBodyFont(
                          fontSize: 11,
                          letterSpacing: 1.2,
                          color: AppColors.skMuted(d),
                        ),
                      ),
                    ),
                    // Title
                    Expanded(
                      child: Text(
                        meal.title,
                        style: tp.getBodyFont(
                          fontSize: 15,
                          color: AppColors.skInk(d),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    // Calories
                    Text(
                      meal.calories.toStringAsFixed(0),
                      style: tp.getSerifFont(
                        fontSize: 17,
                        color: AppColors.skInk(d),
                      ),
                    ),
                    const SizedBox(width: 3),
                    Text(
                      'kcal',
                      style: tp.getBodyFont(
                        fontSize: 11,
                        color: AppColors.skMuted(d),
                      ),
                    ),
                  ],
                ),
              );
            }),

            // ── Footer: total + view link ──
            Container(
              padding: const EdgeInsets.only(top: 14),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: AppColors.skRule(d)),
                ),
              ),
              child: Row(
                children: [
                  // Total
                  Text(
                    '${AppLocalizations.getString('total', language)}: ',
                    style: tp.getBodyFont(
                      fontSize: 13,
                      color: AppColors.skMuted(d),
                    ),
                  ),
                  Text(
                    '${plan.nutrition.totalCalories.toStringAsFixed(0)} kcal',
                    style: tp.getSerifFont(
                      fontSize: 17,
                      color: AppColors.skInk(d),
                    ),
                  ),
                  const Spacer(),
                  // View details
                  Text(
                    AppLocalizations.getString('view_meal_plan', language),
                    style: tp.getBodyFont(
                      fontSize: 12,
                      letterSpacing: 1.0,
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
