import 'package:flutter/foundation.dart';

import 'package:nutriscan/models/meal_plan.dart';
import 'package:nutriscan/services/ai/groq_service.dart';
import 'package:nutriscan/services/database/database_helper.dart';

class UserNutritionInsight {
  final String suggestedDietStyle;
  final String balanceContextForPrompt;
  final bool hasData;

  const UserNutritionInsight({
    required this.suggestedDietStyle,
    required this.balanceContextForPrompt,
    required this.hasData,
  });
}

class MealPlanProvider extends ChangeNotifier {
  MealPlanProvider({GroqService? groqService, DatabaseHelper? databaseHelper})
    : _groqService = groqService ?? GroqService(),
      _databaseHelper = databaseHelper ?? DatabaseHelper();

  final GroqService _groqService;
  final DatabaseHelper _databaseHelper;

  MealPlan? _currentPlan;
  MealPlan? _activePlan; // Loaded from local DB — shown on home screen.
  bool _isLoading = false;
  String? _errorMessage;

  // Nothing stopped a user from spam-tapping generate/refresh; each tap fires
  // a real Groq request (plus an internal repair-prompt retry on bad JSON),
  // which was enough on its own to trip Groq's rate limit. Ad flows in this
  // app already use a cooldown for the same reason (see AdsConfig) — mirror
  // that here rather than only fixing the retry path.
  static const Duration generateCooldown = Duration(seconds: 15);
  DateTime? _lastGenerateAttempt;

  double _calorieTarget = 2000;
  String _dietStyle = 'balanced';
  int _mealsPerDay = 4;
  final List<String> _restrictions = [];

  UserNutritionInsight? _lastInsight;

  MealPlan? get currentPlan => _currentPlan;
  MealPlan? get activePlan => _activePlan;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  UserNutritionInsight? get lastInsight => _lastInsight;

  double get calorieTarget => _calorieTarget;
  String get dietStyle => _dietStyle;
  int get mealsPerDay => _mealsPerDay;
  List<String> get restrictions => List.unmodifiable(_restrictions);

  /// Load the most recent active meal plan from the local database.
  /// Call once at app startup (e.g. from HomeScreen._initializeData).
  Future<void> loadActiveMealPlan() async {
    try {
      _activePlan = await _databaseHelper.getActiveMealPlan();
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to load active meal plan: $e');
    }
  }

  /// Copies the persisted active plan into [currentPlan] so
  /// MealPlanResultScreen (which reads currentPlan) can display it.
  /// Call before navigating to the result screen from the home card.
  void showActivePlan() {
    if (_activePlan != null) {
      _currentPlan = _activePlan;
      _errorMessage = null;
      notifyListeners();
    }
  }

  /// Dismiss the active meal plan from the home screen.
  Future<void> dismissMealPlan() async {
    _activePlan = null;
    notifyListeners();
    try {
      await _databaseHelper.deactivateActiveMealPlan();
    } catch (e) {
      debugPrint('Failed to deactivate meal plan: $e');
    }
  }

  void setCalorieTarget(double value) {
    _calorieTarget = value.clamp(1200, 3500);
    notifyListeners();
  }

  void setDietStyle(String style) {
    if (_dietStyle == style) return;
    _dietStyle = style;
    notifyListeners();
  }

  void setMealsPerDay(int count) {
    if (count < 3 || count > 6) return;
    if (_mealsPerDay == count) return;
    _mealsPerDay = count;
    notifyListeners();
  }

  void toggleRestriction(String restriction) {
    if (_restrictions.contains(restriction)) {
      _restrictions.remove(restriction);
    } else {
      _restrictions.add(restriction);
    }
    notifyListeners();
  }

  void setRestrictionsFromText(String text) {
    _restrictions
      ..clear()
      ..addAll(
        text
            .split(',')
            .map((item) => item.trim())
            .where((item) => item.isNotEmpty)
            .toSet(),
      );
    notifyListeners();
  }

  void clearPlan() {
    _currentPlan = null;
    _errorMessage = null;
    notifyListeners();
  }

  static const int _analysisDays = 14;
  static const double _minProteinPerDay = 45;
  static const double _minFiberPerDay = 18;
  static const double _highFatPerDay = 75;

