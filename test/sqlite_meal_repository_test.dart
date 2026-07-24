import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:nutrilog/database/database_helper.dart';
import 'package:nutrilog/models/food.dart';
import 'package:nutrilog/models/meal_record.dart';
import 'package:nutrilog/repositories/sqlite_meal_repository.dart';

void main() {
  sqfliteFfiInit();

  late DatabaseHelper databaseHelper;
  late SqliteMealRepository repository;

  setUp(() {
    databaseHelper = DatabaseHelper.forTesting(databaseFactoryFfi);
    repository = SqliteMealRepository(databaseHelper);
  });

  tearDown(() => databaseHelper.close());

  test('stores date, meal type, servings, and nutrition snapshots', () async {
    final foodId = await databaseHelper.insertFood(
      Food(name: '茶葉蛋', calories: 70, protein: 6, carbs: 1, fat: 5),
    );
    await repository.insertMealRecord(
      MealRecord(
        date: '2026-07-19',
        mealType: 'dinner',
        foodId: foodId,
        servings: 2.5,
        foodNameSnapshot: '茶葉蛋',
        caloriesSnapshot: 70,
        proteinSnapshot: 6,
        carbsSnapshot: 1,
        fatSnapshot: 5,
      ),
    );

    await databaseHelper.updateFood(
      Food(
        id: foodId,
        name: '修改後名稱',
        calories: 1,
        protein: 1,
        carbs: 1,
        fat: 1,
      ),
    );

    final item = (await repository.getMealItemsByDateAndMealType(
      '2026-07-19',
      'dinner',
    )).single;
    expect(item.foodName, '茶葉蛋');
    expect(item.servings, 2.5);
    expect(item.totalCalories, 175);
    expect(item.totalProtein, 15);
    expect(item.totalCarbs, 2.5);
    expect(item.totalFat, 12.5);
    expect(
      await repository.getMealItemsByDateAndMealType('2026-07-19', 'breakfast'),
      isEmpty,
    );
  });

  test('lists meal records and deletes a selected record', () async {
    final foodId = await databaseHelper.insertFood(
      Food(name: '香蕉', calories: 90, protein: 1.1),
    );
    await repository.insertMealRecord(
      MealRecord(
        date: '2026-07-20',
        mealType: 'snack',
        foodId: foodId,
        servings: 1,
        foodNameSnapshot: '香蕉',
        caloriesSnapshot: 90,
        proteinSnapshot: 1.1,
        carbsSnapshot: 0,
        fatSnapshot: 0,
      ),
    );

    expect(await repository.getAllMealRecords(), hasLength(1));
    expect(await repository.getMealRecordsByDate('2026-07-20'), hasLength(1));
    expect(
      await repository.getMealRecordsByDateAndMealType('2026-07-20', 'snack'),
      hasLength(1),
    );

    final item = (await repository.getMealItemsByDateAndMealType(
      '2026-07-20',
      'snack',
    )).single;
    await repository.deleteMealRecord(item);
    expect(await repository.getAllMealRecords(), isEmpty);
  });
}
