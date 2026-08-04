import 'package:flutter/foundation.dart';

/// Canonical per-100g nutrients, matching functions/src/fkb/types.ts
/// NutrientsPer100g. Keys are fixed everywhere — see docs/MASTER_PLAN.md §7.2.
@immutable
class FkbNutrientsPer100g {
  final double caloriesKcal;
  final double proteinG;
  final double carbsG;
  final double fatG;
  final double fiberG;
  final double sugarG;
  final double sodiumMg;

  const FkbNutrientsPer100g({
    required this.caloriesKcal,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
    required this.fiberG,
    required this.sugarG,
    required this.sodiumMg,
  });

  factory FkbNutrientsPer100g.fromMap(Map<String, dynamic> map) {
    return FkbNutrientsPer100g(
      caloriesKcal: _parseDouble(map['calories_kcal']),
      proteinG: _parseDouble(map['protein_g']),
      carbsG: _parseDouble(map['carbs_g']),
      fatG: _parseDouble(map['fat_g']),
      fiberG: _parseDouble(map['fiber_g']),
      sugarG: _parseDouble(map['sugar_g']),
      sodiumMg: _parseDouble(map['sodium_mg']),
    );
  }

  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0.0;
  }
}

/// A single `fkbSearch` result — the summary shape returned by the
/// callable, not the full FKB document (see [FkbFood]).
@immutable
class FkbFoodSummary {
  final String foodId;
  final String nameEn;
  final String nameVi;
  final double score;
  final FkbNutrientsPer100g nutrientsPer100g;
  final String source;
  final String sourceRef;

  const FkbFoodSummary({
    required this.foodId,
    required this.nameEn,
    required this.nameVi,
    required this.score,
    required this.nutrientsPer100g,
    required this.source,
    required this.sourceRef,
  });

  factory FkbFoodSummary.fromMap(Map<String, dynamic> map) {
    return FkbFoodSummary(
      foodId: (map['food_id'] ?? '').toString(),
      nameEn: (map['name_en'] ?? '').toString(),
      nameVi: (map['name_vi'] ?? '').toString(),
      score: FkbNutrientsPer100g._parseDouble(map['score']),
      nutrientsPer100g: FkbNutrientsPer100g.fromMap(
        map['nutrients_per_100g'] is Map
            ? Map<String, dynamic>.from(map['nutrients_per_100g'])
            : <String, dynamic>{},
      ),
      source: (map['source'] ?? '').toString(),
      sourceRef: (map['source_ref'] ?? '').toString(),
    );
  }
}

/// Full `fkbGet` result — one verified food entry.
@immutable
class FkbFood {
  final String foodId;
  final String nameEn;
  final String nameVi;
  final List<String> aliases;
  final FkbNutrientsPer100g nutrientsPer100g;
  final String source;
  final String sourceRef;
  final String? dataType;
  final String verifiedAt;
  final String? verifiedBy;

  const FkbFood({
    required this.foodId,
    required this.nameEn,
    required this.nameVi,
    required this.aliases,
    required this.nutrientsPer100g,
    required this.source,
    required this.sourceRef,
    this.dataType,
    required this.verifiedAt,
    this.verifiedBy,
  });

  factory FkbFood.fromMap(Map<String, dynamic> map) {
    return FkbFood(
      foodId: (map['food_id'] ?? '').toString(),
      nameEn: (map['name_en'] ?? '').toString(),
      nameVi: (map['name_vi'] ?? '').toString(),
      aliases: map['aliases'] is List
          ? List<String>.from(map['aliases'].map((e) => e.toString()))
          : const [],
      nutrientsPer100g: FkbNutrientsPer100g.fromMap(
        map['nutrients_per_100g'] is Map
            ? Map<String, dynamic>.from(map['nutrients_per_100g'])
            : <String, dynamic>{},
      ),
      source: (map['source'] ?? '').toString(),
      sourceRef: (map['source_ref'] ?? '').toString(),
      dataType: map['data_type']?.toString(),
      verifiedAt: (map['verified_at'] ?? '').toString(),
      verifiedBy: map['verified_by']?.toString(),
    );
  }
}
