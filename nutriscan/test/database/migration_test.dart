import 'package:flutter_test/flutter_test.dart';
import 'package:nutriscan/services/database/database_helper.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

// Verifies docs/plan.md Phase 2 V2.1/V2.6: a pre-existing v1 install (no
// portion_grams/source/fkb_food_id/match_score/model_id/prompt_version
// columns) upgrades cleanly and old rows read back as 'estimated', not null
// or a crash.
void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('opening a real v1 database applies the v2 migration and backfills source', () async {
    final path = join(await databaseFactory.getDatabasesPath(), 'calories.db');
    await databaseFactory.deleteDatabase(path);

    // Recreate exactly the pre-Phase-2 schema and seed one legacy row.
    final legacyDb = await databaseFactory.openDatabase(path);
    await legacyDb.execute('''
      CREATE TABLE foods(
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        description TEXT,
        calories REAL NOT NULL,
        protein REAL NOT NULL,
        carbs REAL NOT NULL,
        fat REAL NOT NULL,
        fiber REAL NOT NULL,
        sugar REAL NOT NULL,
        sodium REAL NOT NULL,
        health_score INTEGER NOT NULL,
        health_benefits TEXT,
        health_warnings TEXT,
        serving_size TEXT,
        image_path TEXT,
        analyzed_at TEXT NOT NULL
      )
    ''');
    await legacyDb.insert('foods', {
      'id': 'legacy-1',
      'name': 'Pre-Phase-2 scan',
      'description': '',
      'calories': 250,
      'protein': 10,
      'carbs': 30,
      'fat': 5,
      'fiber': 2,
      'sugar': 3,
      'sodium': 100,
      'health_score': 6,
      'health_benefits': '',
      'health_warnings': '',
      'serving_size': '1 serving',
      'image_path': '',
      'analyzed_at': DateTime.utc(2025, 1, 1).toIso8601String(),
    });
    await legacyDb.setVersion(1);
    await legacyDb.close();

    // DatabaseHelper opens at version 2 -> sqflite invokes onUpgrade(1, 2).
    final upgraded = await DatabaseHelper().database;
    expect(await upgraded.getVersion(), 2);

    final columns = await upgraded.rawQuery('PRAGMA table_info(foods)');
    final columnNames = columns.map((c) => c['name'] as String).toSet();
    expect(
      columnNames.containsAll([
        'portion_grams',
        'source',
        'fkb_food_id',
        'match_score',
        'model_id',
        'prompt_version',
      ]),
      isTrue,
    );

    final rows = await upgraded.query('foods', where: 'id = ?', whereArgs: ['legacy-1']);
    expect(rows, hasLength(1));
    expect(rows.first['source'], 'estimated');
    expect(rows.first['portion_grams'], isNull);
  });
}
