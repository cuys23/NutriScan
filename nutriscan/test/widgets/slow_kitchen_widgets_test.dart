import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:nutriscan/config/app_colors.dart';
import 'package:nutriscan/models/food.dart';
import 'package:nutriscan/providers/theme/theme_provider.dart';
import 'package:nutriscan/widgets/analysis/sk_line_chart.dart';
import 'package:nutriscan/widgets/common/sk_torn_divider.dart';
import 'package:nutriscan/widgets/home/sk_day_timeline.dart';
import 'package:shared_preferences/shared_preferences.dart';

Food meal({required int hour, required int minute, double kcal = 480}) => Food(
      id: '$hour:$minute',
      name: 'Phở bò',
      description: '',
      calories: kcal,
      protein: 28.5,
      carbs: 62,
      fat: 12,
      fiber: 3.2,
      sugar: 4.1,
      sodium: 800,
      healthScore: 8,
      healthBenefits: const [],
      healthWarnings: const [],
      servingSize: '1 bowl',
      imagePath: '',
      analyzedAt: DateTime(2026, 8, 10, hour, minute),
      source: 'verified',
    );

Future<void> pump(WidgetTester tester, Widget child) => tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: child,
          ),
        ),
      ),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;
  SharedPreferences.setMockInitialValues({});

  group('SkDayTimeline.gapLabel', () {
    test('reports the longest gap and the meal it follows', () {
      final label = SkDayTimeline.gapLabel([
        meal(hour: 7, minute: 40),
        meal(hour: 12, minute: 15),
        meal(hour: 19, minute: 5),
      ]);
      expect(label, '6h 50m gap after 12:15');
    });

    test('measures from 06:00 when the first meal is the widest gap', () {
      expect(SkDayTimeline.gapLabel([meal(hour: 19, minute: 0)]),
          '13h 0m gap after waking');
    });

    test('has a no-meal fallback', () {
      expect(SkDayTimeline.gapLabel([]), 'No meals yet');
    });
  });

  group('layout', () {
    testWidgets('day timeline lays out without overflow', (tester) async {
      await pump(
        tester,
        SkDayTimeline(
          meals: [
            meal(hour: 6, minute: 5, kcal: 120),
            meal(hour: 12, minute: 15, kcal: 720),
            meal(hour: 21, minute: 55, kcal: 2000),
          ],
          themeProvider: ThemeProvider(),
          isDarkMode: false,
        ),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('line chart paints an all-zero week', (tester) async {
      await pump(
        tester,
        SkLineChart(
          values: List.filled(7, 0),
          previousValues: List.filled(7, 0),
          labels: const ['M', 'T', 'W', 'T', 'F', 'S', 'S'],
          format: (v) => v.toStringAsFixed(0),
          lineColor: AppColors.skInkLight,
          dotColor: AppColors.skAccentLight,
          gridColor: AppColors.skRuleSoftLight,
          faintColor: AppColors.skFaintLight,
          labelStyle: const TextStyle(fontSize: 12),
          valueStyle: const TextStyle(fontSize: 11),
          noteStyle: const TextStyle(fontSize: 11),
        ),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('torn divider paints', (tester) async {
      await pump(tester, const SkTornDivider(color: AppColors.skRuleLight));
      expect(tester.takeException(), isNull);
    });
  });
}
