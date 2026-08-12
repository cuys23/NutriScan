import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:nutriscan/config/api_config.dart';
import 'package:nutriscan/config/app_localizations.dart';
import 'package:nutriscan/config/feature_flags.dart';
import 'package:nutriscan/models/food.dart';
import 'package:nutriscan/providers/ads/admob_provider.dart';
import 'package:nutriscan/providers/coins/coin_provider.dart';
import 'package:nutriscan/providers/notifications/notification_provider.dart';
import 'package:nutriscan/providers/payment/subscription_provider.dart';
import 'package:nutriscan/services/ai/vision_ai_service.dart';
import 'package:nutriscan/services/database/database_helper.dart';
import 'package:nutriscan/services/fkb/match_service.dart';
import 'package:nutriscan/services/storage/firebase_storage_service.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FoodProvider with ChangeNotifier {
  List<Food> _foods = [];
  bool _isLoading = false;
  String? _error;

  // docs/plan.md Phase 7A — a multi-item scan is held here for user review
  // (keep/drop items) instead of being saved immediately. Null when there is
  // nothing pending. A single-item scan never touches this — it still saves
  // immediately, unchanged from before 7A.
  List<Food>? _pendingMultiFoodCandidates;
  String _pendingLanguage = 'en';
  bool _pendingIsPremiumUser = false;
  // Tracked separately from _pendingIsPremiumUser (which reflects the
  // caller-supplied isPremiumUser param, used for upload/insert decisions):
  // this is the actual outcome of the coin-provider spend for this pending
  // scan, so cancelMultiFoodSelection() refunds exactly when a coin was
  // really taken — regardless of whether the two ever disagree.
  bool _pendingCoinsSpent = false;
  final VisionAiService _visionAiService = VisionAiService();
  final DatabaseHelper _databaseHelper = DatabaseHelper();
  final FirebaseStorageService _storageService = FirebaseStorageService();
  final MatchService _matchService = MatchService();
  AdMobProvider? _admobProvider;
  SubscriptionProvider? _subscriptionProvider;
  CoinProvider? _coinProvider;
  NotificationProvider? _notificationProvider;

  static const bool _allowFirebaseUpload = true;

  List<Food> get foods => _foods;

  bool get isLoading => _isLoading;

  String? get error => _error;

  /// Items awaiting user review from a multi-food scan (docs/plan.md Phase
  /// 7A), or null if there's nothing pending.
  List<Food>? get pendingMultiFoodCandidates => _pendingMultiFoodCandidates;

  void setAdMobProvider(AdMobProvider admobProvider) {
    _admobProvider = admobProvider;
  }

  void setSubscriptionProvider(SubscriptionProvider subscriptionProvider) {
    _subscriptionProvider = subscriptionProvider;
  }

  void setCoinProvider(CoinProvider coinProvider) {
    _coinProvider = coinProvider;
  }

  void setNotificationProvider(NotificationProvider notificationProvider) {
    _notificationProvider = notificationProvider;
  }

  Future<String> _copyImageToLocalStorage(File imageFile, String foodId) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final imagesDir = Directory(path.join(appDir.path, 'food_images'));

      if (!await imagesDir.exists()) {
        await imagesDir.create(recursive: true);
      }

      final fileName =
          '${foodId}_${DateTime.now().millisecondsSinceEpoch}${path.extension(imageFile.path)}';
      final localPath = path.join(imagesDir.path, fileName);

      await imageFile.copy(localPath);

      if (!await File(localPath).exists()) {
        debugPrint(
          'Error copying image to local storage: copy reported success '
          'but "$localPath" does not exist afterward',
        );
        return imageFile.path;
      }

      return localPath;
    } catch (e) {
      debugPrint('Error copying image to local storage: $e');
      return imageFile.path;
    }
  }

  Future<void> initialize() async {
    try {
      await loadFoods();
    } catch (e) {
      debugPrint('Error during food provider initialization: $e');
    }
  }

  Future<void> loadFoods() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _foods = await _databaseHelper.getAllFoods();
      _error = null;
    } catch (e) {
      debugPrint('Error loading foods: $e');
      _error = 'Failed to load foods';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Calls the FKB matcher and returns [food] with macros overridden to
  /// FKB per_100g × grams and `source: verified` on a confident hit, or
  /// `source: estimated` (AI macros unchanged) otherwise. Never throws —
  /// a matcher outage must not fail the whole scan (docs/plan.md Phase 1C).
  Future<Food> _resolveFoodSource(Food food, String language) async {
    if (!FeatureFlags().fkbMatcherEnabled) {
      return food.copyWith(source: 'estimated');
    }

    final match = await _matchService.match(
      foodName: food.name,
      portionGrams: food.portionGrams,
      aiNutrients: {
        'calories_kcal': food.calories,
        'protein_g': food.protein,
        'carbs_g': food.carbs,
        'fat_g': food.fat,
        'fiber_g': food.fiber,
        'sugar_g': food.sugar,
        'sodium_mg': food.sodium,
      },
      locale: language,
      modelId: FeatureFlags().aiModelVision,
      promptVersion: ApiConfig.scanPromptVersion,
    );

    if (match == null || !match.isVerified) {
      return food.copyWith(source: 'estimated');
    }

    final n = match.nutrientsTotal;
    return food.copyWith(
      calories: (n['calories_kcal'] as num?)?.toDouble(),
      protein: (n['protein_g'] as num?)?.toDouble(),
      carbs: (n['carbs_g'] as num?)?.toDouble(),
      fat: (n['fat_g'] as num?)?.toDouble(),
      fiber: (n['fiber_g'] as num?)?.toDouble(),
      sugar: (n['sugar_g'] as num?)?.toDouble(),
      sodium: (n['sodium_mg'] as num?)?.toDouble(),
      source: 'verified',
      fkbFoodId: match.foodId,
      matchScore: match.matchScore,
    );
  }

  /// Pure parsing step of docs/plan.md Phase 7A: turns one AI response into
  /// a list of item maps regardless of scan mode, so the rest of
  /// [analyzeFoodImage] never branches on `multiFood` again.
  ///
  /// - `multiFood: false`, or the model didn't return an `items` list even
  ///   though it was asked to: treated as a single item — [analysisResult]
  ///   itself — identical to the pre-7A behavior.
  /// - `multiFood: true` with a valid `items` list: capped to 8 (a
  ///   hallucinated 20-item list is a UX/cost problem, not a real plate).
  /// - Any item without a non-empty `food_name` is dropped in both modes —
  ///   matches the old single-item validation that used to live inline here.
  @visibleForTesting
  static List<Map<String, dynamic>> normalizeScanItems(
    Map<String, dynamic> analysisResult, {
    required bool multiFood,
  }) {
    List<dynamic> items;
    if (multiFood && analysisResult['items'] is List) {
      items = analysisResult['items'] as List;
      if (items.length > 8) items = items.sublist(0, 8);
    } else {
      items = [analysisResult];
    }
    return items
        .whereType<Map>()
        .where((it) => (it['food_name']?.toString().trim().isNotEmpty) ?? false)
        .map((it) => Map<String, dynamic>.from(it))
        .toList();
  }

  Future<void> analyzeFoodImage(
    File imageFile, {
    String language = 'en',
    bool isPremiumUser = false,
  }) async {
    // A multi-food scan is still awaiting the user's keep/drop review (or the
    // review sheet was dismissed without going through confirm/cancel — see
    // MultiFoodReviewSheet's back-button guard). Starting a new scan here
    // would silently overwrite _pendingMultiFoodCandidates and discard
    // results the user already paid a coin/AI call for.
    if (_pendingMultiFoodCandidates != null) {
      _error = 'PENDING_MULTI_FOOD_REVIEW';
      notifyListeners();
      return;
    }

    // Coins are the real gate, not just a UI nicety: spend up front, before
    // the AI call, so a free scan can never slip through (previously this
    // only ran after a successful scan in _finalizeScan — a user with 0
    // coins still got a full paid Groq call, and spendCoins() just failed
    // silently afterward with nothing actually blocked). Refunded below on
    // any outcome that isn't a real, useful scan.
    final bool isPremium = _subscriptionProvider?.hasPremiumFeatures == true;
    bool coinsSpent = false;
    if (!isPremium) {
      if (_coinProvider == null ||
          !await _coinProvider!.spendCoins(CoinProvider.coinsPerScan)) {
        _error = 'NOT_ENOUGH_COINS';
        notifyListeners();
        return;
      }
      coinsSpent = true;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Persist the picked photo to permanent local storage right away,
      // before the AI call below (up to 30s). The picker's source file is a
      // temp file with no lifetime guarantee across a slow network
      // round-trip; copying it up front (instead of after the AI call, as
      // this used to) removes that window entirely.
      final String localId = DateTime.now().millisecondsSinceEpoch.toString();
      final String localImagePath = await _copyImageToLocalStorage(
        imageFile,
        localId,
      );

      final bool multiFood = FeatureFlags().multiFoodScanEnabled;

      Map<String, dynamic> analysisResult = await _visionAiService
          .analyzeFoodImage(imageFile, language: language, multiFood: multiFood)
          .timeout(const Duration(seconds: 30));

      final items = FoodProvider.normalizeScanItems(
        analysisResult,
        multiFood: multiFood,
      );

      if (analysisResult['is_food'] == false || items.isEmpty) {
        if (coinsSpent) {
          await _coinProvider!.refundCoins(CoinProvider.coinsPerScan);
        }
        _error = 'NOT_FOOD_IMAGE';
        _isLoading = false;
        notifyListeners();
        return;
      }

      bool shouldUploadToFirebase =
          _allowFirebaseUpload &&
          isPremiumUser &&
          _subscriptionProvider?.hasPremiumFeatures == true;

      String? firebaseImageUrl;

      if (shouldUploadToFirebase) {
        try {
          firebaseImageUrl = await _storageService.uploadImage(
            imageFile,
            analysisResult['id'] ?? localId,
          );
        } catch (e) {
          debugPrint('Firebase image upload failed: $e');
        }
      }

      final String imagePath = (isPremiumUser && firebaseImageUrl != null)
          ? firebaseImageUrl
          : localImagePath;

      // The local copy above exists only to survive the AI round-trip
      // outliving the picker's temp file. Once the Firebase URL is the one
      // actually saved, the local copy is dead weight — clean it up instead
      // of leaking a full JPEG into food_images/ on every premium scan.
      if (imagePath == firebaseImageUrl && localImagePath != imageFile.path) {
        try {
          await File(localImagePath).delete();
        } catch (e) {
          debugPrint('Error deleting orphaned local image copy: $e');
        }
      }

      // Match items in parallel, not sequentially — up to 8 sequential FKB
      // round-trips would blow the p95 scan latency budget (MASTER_PLAN.md
      // §12.1). Safe because _resolveFoodSource never throws (fail-soft to
      // estimated on any matcher error, see Phase 1C edge cases).
      //
      // Explicit per-item id, not Food.fromJson's default: that default is
      // DateTime.now().millisecondsSinceEpoch, and every Food.fromJson call
      // below runs in the same synchronous tick (items.map is eager), so two
      // items can land on the identical millisecond. insertFood is `INSERT
      // OR REPLACE` — a same-millisecond id collision silently overwrites
      // one saved item with another. Hit this for real during Phase 7A
      // testing (a 3-item scan only produced 2 DB rows).
      final List<Food> candidates = await Future.wait(
        items.asMap().entries.map((entry) async {
          final food = Food.fromJson({
            ...entry.value,
            'id': '${localId}_${entry.key}',
            'image_path': imagePath,
          });
          return _resolveFoodSource(food, language);
        }),
      );

      if (candidates.length == 1) {
        // Unchanged single-item behavior: save immediately, no review step.
        final newFood = candidates.first;
        await _databaseHelper.insertFood(newFood, isPremiumUser: isPremiumUser);
        _foods.insert(0, newFood);
        await _finalizeScan(language);
      } else {
        // Multi-item: hold for user review (keep/drop). The coin (if any)
        // was already spent above, before the AI call — see
        // cancelMultiFoodSelection for the refund if the user keeps nothing.
        _pendingMultiFoodCandidates = candidates;
        _pendingLanguage = language;
        _pendingIsPremiumUser = isPremiumUser;
        _pendingCoinsSpent = coinsSpent;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error in analyzeFoodImage: $e');
      if (coinsSpent) {
        await _coinProvider!.refundCoins(CoinProvider.coinsPerScan);
      }
      if (e is TimeoutException) {
        _error = _visionAiService.getLocalizedErrorMessage(
          'connection_timeout',
          language,
        );
      } else {
        _error = _visionAiService.getLocalizedErrorMessage(
          'network_error_generic',
          language,
          {'message': e.toString()},
        );
      }
      notifyListeners();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Saves the items the user kept from a multi-food review (docs/plan.md
  /// Phase 7A) and runs the same one-time-per-scan side effects
  /// (notifications) that a single-item scan already ran inline. The coin
  /// was already spent up front in analyzeFoodImage — this is a flat
  /// per-scan cost, not per item, so keeping fewer items doesn't refund
  /// part of it. Passing an empty list behaves like
  /// [cancelMultiFoodSelection] — no insert, and a full refund.
  Future<void> confirmMultiFoodSelection(List<Food> selectedFoods) async {
    if (selectedFoods.isEmpty) {
      cancelMultiFoodSelection();
      return;
    }

    final language = _pendingLanguage;
    await _databaseHelper.insertFoods(
      selectedFoods,
      isPremiumUser: _pendingIsPremiumUser,
    );
    for (final food in selectedFoods) {
      _foods.insert(0, food);
    }
    _pendingMultiFoodCandidates = null;
    await _finalizeScan(language);
  }

  /// Discards a pending multi-food review with nothing saved (docs/plan.md
  /// Phase 7A edge case: user deselects everything, or backs out via
  /// MultiFoodReviewSheet's Cancel/back-button path). The coin was already
  /// spent up front in analyzeFoodImage — since nothing useful came of this
  /// scan, refund it here rather than leaving the user charged for a scan
  /// they explicitly threw away.
  Future<void> cancelMultiFoodSelection() async {
    if (_pendingCoinsSpent) {
      await _coinProvider?.refundCoins(CoinProvider.coinsPerScan);
      _pendingCoinsSpent = false;
    }
    _pendingMultiFoodCandidates = null;
    notifyListeners();
  }

  /// Side effects that must run exactly once per scan action, regardless of
  /// how many food items that scan produced: progress notifications, the
  /// nutrient-deficiency check, and ad action tracking. The coin spend now
  /// happens up front in analyzeFoodImage instead of here — see there for
  /// why (a post-success spend meant a zero-balance scan was never
  /// actually blocked).
  /// Extracted from the tail of analyzeFoodImage so a multi-item scan
  /// (confirmMultiFoodSelection) can't accidentally run it once per item.
  Future<void> _finalizeScan(String language) async {
    final todayCalories = await getTodayCalories();
    _notificationProvider?.updateDailyProgressNotification(todayCalories);

    final weeklySummary = await _databaseHelper.getWeeklySummary();
    _notificationProvider?.updateWeeklySummaryNotification(
      weeklySummary['total_foods'] as int,
      weeklySummary['avg_calories_per_day'] as double,
    );

    final currentMonthSummary = await _databaseHelper.getCurrentMonthSummary();
    final monthNumber = currentMonthSummary['month_number'] as int;
    // Language switching is disabled — the app is English-only (see
    // LanguageProvider), so this no longer needs to read a stored preference.
    const currentLanguage = 'en';
    final monthKeys = [
      'january',
      'february',
      'march',
      'april',
      'may',
      'june',
      'july',
      'august',
      'september',
      'october',
      'november',
      'december',
    ];
    final monthName = AppLocalizations.getString(
      monthKeys[monthNumber - 1],
      currentLanguage,
    );
    _notificationProvider?.updateMonthlySummaryNotification(
      currentMonthSummary['total_foods'] as int,
      monthName,
    );

    _notificationProvider?.updateLastFoodScanTime();

    await _checkAndNotifyNutrientDeficiency(language);

    _admobProvider?.incrementActionCount();

    notifyListeners();
  }

  Future<void> deleteFood(String foodId) async {
    try {
      await _databaseHelper.deleteFood(foodId);
      _foods.removeWhere((food) => food.id == foodId);
      notifyListeners();
    } catch (e) {
      debugPrint('Error deleting food: $e');
      rethrow;
    }
  }

  Future<void> clearAllFoods() async {
    try {
      await _databaseHelper.deleteAllFoods();
      _foods.clear();
      notifyListeners();
    } catch (e) {
      debugPrint('Error clearing all foods: $e');
    }
  }

  DateTime get _today => DateTime.now();

  bool _isToday(Food food) {
    return food.analyzedAt.day == _today.day &&
        food.analyzedAt.month == _today.month &&
        food.analyzedAt.year == _today.year;
  }

  List<Food> get _todayFoods => _foods.where(_isToday).toList();

  Future<double> getTodayCalories() async {
    try {
      return await _databaseHelper.getTotalCaloriesForDate(_today);
    } catch (e) {
      debugPrint('Error getting today calories: $e');
      return 0.0;
    }
  }

  Future<double> getTodayProtein() async {
    try {
      return await _databaseHelper.getTotalProteinForDate(_today);
    } catch (e) {
      debugPrint('Error getting today protein: $e');
      return 0.0;
    }
  }

  Future<double> getTodayCarbs() async {
    try {
      return await _databaseHelper.getTotalCarbsForDate(_today);
    } catch (e) {
      debugPrint('Error getting today carbs: $e');
      return 0.0;
    }
  }

  Future<double> getTodayFat() async {
    try {
      return await _databaseHelper.getTotalFatForDate(_today);
    } catch (e) {
      debugPrint('Error getting today fat: $e');
      return 0.0;
    }
  }

  Future<double> getTodayFiber() async {
    try {
      return await _databaseHelper.getTotalFiberForDate(_today);
    } catch (e) {
      debugPrint('Error getting today fiber: $e');
      return 0.0;
    }
  }

  Future<double> getTodaySugar() async {
    try {
      return await _databaseHelper.getTotalSugarForDate(_today);
    } catch (e) {
      debugPrint('Error getting today sugar: $e');
      return 0.0;
    }
  }

  Future<double> getTodayHealthScore() async {
    try {
      return await _databaseHelper.getAverageHealthScoreForDate(_today);
    } catch (e) {
      debugPrint('Error getting today health score: $e');
      return 0.0;
    }
  }

  Future<List<Food>> getTodayFoods() async {
    try {
      return await _databaseHelper.getFoodsForDate(_today);
    } catch (e) {
      debugPrint('Error getting today foods: $e');
      return [];
    }
  }

  double _getTodayNutritionValue(double Function(Food) getter) {
    return _todayFoods.fold(0.0, (sum, food) => sum + getter(food));
  }

  double getTodayCaloriesSync() =>
      _getTodayNutritionValue((food) => food.calories);

  double getTodayProteinSync() =>
      _getTodayNutritionValue((food) => food.protein);

  double getTodayCarbsSync() => _getTodayNutritionValue((food) => food.carbs);

  double getTodayFatSync() => _getTodayNutritionValue((food) => food.fat);

  double getTodayFiberSync() => _getTodayNutritionValue((food) => food.fiber);

  double getTodaySugarSync() => _getTodayNutritionValue((food) => food.sugar);

  double getTodayHealthScoreSync() {
    if (_todayFoods.isEmpty) return 0.0;
    double totalScore = _todayFoods.fold(
      0.0,
      (sum, food) => sum + food.healthScore,
    );
    return totalScore / _todayFoods.length;
  }

  List<Food> getTodayFoodsSync() => _todayFoods;

  static const double _minDailyProtein = 30;
  static const double _minDailyCarbs = 100;
  static const double _minDailyFat = 22;
  static const double _minDailyFiber = 12;

  Future<void> _checkAndNotifyNutrientDeficiency(String language) async {
    if (_notificationProvider == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final todayStr = _today.toIso8601String().split('T').first;
      final lastKey = prefs.getString('nutrient_deficiency_last');
      if (lastKey != null && lastKey.startsWith('$todayStr:')) {
        return;
      }

      final protein = await getTodayProtein();
      final carbs = await getTodayCarbs();
      final fat = await getTodayFat();
      final fiber = await getTodayFiber();

      double maxDeficit = 0;
      String? deficientNutrient;
      if (protein < _minDailyProtein) {
        final d = _minDailyProtein - protein;
        if (d > maxDeficit) {
          maxDeficit = d;
          deficientNutrient = 'protein';
        }
      }
      if (carbs < _minDailyCarbs) {
        final d = _minDailyCarbs - carbs;
        if (d > maxDeficit) {
          maxDeficit = d;
          deficientNutrient = 'carbs';
        }
      }
      if (fat < _minDailyFat) {
        final d = _minDailyFat - fat;
        if (d > maxDeficit) {
          maxDeficit = d;
          deficientNutrient = 'fat';
        }
      }
      if (fiber < _minDailyFiber) {
        final d = _minDailyFiber - fiber;
        if (d > maxDeficit) {
          maxDeficit = d;
          deficientNutrient = 'fiber';
        }
      }

      if (deficientNutrient != null) {
        await _notificationProvider!.showNutrientDeficiencyNotification(
          nutrientKey: deficientNutrient,
          language: language,
        );
        await prefs.setString(
          'nutrient_deficiency_last',
          '$todayStr:$deficientNutrient',
        );
      }
    } catch (e) {
      debugPrint('Error checking nutrient deficiency: $e');
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void reset() {
    _error = null;
    _isLoading = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _databaseHelper.close();
    super.dispose();
  }
}
