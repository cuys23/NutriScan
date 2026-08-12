import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:nutriscan/config/app_colors.dart';
import 'package:nutriscan/providers/food/food_provider.dart';
import 'package:nutriscan/providers/theme/theme_provider.dart';
import 'package:provider/provider.dart';

/// Month ledger — a calendar of daily calorie totals, Monday-first.
class SkLedgerScreen extends StatelessWidget {
  const SkLedgerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final tp = context.watch<ThemeProvider>();
    final fp = context.watch<FoodProvider>();
    final d = tp.isDarkMode;

    final now = DateTime.now();
    final daysInMonth = DateUtils.getDaysInMonth(now.year, now.month);
    final byDay = <int, double>{};
    for (final f in fp.foods) {
      if (f.analyzedAt.year == now.year && f.analyzedAt.month == now.month) {
        byDay[f.analyzedAt.day] = (byDay[f.analyzedAt.day] ?? 0) + f.calories;
      }
    }
    final total = byDay.values.fold(0.0, (a, b) => a + b);
    final logged = byDay.length;

    // Monday-first blanks before the 1st.
    final lead = DateTime(now.year, now.month, 1).weekday - 1;

    return Scaffold(
      backgroundColor: AppColors.skPaper(d),
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(28, 10, 28, 16),
              decoration: BoxDecoration(
                border:
                    Border(bottom: BorderSide(color: AppColors.skRule(d))),
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    behavior: HitTestBehavior.opaque,
                    child: SizedBox(
                      width: 38,
                      height: 38,
                      child: Icon(Icons.chevron_left,
                          size: 24, color: AppColors.skInk(d)),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(DateFormat('MMMM').format(now),
                      style: tp.getSerifFont(
                          fontSize: 28, color: AppColors.skInk(d))),
                  const Spacer(),
                  Text('${_fmt(total)} KCAL',
                      style: tp.getSkLabel(color: AppColors.skMuted(d))),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: ['M', 'T', 'W', 'T', 'F', 'S', 'S']
                          .map((l) => Expanded(
                                child: Text(
                                  l,
                                  textAlign: TextAlign.center,
                                  style: tp.getSkLabel(
                                      fontSize: 10,
                                      color: AppColors.skFaint(d)),
                                ),
                              ))
                          .toList(),
                    ),
                    const SizedBox(height: 10),
                    GridView.count(
                      crossAxisCount: 7,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 4,
                      childAspectRatio: ((MediaQuery.of(context).size.width -
                                  48 -
                                  24) /
                              7) /
                          58,
                      children: List.generate(lead + daysInMonth, (i) {
                        if (i < lead) return const SizedBox.shrink();
                        final day = i - lead + 1;
                        final value = byDay[day];
                        final isToday = day == now.day;
                        return Container(
                          padding: const EdgeInsets.only(top: 6),
                          decoration: BoxDecoration(
                            border: Border(
                                top: BorderSide(color: AppColors.skRule(d))),
                          ),
                          child: Column(
                            children: [
                              Text(
                                '$day',
                                style: tp.getBodyFont(
                                  fontSize: 11,
                                  fontWeight: isToday
                                      ? FontWeight.w700
                                      : FontWeight.w400,
                                  color: isToday
                                      ? AppColors.skAccent(d)
                                      : AppColors.skMuted(d),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                value == null ? '·' : _fmt(value),
                                style: tp.getSerifFont(
                                  fontSize: 15,
                                  color: value == null
                                      ? AppColors.skFaint(d)
                                      : AppColors.skInk(d),
                                ),
                              ),
                              if (isToday)
                                Container(
                                  margin: const EdgeInsets.only(top: 4),
                                  width: 16,
                                  height: 2,
                                  color: AppColors.skAccent(d),
                                ),
                            ],
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 26),
                    Container(
                      padding: const EdgeInsets.only(top: 18),
                      decoration: BoxDecoration(
                        border:
                            Border(top: BorderSide(color: AppColors.skInk(d))),
                      ),
                      child: Row(
                        children: [
                          _stat(tp, d, 'DAYS LOGGED', '$logged'),
                          _stat(tp, d, 'DAILY AVERAGE',
                              logged == 0 ? '0' : _fmt(total / logged)),
                          _stat(tp, d, 'STREAK', '${_streak(byDay, now)}'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _fmt(double v) => NumberFormat('#,##0').format(v.round());

  /// Consecutive logged days ending today (or yesterday, if today is empty).
  static int _streak(Map<int, double> byDay, DateTime now) {
    var day = byDay.containsKey(now.day) ? now.day : now.day - 1;
    var count = 0;
    while (day >= 1 && byDay.containsKey(day)) {
      count++;
      day--;
    }
    return count;
  }

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
                  tp.getSerifFont(fontSize: 26, color: AppColors.skInk(d))),
        ],
      ),
    );
  }
}
