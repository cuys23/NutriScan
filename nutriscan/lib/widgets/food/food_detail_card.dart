import 'package:flutter/material.dart';
import 'package:iconly/iconly.dart';
import 'package:intl/intl.dart';
import 'package:nutriscan/config/app_colors.dart';
import 'package:nutriscan/config/app_localizations.dart';
import 'package:nutriscan/models/food.dart';
import 'package:nutriscan/providers/food/food_provider.dart';
import 'package:nutriscan/providers/theme/language_provider.dart';
import 'package:nutriscan/providers/theme/theme_provider.dart';
import 'package:nutriscan/utils/image_helper.dart';
import 'package:nutriscan/widgets/food/source_badge.dart';
import 'package:provider/provider.dart';

/// ─────────────────────────────────────────────────────────────
/// Slow Kitchen — Food Detail Card / Sheet
/// Elegant paper container with serif titles, warm muted stat boxes,
/// sage/accent badges, and SK pill delete button.
/// ─────────────────────────────────────────────────────────────
class FoodDetailCard extends StatefulWidget {
  final Food food;
  final VoidCallback? onFoodDeleted;

  const FoodDetailCard({super.key, required this.food, this.onFoodDeleted});

  @override
  State<FoodDetailCard> createState() => _FoodDetailCardState();
}

