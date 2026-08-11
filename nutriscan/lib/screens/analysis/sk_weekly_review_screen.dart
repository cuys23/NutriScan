import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:nutriscan/config/app_colors.dart';
import 'package:nutriscan/models/food.dart';
import 'package:nutriscan/providers/food/food_provider.dart';
import 'package:nutriscan/providers/theme/theme_provider.dart';
import 'package:provider/provider.dart';

/// The printed weekly review — Slow Kitchen "page on a table" layout.
class SkWeeklyReviewScreen extends StatelessWidget {
  const SkWeeklyReviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final tp = context.watch<ThemeProvider>();
    final fp = context.watch<FoodProvider>();
    final d = tp.isDarkMode;

    final now = DateTime.now();
    final days = List.generate(
        7, (i) => DateUtils.dateOnly(now.subtract(Duration(days: 6 - i))));
    final byDay = <DateTime, List<Food>>{for (final day in days) day: []};
    for (final f in fp.foods) {
      final key = DateUtils.dateOnly(f.analyzedAt);
      byDay[key]?.add(f);
    }
    final kcal = days
        .map((day) => byDay[day]!.fold(0.0, (s, f) => s + f.calories))
        .toList();
    final total = kcal.fold(0.0, (a, b) => a + b);
    final maxKcal = kcal.fold(1.0, (a, b) => a > b ? a : b);
    final week = byDay.values.expand((f) => f).toList();
    final avgScore = week.isEmpty
        ? 0.0
        : week.fold(0.0, (s, f) => s + f.healthScore) / week.length;

    final firstHalf = (kcal[0] + kcal[1] + kcal[2]) / 3;
    final lastHalf = (kcal[4] + kcal[5] + kcal[6]) / 3;
    final rising = lastHalf >= firstHalf;

    Food? best, heaviest;
    for (final f in week) {
      if (best == null || f.healthScore > best.healthScore) best = f;
      if (heaviest == null || f.calories > heaviest.calories) heaviest = f;
    }

    final range =
        '${DateFormat('d').format(days.first)} — ${DateFormat('d MMMM').format(days.last)}';

    return Scaffold(
      backgroundColor: AppColors.skImage(d),
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 12),
              child: Row(
                children: [
                  _BackButton(
                    isDarkMode: d,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'WEEKLY REVIEW',
                    style: tp.getSkLabel(color: AppColors.skMuted(d)),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(26, 32, 26, 30),
                  decoration: BoxDecoration(
                    color: AppColors.skPaper(d),
                    border: Border.all(color: AppColors.skRule(d)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 30,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(range.toUpperCase(),
                              style: tp.getSkLabel(
                                  color: AppColors.skMuted(d))),
                          Text('No. ${_weekOfYear(now)}',
                              style: tp.getSerifFont(
                                  fontSize: 15,
                                  color: AppColors.skFaint(d))),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text(
                        rising
                            ? 'A week that builds towards the weekend.'
                            : 'A steady week, lighter at the weekend.',
                        style: tp.getSerifFont(
                            fontSize: 36,
                            height: 1.1,
                            color: AppColors.skInk(d)),
                      ),
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(color: AppColors.skInk(d)),
                          ),
                        ),
                        child: Row(
                          children: [
                            _stat(tp, d, 'TOTAL', _fmt(total)),
                            _stat(tp, d, 'DAILY', _fmt(total / 7)),
                            _stat(tp, d, 'SCORE',
                                avgScore.toStringAsFixed(1)),
                          ],
                        ),
                      ),
                      ...List.generate(7, (i) {
                        return Container(
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          decoration: BoxDecoration(
                            border: Border(
                              bottom:
                                  BorderSide(color: AppColors.skRule(d)),
                            ),
                          ),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 38,
                                child: Text(
                                  DateFormat('E')
                                      .format(days[i])
                                      .toUpperCase(),
                                  style: tp.getSkLabel(
                                      color: AppColors.skMuted(d)),
                                ),
                              ),
                              Expanded(
                                child: Container(
                                  height: 6,
                                  color: AppColors.skRuleSoft(d),
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: FractionallySizedBox(
                                      widthFactor: (kcal[i] / maxKcal)
                                          .clamp(0.0, 1.0),
                                      child: Container(
                                          color: AppColors.skInk(d)),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              SizedBox(
                                width: 56,
                                child: Text(
                                  _fmt(kcal[i]),
                                  textAlign: TextAlign.right,
                                  style: tp.getSerifFont(
                                      fontSize: 19,
                                      color: AppColors.skInk(d)),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                      const SizedBox(height: 24),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _highlight(tp, d, 'BEST DISH', best?.name ?? '—',
                              best == null ? '' : '${best.healthScore} of 10'),
                          _highlight(
                              tp,
                              d,
                              'HEAVIEST',
                              heaviest?.name ?? '—',
                              heaviest == null
                                  ? ''
                                  : '${_fmt(heaviest.calories)} kcal'),
                        ],
                      ),
                      const SizedBox(height: 26),
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: AppColors.skSurface(d),
                          border: Border.all(color: AppColors.skRule(d)),
                        ),
                        child: Text(
                          rising
                              ? 'Your intake climbs through the week and dips at the weekend. Evening bowls are doing most of the work — keep one protein-forward meal before 8pm and the curve flattens.'
                              : 'Your intake eases off through the week. The weekend is the lightest stretch by a wide margin; if you are training, a larger lunch would carry you better than a late snack.',
                          style: tp.getBodyFont(
                              fontSize: 15,
                              height: 1.6,
                              color: AppColors.skBody(d)),
                        ),
                      ),
                      const SizedBox(height: 22),
                      Center(
                        child: Text(
                          'NUTRISCAN · PRINTED ${DateFormat('d MMMM').format(now).toUpperCase()}',
                          style: tp.getSkLabel(
                              fontSize: 11, color: AppColors.skFaint(d)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _fmt(double v) => NumberFormat('#,##0').format(v.round());

  static int _weekOfYear(DateTime d) =>
      ((d.difference(DateTime(d.year, 1, 1)).inDays) / 7).floor() + 1;

  Widget _stat(ThemeProvider tp, bool d, String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: tp.getSkLabel(
                  fontSize: 11, color: AppColors.skMuted(d))),
          const SizedBox(height: 6),
          Text(value,
              style:
                  tp.getSerifFont(fontSize: 30, color: AppColors.skInk(d))),
        ],
      ),
    );
  }

  Widget _highlight(
      ThemeProvider tp, bool d, String label, String name, String sub) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: tp.getSkLabel(
                  fontSize: 11, color: AppColors.skMuted(d))),
          const SizedBox(height: 6),
          Text(name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: tp.getBodyFont(
                  fontSize: 16, color: AppColors.skInk(d))),
          const SizedBox(height: 2),
          Text(sub,
              style: tp.getBodyFont(
                  fontSize: 13, color: AppColors.skMuted(d))),
        ],
      ),
    );
  }
}

/// Circular back chevron shared by the Slow Kitchen sub-screens.
class _BackButton extends StatelessWidget {
  final bool isDarkMode;
  final VoidCallback onTap;

  const _BackButton({required this.isDarkMode, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 38,
        height: 38,
        child: Icon(Icons.chevron_left,
            size: 24, color: AppColors.skInk(isDarkMode)),
      ),
    );
  }
}
