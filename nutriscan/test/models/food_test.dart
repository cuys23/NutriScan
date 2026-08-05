import 'package:flutter_test/flutter_test.dart';
import 'package:nutriscan/models/food.dart';

void main() {
  group('Food.fromJson / toJson round trip', () {
    test('preserves verified-scan fields through a full round trip', () {
      final original = Food.fromJson({
        'food_name': 'Banana',
        'description': 'A ripe banana.',
        'calories': 105,
        'protein': 1.3,
        'carbs': 27,
        'fat': 0.4,
        'fiber': 3.1,
        'sugar': 14,
        'sodium': 1,
        'healthScore': 8,
        'health_benefits': ['Potassium'],
        'health_warnings': [],
        'serving_size': '1 medium banana',
        'image_path': '/tmp/banana.jpg',
        'source': 'verified',
        'portion_grams': 118,
        'fkb_food_id': 'usda_173944',
        'match_score': 0.95,
      });

      expect(original.source, 'verified');
      expect(original.portionGrams, 118);
      expect(original.fkbFoodId, 'usda_173944');
      expect(original.matchScore, 0.95);

      final json = original.toJson();
      // toJson uses id/analyzed_at generated at construction time, not
      // present in the source map — round trip through fromJson again to
      // confirm every FKB trust field survives a second parse unchanged.
      final roundTripped = Food.fromJson(json);

      expect(roundTripped.name, original.name);
      expect(roundTripped.calories, original.calories);
      expect(roundTripped.source, original.source);
      expect(roundTripped.portionGrams, original.portionGrams);
      expect(roundTripped.fkbFoodId, original.fkbFoodId);
      expect(roundTripped.matchScore, original.matchScore);
    });

    test('defaults source to estimated and leaves FKB fields null when absent', () {
      final food = Food.fromJson({
        'food_name': 'Mystery dish',
        'calories': 300,
        'protein': 10,
        'carbs': 40,
        'fat': 8,
        'fiber': 2,
        'sugar': 5,
        'sodium': 200,
      });

      expect(food.source, 'estimated');
      expect(food.portionGrams, isNull);
      expect(food.fkbFoodId, isNull);
      expect(food.matchScore, isNull);
    });

    test('never fabricates a portion_grams value — null stays null through toJson', () {
      final food = Food.fromJson({'food_name': 'No portion info'});
      expect(food.portionGrams, isNull);
      expect(food.toJson()['portion_grams'], isNull);
    });
  });

  group('Food.copyWith', () {
    test('overrides only the given fields', () {
      final original = Food.fromJson({
        'food_name': 'Rice',
        'calories': 130,
        'source': 'estimated',
      });

      final edited = original.copyWith(source: 'user_edited', calories: 140);

      expect(edited.source, 'user_edited');
      expect(edited.calories, 140);
      expect(edited.name, original.name); // unchanged fields carried over
    });
  });
}
