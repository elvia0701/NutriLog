import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:nutrilog/database/database_helper.dart';
import 'package:nutrilog/models/food.dart';
import 'package:nutrilog/models/meal_record.dart';

void main() {
  sqfliteFfiInit();

  late DatabaseHelper databaseHelper;

  setUp(() {
    databaseHelper = DatabaseHelper.forTesting(databaseFactoryFfi);
  });

  tearDown(() async {
    await databaseHelper.close();
  });

  test('unused food can be deleted', () async {
    final foodId = await databaseHelper.insertFood(
      Food(name: '未使用食物', calories: 100, protein: 5),
    );

    final result = await databaseHelper.removeFood(foodId);

    expect(result, FoodRemovalResult.deleted);
    expect(await databaseHelper.getFoods(), isEmpty);
  });

  test('referenced food is archived and its meal record is retained', () async {
    final foodId = await databaseHelper.insertFood(
      Food(name: '已使用食物', calories: 200, protein: 10),
    );
    await databaseHelper.insertMealRecord(
      MealRecord(
        date: '2026-07-20',
        mealType: 'lunch',
        foodId: foodId,
        servings: 1,
      ),
    );

    final result = await databaseHelper.removeFood(foodId);

    expect(result, FoodRemovalResult.archived);
    expect(await databaseHelper.getFoods(), isEmpty);
    expect(await databaseHelper.getAllMealRecords(), hasLength(1));

    final db = await databaseHelper.database;
    final archivedFood = await db.query(
      'foods',
      where: 'id = ?',
      whereArgs: [foodId],
    );
    expect(archivedFood.single['is_archived'], 1);

    final historicalItems = await databaseHelper.getMealItemsByDateAndMealType(
      '2026-07-20',
      'lunch',
    );
    expect(historicalItems, hasLength(1));
    expect(historicalItems.single.foodName, '已使用食物');
  });

  test('version 2 database migrates without losing food or meals', () async {
    final tempDirectory = await Directory.systemTemp.createTemp(
      'nutrilog_migration_',
    );
    final databasePath = path.join(tempDirectory.path, 'health_app.db');

    final version2Database = await databaseFactoryFfi.openDatabase(
      databasePath,
      options: OpenDatabaseOptions(
        version: 2,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE foods (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              name TEXT NOT NULL,
              calories INTEGER NOT NULL,
              protein REAL NOT NULL,
              carbs REAL NOT NULL DEFAULT 0,
              fat REAL NOT NULL DEFAULT 0,
              favorite INTEGER NOT NULL DEFAULT 0
            )
          ''');
          await db.execute('''
            CREATE TABLE meal_records (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              date TEXT NOT NULL,
              meal_type TEXT NOT NULL,
              food_id INTEGER NOT NULL,
              servings REAL NOT NULL DEFAULT 1,
              FOREIGN KEY (food_id) REFERENCES foods (id)
            )
          ''');
        },
      ),
    );
    final foodId = await version2Database.insert('foods', {
      'name': '舊版食物',
      'calories': 150,
      'protein': 7.5,
    });
    await version2Database.insert('meal_records', {
      'date': '2026-07-13',
      'meal_type': 'breakfast',
      'food_id': foodId,
      'servings': 1.5,
    });
    await version2Database.close();

    final migratedDatabase = DatabaseHelper.forTesting(
      databaseFactoryFfi,
      databasePath: databasePath,
    );
    final db = await migratedDatabase.database;

    expect(await db.getVersion(), DatabaseHelper.databaseVersion);
    final columns = await db.rawQuery('PRAGMA table_info(foods)');
    expect(columns.map((column) => column['name']), contains('is_archived'));
    expect(await migratedDatabase.getFoods(), hasLength(1));
    expect(await migratedDatabase.getAllMealRecords(), hasLength(1));

    await migratedDatabase.close();
    await tempDirectory.delete(recursive: true);
  });
}
