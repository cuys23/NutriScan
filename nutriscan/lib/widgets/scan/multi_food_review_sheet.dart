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
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    // Default: everything the scan found is selected; the user deselects
    // what doesn't belong, rather than opting in item by item.
    _selected = Set<int>.from(
      List.generate(widget.candidates.length, (i) => i),
    );
  }

  Future<void> _handleCancel() async {
    // Guards the same way _handleSave does: without this, a fast double-tap
    // could call cancelMultiFoodSelection() twice before the first refund
    // finishes, crediting the coin back twice for one cancelled scan.
    setState(() => _isSaving = true);
    await context.read<FoodProvider>().cancelMultiFoodSelection();
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _handleSave() async {
    setState(() => _isSaving = true);
    final selectedFoods = [for (final i in _selected) widget.candidates[i]];
    try {
      await context.read<FoodProvider>().confirmMultiFoodSelection(
        selectedFoods,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.getString(
              'multi_food_review_save_error',
              widget.currentLanguage,
            ),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;
    final lang = widget.currentLanguage;

    return PopScope(
      // The sheet is shown with isDismissible/enableDrag false so the only
      // way it could otherwise close is the system back button — which does
      // NOT go through isDismissible and would silently leave
      // FoodProvider._pendingMultiFoodCandidates set with no sheet on
      // screen to review it. Route back through the same cancel path as the
      // Cancel button instead of letting it close for free.
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop || _isSaving) return;
        _handleCancel();
      },
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: isDarkMode
                  ? AppColors.surfaceDark
                  : AppColors.surfaceLight,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
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
                  AppLocalizations.getString(
                    'multi_food_review_subtitle',
                    lang,
                  ),
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
                    separatorBuilder: (context, index) =>
                        const Divider(height: 1),
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
                        onPressed: _isSaving ? null : _handleCancel,
                        child: Text(
                          AppLocalizations.getString(
                            'multi_food_review_cancel',
                            lang,
                          ),
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
                        onPressed: (_selected.isEmpty || _isSaving)
                            ? null
                            : _handleSave,
                        child: _isSaving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : Text(
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
      ),
    );
  }
}