class _FoodDetailCardState extends State<FoodDetailCard> {
  @override
  Widget build(BuildContext context) {
    final tp = context.watch<ThemeProvider>();
    final lang = context.watch<LanguageProvider>().currentLanguage;
    final d = tp.isDarkMode;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.skPaper(d),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        border: Border.all(color: AppColors.skRule(d)),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Food Image & Floating Badges ──
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
              child: SizedBox(
                height: 220,
                width: double.infinity,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: ImageHelper.getImageWidget(
                        widget.food.effectiveImageUrl,
                        width: double.infinity,
                        height: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                    // Score Badge (Top Right)
                    Positioned(
                      top: 14,
                      right: 14,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppColors.skSurface(d).withValues(alpha: 0.92),
                          border: Border.all(color: AppColors.skSage(d)),
                          borderRadius: BorderRadius.circular(2),
                        ),
                        child: Text(
                          '${AppLocalizations.getString('score', lang).toUpperCase()}: ${widget.food.healthScore}',
                          style: tp.getBodyFont(
                            color: AppColors.skSage(d),
                            fontSize: 11,
                            letterSpacing: 1.2,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    // Title Banner (Bottom Left)
                    Positioned(
                      bottom: 14,
                      left: 14,
                      right: 14,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.skSurface(d).withValues(alpha: 0.94),
                          border: Border.all(color: AppColors.skRule(d)),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          widget.food.name,
                          style: tp.getSerifFont(
                            color: AppColors.skInk(d),
                            fontSize: 20,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Description ──
                  Builder(
                    builder: (_) {
                      final isEmpty = widget.food.description.trim().isEmpty ||
                          widget.food.description == 'No description available';
                      final text = isEmpty
                          ? AppLocalizations.getString(
                              'no_description_available', lang)
                          : widget.food.description;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppLocalizations.getString('description', lang),
                            style: tp.getSerifFont(
                              fontSize: 20,
                              color: AppColors.skInk(d),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            text,
                            style: tp.getBodyFont(
                              fontSize: 14,
                              color: AppColors.skBody(d),
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],
                      );
                    },
                  ),

                  // ── Nutrition Grid ──
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        AppLocalizations.getString('nutrition', lang),
                        style: tp.getSerifFont(
                          fontSize: 20,
                          color: AppColors.skInk(d),
                        ),
                      ),
                      SourceBadge(
                        source: widget.food.source,
                        currentLanguage: lang,
                      ),
                    ],
                  ),
                  if (widget.food.source == 'verified') ...[
                    const SizedBox(height: 4),
                    Text(
                      AppLocalizations.getString(
                        'source_verified_subtitle',
                        lang,
                      ),
                      style: tp.getBodyFont(
                        fontSize: 12,
                        color: AppColors.skMuted(d),
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),

                  // SK Nutrition Stat Grid (2 columns)
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 2.3,
                    children: [
                      _buildNutritionStat(
                        tp,
                        d,
                        AppLocalizations.getString('calories', lang),
                        '${widget.food.calories.toStringAsFixed(0)} kcal',
                        AppColors.skAccent(d),
                      ),
                      _buildNutritionStat(
                        tp,
                        d,
                        AppLocalizations.getString('protein', lang),
                        '${widget.food.protein.toStringAsFixed(1)}g',
                        AppColors.skSage(d),
                      ),
                      _buildNutritionStat(
                        tp,
                        d,
                        AppLocalizations.getString('carbs', lang),
                        '${widget.food.carbs.toStringAsFixed(1)}g',
                        AppColors.skAccent(d),
                      ),
                      _buildNutritionStat(
                        tp,
                        d,
                        AppLocalizations.getString('fat', lang),
                        '${widget.food.fat.toStringAsFixed(1)}g',
                        AppColors.skMuted(d),
                      ),
                      _buildNutritionStat(
                        tp,
                        d,
                        AppLocalizations.getString('fiber', lang),
                        '${widget.food.fiber.toStringAsFixed(1)}g',
                        AppColors.skSage(d),
                      ),
                      _buildNutritionStat(
                        tp,
                        d,
                        AppLocalizations.getString('sugar', lang),
                        '${widget.food.sugar.toStringAsFixed(1)}g',
                        AppColors.skMuted(d),
                      ),
                    ],
                  ),

                  const SizedBox(height: 22),

                  // ── Health Benefits ──
                  if (widget.food.healthBenefits.isNotEmpty) ...[
                    Text(
                      AppLocalizations.getString('health_benefits', lang),
                      style: tp.getSerifFont(
                        fontSize: 20,
                        color: AppColors.skInk(d),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.food.healthBenefits.join('\n'),
                      style: tp.getBodyFont(
                        fontSize: 14,
                        color: AppColors.skBody(d),
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // ── Health Warnings ──
                  if (widget.food.healthWarnings.isNotEmpty) ...[
                    Text(
                      AppLocalizations.getString('health_warnings', lang),
                      style: tp.getSerifFont(
                        fontSize: 20,
                        color: AppColors.skInk(d),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.food.healthWarnings.join('\n'),
                      style: tp.getBodyFont(
                        fontSize: 14,
                        color: AppColors.skAccent(d),
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // ── Serving Size & Date ──
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              AppLocalizations.getString('serving_size', lang)
                                  .toUpperCase(),
                              style: tp.getBodyFont(
                                fontSize: 11,
                                letterSpacing: 1.2,
                                color: AppColors.skMuted(d),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.food.servingSize,
                              style: tp.getSerifFont(
                                fontSize: 18,
                                color: AppColors.skInk(d),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            AppLocalizations.getString('date', lang)
                                .toUpperCase(),
                            style: tp.getBodyFont(
                              fontSize: 11,
                              letterSpacing: 1.2,
                              color: AppColors.skMuted(d),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            DateFormat('dd MMM yyyy')
                                .format(widget.food.analyzedAt),
                            style: tp.getSerifFont(
                              fontSize: 18,
                              color: AppColors.skInk(d),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 28),

                  // ── Delete Button ──
                  GestureDetector(
                    onTap: () => _showDeleteDialog(context),
                    child: Container(
                      height: 52,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: AppColors.skSurface(d),
                        border: Border.all(color: AppColors.skAccent(d)),
                        borderRadius: BorderRadius.circular(26),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(IconlyLight.delete,
                              size: 18, color: AppColors.skAccent(d)),
                          const SizedBox(width: 8),
                          Text(
                            AppLocalizations.getString('delete', lang),
                            style: tp.getBodyFont(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: AppColors.skAccent(d),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNutritionStat(
    ThemeProvider tp,
    bool d,
    String label,
    String value,
    Color indicatorColor,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.skSurface(d),
        border: Border.all(color: AppColors.skRuleSoft(d)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: indicatorColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label.toUpperCase(),
                  style: tp.getBodyFont(
                    fontSize: 10,
                    letterSpacing: 1.1,
                    color: AppColors.skMuted(d),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: tp.getSerifFont(
              fontSize: 17,
              color: AppColors.skInk(d),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(BuildContext context) {
    final tp = Provider.of<ThemeProvider>(context, listen: false);
    final lang =
        Provider.of<LanguageProvider>(context, listen: false).currentLanguage;
    final d = tp.isDarkMode;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.skPaper(d),
              border: Border.all(color: AppColors.skRule(d)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  IconlyLight.delete,
                  size: 40,
                  color: AppColors.skAccent(d),
                ),
                const SizedBox(height: 16),
                Text(
                  AppLocalizations.getString('delete_food', lang),
                  style: tp.getSerifFont(
                    fontSize: 22,
                    color: AppColors.skInk(d),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text(
                  '${AppLocalizations.getString('delete_confirmation', lang)} "${widget.food.name}"?',
                  style: tp.getBodyFont(
                    fontSize: 14,
                    color: AppColors.skBody(d),
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: Container(
                          height: 44,
                          decoration: BoxDecoration(
                            border: Border.all(color: AppColors.skRule(d)),
                            borderRadius: BorderRadius.circular(22),
                          ),
                          child: Center(
                            child: Text(
                              AppLocalizations.getString('cancel', lang),
                              style: tp.getBodyFont(
                                fontSize: 14,
                                color: AppColors.skInk(d),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: () async {
                          await context
                              .read<FoodProvider>()
                              .deleteFood(widget.food.id);
                          if (!mounted) return;
                          Navigator.of(context).pop();
                          if (widget.onFoodDeleted != null) {
                            widget.onFoodDeleted!();
                          }
                        },
                        child: Container(
                          height: 44,
                          decoration: BoxDecoration(
                            color: AppColors.skInk(d),
                            borderRadius: BorderRadius.circular(22),
                          ),
                          child: Center(
                            child: Text(
                              AppLocalizations.getString('delete', lang),
                              style: tp.getBodyFont(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: AppColors.skPaper(d),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
