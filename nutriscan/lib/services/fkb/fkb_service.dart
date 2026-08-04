import 'package:cloud_functions/cloud_functions.dart';
import 'package:nutriscan/models/fkb_food.dart';

/// Thin client for the `fkbSearch` / `fkbGet` Cloud Functions callables.
/// No USDA key or Firestore access on the client — all FKB reads go through
/// these authenticated callables (see functions/src/index.ts).
class FkbService {
  final HttpsCallable _searchCallable = FirebaseFunctions.instance
      .httpsCallable(
        'fkbSearch',
        options: HttpsCallableOptions(timeout: const Duration(seconds: 15)),
      );

  final HttpsCallable _getCallable = FirebaseFunctions.instance.httpsCallable(
    'fkbGet',
    options: HttpsCallableOptions(timeout: const Duration(seconds: 15)),
  );

  /// Searches verified foods by name/alias. Returns an empty list on any
  /// failure (search is an assist, not a hard dependency for the caller).
  Future<List<FkbFoodSummary>> search(
    String query, {
    String? locale,
    int limit = 10,
  }) async {
    try {
      final result = await _searchCallable.call<Map<String, dynamic>>({
        'query': query,
        if (locale != null) 'locale': locale,
        'limit': limit,
      });
      final data = Map<String, dynamic>.from(result.data);
      final items = (data['data']?['items'] as List?) ?? const [];
      return items
          .map((item) => FkbFoodSummary.fromMap(Map<String, dynamic>.from(item)))
          .toList();
    } on FirebaseFunctionsException {
      return [];
    }
  }

  /// Fetches a single verified food by `food_id`. Returns null if it does
  /// not exist or the call fails.
  Future<FkbFood?> get(String foodId) async {
    try {
      final result = await _getCallable.call<Map<String, dynamic>>({
        'food_id': foodId,
      });
      final data = Map<String, dynamic>.from(result.data);
      final food = data['data'];
      if (food is! Map) return null;
      return FkbFood.fromMap(Map<String, dynamic>.from(food));
    } on FirebaseFunctionsException {
      return null;
    }
  }
}
