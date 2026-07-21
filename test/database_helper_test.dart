import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:nutrilog/database/database_helper.dart';
import 'package:nutrilog/models/food.dart';
import 'package:nutrilog/models/meal_record.dart';
import 'package:nutrilog/models/nutrition_goal.dart';

void main() {
  sqfliteFfiInit();

  late DatabaseHelper databaseHelper;

  setUp(() {
    databaseHelper = DatabaseHelper.forTesting(databaseFactoryFfi);
  });

  tearDown(() async {
    await databaseHelper.close();
  });

  test(
    'zero-valued food nutrients persist and produce valid meal totals',
    () async {
      final foodId = await databaseHelper.insertFood(
        Food(name: '無營養素飲品', calories: 10, protein: 1, carbs: 2, fat: 3),
      );
      await databaseHelper.updateFood(
        Food(
          id: foodId,
          name: '無營養素飲品',
          calories: 0,
          protein: 0,
          carbs: 0,
          fat: 0,
        ),
      );

      final savedFood = (await databaseHelper.getFoods()).single;
      expect(savedFood.id, foodId);
      expect(savedFood.calories, 0);
      expect(savedFood.protein, 0);
      expect(savedFood.carbs, 0);
      expect(savedFood.fat, 0);

      await databaseHelper.insertMealRecord(
        MealRecord(
          date: '2026-07-21',
          mealType: 'snack',
          foodId: foodId,
          servings: 2,
          foodNameSnapshot: savedFood.name,
          caloriesSnapshot: savedFood.calories.toDouble(),
          proteinSnapshot: savedFood.protein,
          carbsSnapshot: savedFood.carbs,
          fatSnapshot: savedFood.fat,
        ),
      );

      final meal = (await databaseHelper.getMealItemsByDateAndMealType(
        '2026-07-21',
        'snack',
      )).single;
      expect(meal.totalCalories, 0);
      expect(meal.totalProtein, 0);
      expect(meal.totalCarbs, 0);
      expect(meal.totalFat, 0);
    },
  );

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
        foodNameSnapshot: '已使用食物',
        caloriesSnapshot: 200,
        proteinSnapshot: 10,
        carbsSnapshot: 12,
        fatSnapshot: 8,
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

  test('version 2 database migrates and backfills meal snapshots', () async {
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
      'carbs': 20,
      'fat': 4,
    });
    await version2Database.insert('meal_records', {
      'date': '2026-07-13',
      'meal_type': 'breakfast',
      'food_id': foodId,
      'servings': 1.5,
    });
    await version2Database.insert('meal_records', {
      'date': '2026-07-13',
      'meal_type': 'snack',
      'food_id': 999,
      'servings': 1,
    });
    await version2Database.close();

    final migratedDatabase = DatabaseHelper.forTesting(
      databaseFactoryFfi,
      databasePath: databasePath,
    );
    final db = await migratedDatabase.database;

    expect(await db.getVersion(), DatabaseHelper.databaseVersion);
    final foodColumns = await db.rawQuery('PRAGMA table_info(foods)');
    expect(
      foodColumns.map((column) => column['name']),
      contains('is_archived'),
    );
    final mealColumns = await db.rawQuery('PRAGMA table_info(meal_records)');
    expect(
      mealColumns.map((column) => column['name']),
      containsAll([
        'food_name_snapshot',
        'calories_snapshot',
        'protein_snapshot',
        'carbs_snapshot',
        'fat_snapshot',
      ]),
    );
    expect(await migratedDatabase.getFoods(), hasLength(1));
    expect(await migratedDatabase.getAllMealRecords(), hasLength(2));
    final weightTable = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'weight_records'",
    );
    expect(weightTable, hasLength(1));

    final breakfast = await migratedDatabase.getMealItemsByDateAndMealType(
      '2026-07-13',
      'breakfast',
    );
    expect(breakfast.single.foodName, '舊版食物');
    expect(breakfast.single.calories, 150);
    expect(breakfast.single.protein, 7.5);
    expect(breakfast.single.carbs, 20);
    expect(breakfast.single.fat, 4);

    final orphan = await migratedDatabase.getMealItemsByDateAndMealType(
      '2026-07-13',
      'snack',
    );
    expect(orphan.single.foodName, '未知食物');
    expect(orphan.single.calories, 0);
    expect(orphan.single.protein, 0);

    await migratedDatabase.close();
    await tempDirectory.delete(recursive: true);
  });

  test('version 4 migration preserves existing food and meal data', () async {
    final tempDirectory = await Directory.systemTemp.createTemp(
      'nutrilog_weight_migration_',
    );
    final databasePath = path.join(tempDirectory.path, 'health_app.db');
    final version4Database = await databaseFactoryFfi.openDatabase(
      databasePath,
      options: OpenDatabaseOptions(
        version: 4,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE foods (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              name TEXT NOT NULL,
              calories INTEGER NOT NULL,
              protein REAL NOT NULL,
              carbs REAL NOT NULL DEFAULT 0,
              fat REAL NOT NULL DEFAULT 0,
              favorite INTEGER NOT NULL DEFAULT 0,
              is_archived INTEGER NOT NULL DEFAULT 0
            )
          ''');
          await db.execute('''
            CREATE TABLE meal_records (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              date TEXT NOT NULL,
              meal_type TEXT NOT NULL,
              food_id INTEGER NOT NULL,
              servings REAL NOT NULL DEFAULT 1,
              food_name_snapshot TEXT NOT NULL DEFAULT '未知食物',
              calories_snapshot REAL NOT NULL DEFAULT 0,
              protein_snapshot REAL NOT NULL DEFAULT 0,
              carbs_snapshot REAL NOT NULL DEFAULT 0,
              fat_snapshot REAL NOT NULL DEFAULT 0
            )
          ''');
        },
      ),
    );
    final foodId = await version4Database.insert('foods', {
      'name': '升版前食物',
      'calories': 88,
      'protein': 6,
    });
    await version4Database.insert('meal_records', {
      'date': '2026-07-19',
      'meal_type': 'breakfast',
      'food_id': foodId,
      'servings': 1,
      'food_name_snapshot': '升版前食物',
      'calories_snapshot': 88,
      'protein_snapshot': 6,
    });
    await version4Database.close();

    final migratedDatabase = DatabaseHelper.forTesting(
      databaseFactoryFfi,
      databasePath: databasePath,
    );
    final db = await migratedDatabase.database;

    expect(await db.getVersion(), DatabaseHelper.databaseVersion);
    expect((await migratedDatabase.getFoods()).single.name, '升版前食物');
    expect(
      (await migratedDatabase.getAllMealRecords()).single.foodNameSnapshot,
      '升版前食物',
    );
    await migratedDatabase.saveWeightRecord('2026-07-20', 90.5);
    expect(
      (await migratedDatabase.getWeightRecordByDate('2026-07-20'))?.weight,
      90.5,
    );

    await migratedDatabase.close();
    await tempDirectory.delete(recursive: true);
  });

  test('meal snapshot does not change after its food is modified', () async {
    final foodId = await databaseHelper.insertFood(
      Food(name: '原始食物', calories: 100, protein: 8, carbs: 12, fat: 3),
    );
    await databaseHelper.insertMealRecord(
      MealRecord(
        date: '2026-07-20',
        mealType: 'dinner',
        foodId: foodId,
        servings: 2,
        foodNameSnapshot: '原始食物',
        caloriesSnapshot: 100,
        proteinSnapshot: 8,
        carbsSnapshot: 12,
        fatSnapshot: 3,
      ),
    );

    final db = await databaseHelper.database;
    await db.update(
      'foods',
      {'name': '修改後食物', 'calories': 999, 'protein': 99},
      where: 'id = ?',
      whereArgs: [foodId],
    );

    final items = await databaseHelper.getMealItemsByDateAndMealType(
      '2026-07-20',
      'dinner',
    );
    expect(items.single.foodName, '原始食物');
    expect(items.single.totalCalories, 200);
    expect(items.single.totalProtein, 16);
  });

  test('saving weight again on the same date updates one record', () async {
    await databaseHelper.saveWeightRecord('2026-07-20', 90);
    final first = await databaseHelper.getWeightRecordByDate('2026-07-20');

    await databaseHelper.saveWeightRecord('2026-07-20', 90.5);
    final updated = await databaseHelper.getWeightRecordByDate('2026-07-20');
    final records = await databaseHelper.getWeightRecords();

    expect(first, isNotNull);
    expect(updated?.id, first?.id);
    expect(updated?.weight, 90.5);
    expect(records, hasLength(1));
  });

  test('weights are independent by date and sorted newest first', () async {
    await databaseHelper.saveWeightRecord('2026-07-18', 91.2);
    await databaseHelper.saveWeightRecord('2026-07-20', 90.5);
    await databaseHelper.saveWeightRecord('2026-07-19', 90.8);

    expect(
      (await databaseHelper.getWeightRecordByDate('2026-07-18'))?.weight,
      91.2,
    );
    expect(
      (await databaseHelper.getWeightRecordByDate('2026-07-20'))?.weight,
      90.5,
    );
    expect(
      (await databaseHelper.getWeightRecords()).map((record) => record.date),
      ['2026-07-20', '2026-07-19', '2026-07-18'],
    );
  });

  test('weight record can be deleted', () async {
    await databaseHelper.saveWeightRecord('2026-07-20', 90);

    expect(await databaseHelper.deleteWeightRecord('2026-07-20'), 1);
    expect(await databaseHelper.getWeightRecordByDate('2026-07-20'), isNull);
  });

  test('database rejects out-of-range or over-precise weights', () async {
    for (final invalidWeight in [0.0, -1.0, 19.9, 500.1, 501.0, 90.55]) {
      expect(
        databaseHelper.saveWeightRecord('2026-07-20', invalidWeight),
        throwsArgumentError,
      );
    }
  });

  test('first nutrition goal is created and same date is updated', () async {
    await databaseHelper.saveNutritionGoal(
      const NutritionGoal(
        effectiveDate: '2026-07-20',
        calorieTarget: 1600,
        proteinTarget: 100,
      ),
    );
    await databaseHelper.saveNutritionGoal(
      const NutritionGoal(
        effectiveDate: '2026-07-20',
        calorieTarget: 1700,
        proteinTarget: 110,
      ),
    );

    final goals = await databaseHelper.getNutritionGoals();
    expect(goals, hasLength(1));
    expect(goals.single.calorieTarget, 1700);
    expect(goals.single.proteinTarget, 110);
  });

  test('nutrition goal lookup uses latest effective version by date', () async {
    await databaseHelper.saveNutritionGoal(
      const NutritionGoal(
        effectiveDate: '2026-07-20',
        calorieTarget: 1600,
        proteinTarget: 100,
      ),
    );
    await databaseHelper.saveNutritionGoal(
      const NutritionGoal(
        effectiveDate: '2026-08-01',
        calorieTarget: 1800,
        proteinTarget: 120,
      ),
    );

    expect(await databaseHelper.getNutritionGoalForDate('2026-07-19'), isNull);
    expect(
      (await databaseHelper.getNutritionGoalForDate(
        '2026-07-31',
      ))?.calorieTarget,
      1600,
    );
    expect(
      (await databaseHelper.getNutritionGoalForDate(
        '2026-08-01',
      ))?.calorieTarget,
      1800,
    );
    expect(
      (await databaseHelper.getNutritionGoalForDate(
        '2026-08-20',
      ))?.proteinTarget,
      120,
    );
  });

  test('version 5 goals migration preserves existing weight data', () async {
    final tempDirectory = await Directory.systemTemp.createTemp(
      'nutrilog_goals_migration_',
    );
    final databasePath = path.join(tempDirectory.path, 'health_app.db');
    final version5Database = await databaseFactoryFfi.openDatabase(
      databasePath,
      options: OpenDatabaseOptions(
        version: 5,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE weight_records (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              date TEXT NOT NULL UNIQUE,
              weight REAL NOT NULL
            )
          ''');
        },
      ),
    );
    await version5Database.insert('weight_records', {
      'date': '2026-07-20',
      'weight': 90.5,
    });
    await version5Database.close();

    final migratedDatabase = DatabaseHelper.forTesting(
      databaseFactoryFfi,
      databasePath: databasePath,
    );
    final db = await migratedDatabase.database;

    expect(await db.getVersion(), DatabaseHelper.databaseVersion);
    expect(
      (await migratedDatabase.getWeightRecordByDate('2026-07-20'))?.weight,
      90.5,
    );
    final goalsTable = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'goals'",
    );
    expect(goalsTable, hasLength(1));

    await migratedDatabase.close();
    await tempDirectory.delete(recursive: true);
  });
}