  Future<UserNutritionInsight> analyzeUserNutrition() async {
    try {
      final summary = await _databaseHelper.getNutritionSummaryForLastDays(
        _analysisDays,
      );
      final totalMeals = summary['total_meals'] as int? ?? 0;
      if (totalMeals < 3) {
        _lastInsight = const UserNutritionInsight(
          suggestedDietStyle: 'balanced',
          balanceContextForPrompt: '',
          hasData: false,
        );
        notifyListeners();
        return _lastInsight!;
      }

      final avgProtein =
          (summary['avg_protein_per_day'] as num?)?.toDouble() ?? 0.0;
      final avgFat = (summary['avg_fat_per_day'] as num?)?.toDouble() ?? 0.0;
      final avgFiber =
          (summary['avg_fiber_per_day'] as num?)?.toDouble() ?? 0.0;
      final avgCalories =
          (summary['avg_calories_per_day'] as num?)?.toDouble() ?? 0.0;

      String suggested = 'balanced';
      final List<String> gaps = [];

      if (avgProtein < _minProteinPerDay) {
        suggested = 'high_protein';
        gaps.add('low protein (avg ${avgProtein.toStringAsFixed(0)}g/day)');
      }
      if (avgFiber < _minFiberPerDay && suggested == 'balanced') {
        suggested = 'vegetarian';
        gaps.add('low fiber (avg ${avgFiber.toStringAsFixed(0)}g/day)');
      }
      if (avgFat > _highFatPerDay && suggested == 'balanced') {
        suggested = 'low_carb';
        gaps.add('high fat intake (avg ${avgFat.toStringAsFixed(0)}g/day)');
      }

      final recentFoods = await _databaseHelper.getFoodsForLastWeek();
      final foodCounts = <String, int>{};
      for (final food in recentFoods) {
        foodCounts[food.name] = (foodCounts[food.name] ?? 0) + 1;
      }
      final topFoods = (foodCounts.entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value)))
          .take(5)
          .map((e) => e.key)
          .toList();

      final avgCarbs = (summary['avg_carbs_per_day'] as num?)?.toDouble() ?? 0.0;

      String contextForPrompt =
          "User's recent diet (last $_analysisDays days) averages "
          "${avgCalories.toStringAsFixed(0)} kcal, ${avgProtein.toStringAsFixed(0)}g protein, "
          "${avgCarbs.toStringAsFixed(0)}g carbs, ${avgFat.toStringAsFixed(0)}g fat, "
          "${avgFiber.toStringAsFixed(0)}g fiber per day.";
      if (gaps.isNotEmpty) {
        contextForPrompt +=
            " Gaps: ${gaps.join('; ')}. Create a plan that helps balance their diet and address these needs.";
      } else {
        contextForPrompt += " This is relatively balanced; create a varied plan that maintains balance.";
      }
      if (topFoods.isNotEmpty) {
        contextForPrompt += " Frequently logged foods: ${topFoods.join(', ')}.";
      }

      _lastInsight = UserNutritionInsight(
        suggestedDietStyle: suggested,
        balanceContextForPrompt: contextForPrompt,
        hasData: true,
      );
      notifyListeners();
      return _lastInsight!;
    } catch (e) {
      _lastInsight = const UserNutritionInsight(
        suggestedDietStyle: 'balanced',
        balanceContextForPrompt: '',
        hasData: false,
      );
      notifyListeners();
      return _lastInsight!;
    }
  }

  void applySuggestedDietStyle() {
    if (_lastInsight != null && _lastInsight!.hasData) {
      _dietStyle = _lastInsight!.suggestedDietStyle;
      notifyListeners();
    }
  }

  /// Time left before another [generateMealPlan] call is allowed, or null if
  /// the cooldown has already elapsed.
  Duration? get generateCooldownRemaining {
    if (_lastGenerateAttempt == null) return null;
    final elapsed = DateTime.now().difference(_lastGenerateAttempt!);
    if (elapsed >= generateCooldown) return null;
    return generateCooldown - elapsed;
  }

  /// Localized "please wait" message for a cooldown-blocked attempt — shown
  /// as a transient snackbar by the caller rather than through
  /// [errorMessage], so a plan already on screen doesn't get replaced by an
  /// error state just because the user tapped refresh twice.
  String cooldownMessage(String languageCode) =>
      _groqService.getLocalizedErrorMessage('rate_limit', languageCode);

  /// Generates a new plan. Returns false without touching any state
  /// (loading, errorMessage, currentPlan) if still within
  /// [generateCooldownRemaining] — callers should show [cooldownMessage]
  /// themselves in that case. Returns true once a real attempt has run
  /// (success or failure both surface through [errorMessage] as before).
  Future<bool> generateMealPlan({required String languageCode}) async {
    if (generateCooldownRemaining != null) {
      return false;
    }
    _lastGenerateAttempt = DateTime.now();

    _setLoading(true);
    try {
      String? userContext;
      if (_lastInsight != null &&
          _lastInsight!.hasData &&
          _lastInsight!.balanceContextForPrompt.isNotEmpty) {
        userContext = _lastInsight!.balanceContextForPrompt;
      }

      final result = await _groqService.generateMealPlan(
        targetCalories: _calorieTarget.round(),
        dietStyle: _dietStyle,
        mealsPerDay: _mealsPerDay,
        restrictions: _restrictions,
        language: languageCode,
        userNutritionContext: userContext,
      );

      _currentPlan = result;
      _activePlan = result;
      _errorMessage = null;

      // Persist to local DB so it survives app restarts.
      try {
        await _databaseHelper.saveMealPlan(
          result,
          targetCalories: _calorieTarget,
          dietStyle: _dietStyle,
          mealsPerDay: _mealsPerDay,
        );
      } catch (e) {
        debugPrint('Failed to save meal plan to DB: $e');
      }
    } catch (error) {
      _errorMessage = error.toString();
      _currentPlan = null;
    } finally {
      _setLoading(false);
    }
    return true;
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}
