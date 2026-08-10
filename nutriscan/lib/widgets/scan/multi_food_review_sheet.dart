import 'package:flutter/material.dart';
import 'package:nutriscan/config/app_colors.dart';
import 'package:nutriscan/config/app_localizations.dart';
import 'package:nutriscan/models/food.dart';
import 'package:nutriscan/providers/food/food_provider.dart';
import 'package:nutriscan/providers/theme/theme_provider.dart';
import 'package:nutriscan/widgets/food/source_badge.dart';
import 'package:provider/provider.dart';

/// docs/plan.md Phase 7A — shown when a scan detects more than one food
/// item. Nothing is saved and no coin is spent until the user confirms a
/// selection here (see FoodProvider.confirmMultiFoodSelection).
class MultiFoodReviewSheet extends StatefulWidget {
  final List<Food> candidates;
  final String currentLanguage;

  const MultiFoodReviewSheet({
    super.key,
    required this.candidates,
    required this.currentLanguage,
  });

  @override
  State<MultiFoodReviewSheet> createState() => _MultiFoodReviewSheetState();
}

class _MultiFoodReviewSheetState extends State<MultiFoodReviewSheet> {
  late Set<int> _selected;

  @override
  void initState() {
    super.initState();
    // Default: everything the scan found is selected; the user deselects
    // what doesn't belong, rather than opting in item by item.
    _selected = Set<int>.from(
      List.generate(widget.candidates.length, (i) => i),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;
    final lang = widget.currentLanguage;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: isDarkMode ? AppColors.surfaceDark : AppColors.surfaceLight,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppLocalizations.getString('multi_food_review_title', lang),
                style: themeProvider.getFontForCurrentLanguage(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                AppLocalizations.getString('multi_food_review_subtitle', lang),
                style: themeProvider.getFontForCurrentLanguage(
                  fontSize: 13,
                  color: isDarkMode
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                ),
              ),
              const SizedBox(height: 12),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.5,
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: widget.candidates.length,
                  separatorBuilder: (context, index) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final food = widget.candidates[index];
                    final checked = _selected.contains(index);
                    return CheckboxListTile(
                      value: checked,
                      onChanged: (value) {
                        setState(() {
                          if (value == true) {
                            _selected.add(index);
                          } else {
                            _selected.remove(index);
                          }
                        });
                      },
                      controlAffinity: ListTileControlAffinity.leading,
                      title: Text(
                        food.name,
                        style: themeProvider.getFontForCurrentLanguage(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        '${food.calories.round()} kcal'
                        '${food.portionGrams != null ? ' · ${food.portionGrams!.round()}g' : ''}',
                        style: themeProvider.getFontForCurrentLanguage(
                          fontSize: 12,
                          color: isDarkMode
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondaryLight,
                        ),
                      ),
                      secondary: SourceBadge(
                        source: food.source,
                        currentLanguage: lang,
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        context.read<FoodProvider>().cancelMultiFoodSelection();
                        Navigator.of(context).pop();
                      },
                      child: Text(
                        AppLocalizations.getString('multi_food_review_cancel', lang),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: _selected.isEmpty
                          ? null
                          : () {
                              final selectedFoods = [
                                for (final i in _selected) widget.candidates[i],
                              ];
                              context
                                  .read<FoodProvider>()
                                  .confirmMultiFoodSelection(selectedFoods);
                              Navigator.of(context).pop();
                            },
                      child: Text(
                        '${AppLocalizations.getString('multi_food_review_save', lang)} (${_selected.length})',
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
