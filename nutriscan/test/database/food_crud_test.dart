import 'package:flutter_test/flutter_test.dart';
import 'package:nutriscan/models/food.dart';
import 'package:nutriscan/services/database/database_helper.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

// Runs DatabaseHelper against the real sqlite engine (via the ffi driver,
// no platform channel needed) instead of mocking it — Food round-trips
// through actual SQL, the same as on-device.
void main() {
  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    // A stale calories.db from a previous local `flutter test` run would
    // otherwise leak rows across runs (ffi persists it on disk, unlike a
    // real device's per-install sandbox).
    final path = join(await databaseFactory.getDatabasesPath(), 'calories.db');
    await databaseFactory.deleteDatabase(path);
  });

  test('insertFood -> getAllFoods round-trips every FKB trust field', () async {
    final db = DatabaseHelper();
    final food = Food(
      id: 'crud-test-verified-1',
      name: 'Banana',
      description: 'A ripe banana.',
      calories: 105,
      protein: 1.3,
      carbs: 27,
      fat: 0.4,
      fiber: 3.1,
      sugar: 14,
      sodium: 1,
      healthScore: 8,
      healthBenefits: const ['Potassium'],
      healthWarnings: const [],
      servingSize: '1 medium banana',
      imagePath: '/tmp/banana.jpg',
      analyzedAt: DateTime.utc(2026, 1, 1),
      source: 'verified',
      portionGrams: 118,
      fkbFoodId: 'usda_173944',
      matchScore: 0.95,
    );

    await db.insertFood(food);
    final stored = (await db.getAllFoods()).firstWhere((f) => f.id == food.id);

    expect(stored.name, food.name);
    expect(stored.calories, food.calories);
    expect(stored.healthBenefits, food.healthBenefits);
    expect(stored.source, 'verified');
    expect(stored.portionGrams, 118);
    expect(stored.fkbFoodId, 'usda_173944');
    expect(stored.matchScore, 0.95);
  });

  test('estimated food round-trips with null FKB fields intact', () async {
    final db = DatabaseHelper();
    final food = Food(
      id: 'crud-test-estimated-1',
      name: 'Mystery dish',
      description: '',
      calories: 300,
      protein: 10,
      carbs: 40,
      fat: 8,
      fiber: 2,
      sugar: 5,
      sodium: 200,
      healthScore: 5,
      healthBenefits: const [],
      healthWarnings: const [],
      servingSize: '1 serving',
      imagePath: '',
      analyzedAt: DateTime.utc(2026, 1, 1),
      // source defaults to 'estimated'; portionGrams/fkbFoodId/matchScore
      // default to null — mirrors an AI-only scan with no FKB match.
    );

    await db.insertFood(food);
    final stored = (await db.getAllFoods()).firstWhere((f) => f.id == food.id);

    expect(stored.source, 'estimated');
    expect(stored.portionGrams, isNull);
    expect(stored.fkbFoodId, isNull);
    expect(stored.matchScore, isNull);
  });

  test('deleteFood removes exactly the targeted row', () async {
    final db = DatabaseHelper();
    final food = Food(
      id: 'crud-test-delete-me',
      name: 'Temp',
      description: '',
      calories: 1,
      protein: 1,
      carbs: 1,
      fat: 1,
      fiber: 1,
      sugar: 1,
      sodium: 1,
      healthScore: 1,
      healthBenefits: const [],
      healthWarnings: const [],
      servingSize: '1 serving',
      imagePath: '',
      analyzedAt: DateTime.utc(2026, 1, 1),
    );
    await db.insertFood(food);
    expect((await db.getAllFoods()).any((f) => f.id == food.id), isTrue);

    await db.deleteFood(food.id);
    expect((await db.getAllFoods()).any((f) => f.id == food.id), isFalse);
  });
}
