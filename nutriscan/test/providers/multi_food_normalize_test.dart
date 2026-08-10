import 'package:flutter_test/flutter_test.dart';
import 'package:nutriscan/providers/food/food_provider.dart';

// docs/plan.md Phase 7A — pure-logic check for FoodProvider.normalizeScanItems,
// the parsing step that decides how many Food candidates a scan produces.
// No Firebase/network involved, so this runs without any mocking.
void main() {
  group('normalizeScanItems', () {
    test('multiFood=false always returns exactly the single response as one item', () {
      final result = FoodProvider.normalizeScanItems(
        {'is_food': true, 'food_name': 'Banana', 'calories': 105},
        multiFood: false,
      );
      expect(result, hasLength(1));
      expect(result.single['food_name'], 'Banana');
    });

    test('multiFood=true with a valid items list returns all items', () {
      final result = FoodProvider.normalizeScanItems(
        {
          'is_food': true,
          'items': [
            {'food_name': 'Rice', 'calories': 200},
            {'food_name': 'Chicken', 'calories': 300},
            {'food_name': 'Vegetables', 'calories': 50},
          ],
        },
        multiFood: true,
      );
      expect(result, hasLength(3));
      expect(result.map((f) => f['food_name']), ['Rice', 'Chicken', 'Vegetables']);
    });

    test('caps at 8 items even if the model returns more', () {
      final items = List.generate(20, (i) => {'food_name': 'Item $i', 'calories': 10});
      final result = FoodProvider.normalizeScanItems(
        {'is_food': true, 'items': items},
        multiFood: true,
      );
      expect(result, hasLength(8));
      expect(result.first['food_name'], 'Item 0');
      expect(result.last['food_name'], 'Item 7');
    });

    test('multiFood=true but no items list falls back to the single response (no regression)', () {
      final result = FoodProvider.normalizeScanItems(
        {'is_food': true, 'food_name': 'Banana', 'calories': 105},
        multiFood: true,
      );
      expect(result, hasLength(1));
      expect(result.single['food_name'], 'Banana');
    });

    test('drops items with a missing or blank food_name', () {
      final result = FoodProvider.normalizeScanItems(
        {
          'is_food': true,
          'items': [
            {'food_name': 'Rice', 'calories': 200},
            {'food_name': '  ', 'calories': 0},
            {'calories': 0},
          ],
        },
        multiFood: true,
      );
      expect(result, hasLength(1));
      expect(result.single['food_name'], 'Rice');
    });

    test('empty items list normalizes to an empty result (caller treats as NOT_FOOD_IMAGE)', () {
      final result = FoodProvider.normalizeScanItems(
        {'is_food': true, 'items': []},
        multiFood: true,
      );
      expect(result, isEmpty);
    });
  });
}
