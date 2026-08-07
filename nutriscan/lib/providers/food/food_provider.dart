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
import 'package:nutriscan/services/ai/groq_service.dart';
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
  final GroqService _groqService = GroqService();
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
      modelId: FeatureFlags().aiModelScan,
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

  Future<void> analyzeFoodImage(
    File imageFile, {
    String language = 'en',
    bool isPremiumUser = false,
  }) async {
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

      Map<String, dynamic> analysisResult = await _groqService
          .analyzeFoodImage(imageFile, language: language)
          .timeout(const Duration(seconds: 30));

      if (analysisResult['is_food'] == false ||
          analysisResult['food_name'] == null ||
          analysisResult['food_name'].toString().trim().isEmpty) {
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

      Food newFood = Food.fromJson({
        ...analysisResult,
        'image_path': imagePath,
      });

      newFood = await _resolveFoodSource(newFood, language);

      await _databaseHelper.insertFood(newFood, isPremiumUser: isPremiumUser);

      _foods.insert(0, newFood);

      final todayCalories = await getTodayCalories();
      _notificationProvider?.updateDailyProgressNotification(todayCalories);

      final weeklySummary = await _databaseHelper.getWeeklySummary();
      _notificationProvider?.updateWeeklySummaryNotification(
        weeklySummary['total_foods'] as int,
        weeklySummary['avg_calories_per_day'] as double,
      );

      final currentMonthSummary = await _databaseHelper
          .getCurrentMonthSummary();
      final monthNumber = currentMonthSummary['month_number'] as int;
      final prefs = await SharedPreferences.getInstance();
      final currentLanguage = prefs.getString('selected_language') ?? 'en';
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

      if (_subscriptionProvider != null &&
          !_subscriptionProvider!.hasPremiumFeatures &&
          _coinProvider != null) {
        await _coinProvider!.spendCoins(CoinProvider.coinsPerScan);
      }

      notifyListeners();
    } catch (e) {
      debugPrint('Error in analyzeFoodImage: $e');
      if (e is TimeoutException) {
        _error = _groqService.getLocalizedErrorMessage(
          'connection_timeout',
          language,
        );
      } else {
        _error = _groqService.getLocalizedErrorMessage(
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
