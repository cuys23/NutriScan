import 'package:cloud_functions/cloud_functions.dart';

/// Result of `matchFood` — mirrors functions/src/fkb/match.ts MatchFoodResult.
class MatchFoodResult {
  final String status; // 'verified' | 'estimated'
  final String? foodId;
  final double matchScore;
  final Map<String, dynamic> nutrientsTotal;
  final String sourceLabel;

  const MatchFoodResult({
    required this.status,
    required this.foodId,
    required this.matchScore,
    required this.nutrientsTotal,
    required this.sourceLabel,
  });

  bool get isVerified => status == 'verified';

  factory MatchFoodResult.fromMap(Map<String, dynamic> map) {
    return MatchFoodResult(
      status: (map['status'] ?? 'estimated').toString(),
      foodId: map['food_id']?.toString(),
      matchScore: (map['match_score'] as num?)?.toDouble() ?? 0.0,
      nutrientsTotal: map['nutrients_total'] is Map
          ? Map<String, dynamic>.from(map['nutrients_total'])
          : const {},
      sourceLabel: (map['source_label'] ?? 'AI estimate').toString(),
    );
  }
}

/// Thin client for the `matchFood` Cloud Function callable — decides
/// verified (FKB) vs estimated (AI) after a scan. See
/// functions/src/fkb/match.ts and docs/plan.md Phase 1C.
class MatchService {
  final HttpsCallable _matchCallable = FirebaseFunctions.instance
      .httpsCallable(
        'matchFood',
        options: HttpsCallableOptions(timeout: const Duration(seconds: 15)),
      );

  /// Returns null on failure — callers must fall back to `estimated` using
  /// the AI's own macros rather than block the scan on a matcher outage.
  Future<MatchFoodResult?> match({
    required String foodName,
    required double? portionGrams,
    required Map<String, dynamic> aiNutrients,
    String? locale,
    String? modelId,
    String? promptVersion,
  }) async {
    try {
      final result = await _matchCallable.call<Map<String, dynamic>>({
        'food_name': foodName,
        'portion_grams': portionGrams,
        if (locale != null) 'locale': locale,
        'ai_nutrients': aiNutrients,
        if (modelId != null) 'model_id': modelId,
        if (promptVersion != null) 'prompt_version': promptVersion,
      });
      final data = Map<String, dynamic>.from(result.data);
      final matchData = data['data'];
      if (matchData is! Map) return null;
      return MatchFoodResult.fromMap(Map<String, dynamic>.from(matchData));
    } on FirebaseFunctionsException {
      return null;
    }
  }
}
