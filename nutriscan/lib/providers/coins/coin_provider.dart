import 'package:flutter/material.dart';
import 'package:nutriscan/config/ads_config.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CoinProvider extends ChangeNotifier {
  static const String _coinBalanceKey = 'coin_balance';
  static const String _totalCoinsEarnedKey = 'total_coins_earned';
  static const String _totalCoinsSpentKey = 'total_coins_spent';

  int _coinBalance = 0;
  int _totalCoinsEarned = 0;
  int _totalCoinsSpent = 0;
  SharedPreferences? _prefs;

  // Coin configuration from AdsConfig
  static int get coinsPerAd => AdsConfig.coinsPerRewardedAd;
  static int get coinsPerScan => AdsConfig.coinsPerScan;
  static int get initialCoins => AdsConfig.initialCoins;

  // Getters
  int get coinBalance => _coinBalance;
  int get totalCoinsEarned => _totalCoinsEarned;
  int get totalCoinsSpent => _totalCoinsSpent;

  CoinProvider() {
    _loadCoins();
  }

  // Reload coins from SharedPreferences (public method for external use)
  Future<void> reloadCoins() async {
    await _loadCoins();
  }

  // Load coins from SharedPreferences
  Future<void> _loadCoins() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      _coinBalance = _prefs?.getInt(_coinBalanceKey) ?? 0;
      _totalCoinsEarned = _prefs?.getInt(_totalCoinsEarnedKey) ?? 0;
      _totalCoinsSpent = _prefs?.getInt(_totalCoinsSpentKey) ?? 0;

      // Give initial coins if first time user
      if (_coinBalance == 0 &&
          _totalCoinsEarned == 0 &&
          _totalCoinsSpent == 0) {
        await addCoins(initialCoins, isInitial: true);
      }

      notifyListeners();
    } catch (e) {
      // Error loading coins
    }
  }

  // Save coins to SharedPreferences
  Future<void> _saveCoins() async {
    try {
      if (_prefs != null) {
        await _prefs!.setInt(_coinBalanceKey, _coinBalance);
        await _prefs!.setInt(_totalCoinsEarnedKey, _totalCoinsEarned);
        await _prefs!.setInt(_totalCoinsSpentKey, _totalCoinsSpent);
      } else {
        _prefs = await SharedPreferences.getInstance();
        await _prefs!.setInt(_coinBalanceKey, _coinBalance);
        await _prefs!.setInt(_totalCoinsEarnedKey, _totalCoinsEarned);
        await _prefs!.setInt(_totalCoinsSpentKey, _totalCoinsSpent);
      }
    } catch (e) {
      // Error saving coins
    }
  }

  // Add coins (from rewarded ads)
  Future<void> addCoins(int amount, {bool isInitial = false}) async {
    _coinBalance += amount;
    if (!isInitial) {
      _totalCoinsEarned += amount;
    }
    await _saveCoins();
    notifyListeners();
  }

  // Spend coins (for scanning)
  Future<bool> spendCoins(int amount) async {
    if (_coinBalance < amount) {
      return false; // Not enough coins
    }

    _coinBalance -= amount;
    _totalCoinsSpent += amount;
    await _saveCoins();
    notifyListeners();
    return true;
  }

  // Check if user has enough coins
  bool hasEnoughCoins(int amount) {
    return _coinBalance >= amount;
  }

  // Check if user can scan (has coins or other conditions)
  bool canScan() {
    return _coinBalance >= coinsPerScan;
  }

  // Get coins needed for next scan
  int getCoinsNeededForScan() {
    return coinsPerScan;
  }

  // Reset coins (for testing or admin purposes)
  Future<void> resetCoins() async {
    _coinBalance = 0;
    _totalCoinsEarned = 0;
    _totalCoinsSpent = 0;
    await _saveCoins();
    notifyListeners();
  }

  // Add bonus coins (for promotions, etc.)
  Future<void> addBonusCoins(int amount) async {
    await addCoins(amount);
  }
}
