import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:nutriscan/config/app_colors.dart';
import 'package:nutriscan/models/food.dart';
import 'package:nutriscan/providers/theme/theme_provider.dart';

/// "The day so far" — a 06:00→22:00 rule with one dot per logged meal,
/// sized by calories, plus a marker for the current time.
class SkDayTimeline extends StatelessWidget {
  final List<Food> meals;
  final ThemeProvider themeProvider;
  final bool isDarkMode;

  static const double dayStart = 6;
  static const double dayEnd = 22;

  const SkDayTimeline({
    super.key,
    required this.meals,
    required this.themeProvider,
    required this.isDarkMode,
  });

  static double _hours(DateTime t) => t.hour + t.minute / 60.0;

  static double _frac(double h) =>
      ((h - dayStart) / (dayEnd - dayStart)).clamp(0.0, 1.0);

  /// Longest stretch of the day without a logged meal, e.g. "4h 35m gap
  /// after 07:40". Shown next to the section label.
  static String gapLabel(List<Food> meals) {
    if (meals.isEmpty) return 'No meals yet';
    final timed = meals.toList()
      ..sort((a, b) => a.analyzedAt.compareTo(b.analyzedAt));
    var from = dayStart;
    var to = _hours(timed.first.analyzedAt);
    var after = 'waking';
    for (var i = 1; i < timed.length; i++) {
      final gap =
          _hours(timed[i].analyzedAt) - _hours(timed[i - 1].analyzedAt);
      if (gap > to - from) {
        from = _hours(timed[i - 1].analyzedAt);
        to = _hours(timed[i].analyzedAt);
        after = DateFormat('HH:mm').format(timed[i - 1].analyzedAt);
      }
    }
    final gap = to - from;
    if (gap <= 0) return 'No gaps yet';
    return '${gap.floor()}h ${((gap % 1) * 60).round()}m gap after $after';
  }

  @override
  Widget build(BuildContext context) {
    final d = isDarkMode;
    final timed = meals.toList()
      ..sort((a, b) => a.analyzedAt.compareTo(b.analyzedAt));
    final nowFrac = _frac(_hours(DateTime.now()));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 44,
          child: LayoutBuilder(
            builder: (context, c) {
              final w = c.maxWidth;
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    left: 0,
                    right: 0,
                    top: 9,
                    child: Container(height: 1, color: AppColors.skRule(d)),
                  ),
                  Positioned(
                    left: nowFrac * w,
                    top: 4,
                    child: Container(
                      width: 1,
                      height: 11,
                      color: AppColors.skAccent(d),
                    ),
                  ),
                  ...timed.map((f) {
                    final size =
                        (6 + (f.calories / 800).clamp(0.0, 1.0) * 7).round();
                    final left = _frac(_hours(f.analyzedAt)) * w - 23;
                    return Positioned(
                      left: left.clamp(0.0, w - 46),
                      top: 0,
                      width: 46,
                      child: Column(
                        children: [
                          Container(
                            margin: EdgeInsets.only(top: 9 - size / 2),
                            width: size.toDouble(),
                            height: size.toDouble(),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.skInk(d),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            DateFormat('HH:mm').format(f.analyzedAt),
                            maxLines: 1,
                            style: themeProvider.getBodyFont(
                              fontSize: 11,
                              color: AppColors.skMuted(d),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              );
            },
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('06:00',
                style: themeProvider.getBodyFont(
                    fontSize: 11, color: AppColors.skFaint(d))),
            Text('22:00',
                style: themeProvider.getBodyFont(
                    fontSize: 11, color: AppColors.skFaint(d))),
          ],
        ),
      ],
    );
  }
}
