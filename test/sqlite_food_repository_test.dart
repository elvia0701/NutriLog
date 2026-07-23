import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:nutrilog/database/database_helper.dart';
import 'package:nutrilog/models/food.dart';
import 'package:nutrilog/models/meal_record.dart';
import 'package:nutrilog/repositories/food_repository.dart';
import 'package:nutrilog/repositories/sqlite_food_repository.dart';

void main() {
  sqfliteFfiInit();

  late DatabaseHelper databaseHelper;
  late SqliteFoodRepository repository;

  setUp(() {
    databaseHelper = DatabaseHelper.forTesting(databaseFactoryFfi);
    repository = SqliteFoodRepository(databaseHelper);
  });

  tearDown(() => databaseHelper.close());

  test('creates, updates, lists, and keeps same-name foods distinct', () async {
    final firstId = await repository.insertFood(
      Food(name: '優格', calories: 100, protein: 8, favorite: true),
    );
    final secondId = await repository.insertFood(
      Food(name: '優格', calories: 0, protein: 0, carbs: 0, fat: 0),
    );

    expect(firstId, isNot(secondId));
    expect(await repository.getFoods(), hasLength(2));

    await repository.updateFood(
      Food(
        id: firstId,
        name: '希臘優格',
        calories: 0,
        protein: 0,
        carbs: 0,
        fat: 0,
        favorite: true,
      ),
    );

    final updated = (await repository.getFoods()).singleWhere(
      (food) => food.id == firstId,
    );
    expect(updated.name, '希臘優格');
    expect(updated.calories, 0);
    expect(updated.protein, 0);
    expect(updated.carbs, 0);
    expect(updated.fat, 0);
    expect(updated.favorite, isTrue);
  });

  test('deletes unused food and archives referenced food safely', () async {
    final unusedId = await repository.insertFood(
      Food(name: '未使用', calories: 10, protein: 1),
    );
    expect(await repository.removeFood(unusedId), FoodRemovalResult.deleted);

    final referencedId = await repository.insertFood(
      Food(name: '已使用', calories: 70, protein: 6),
    );
    await databaseHelper.insertMealRecord(
      MealRecord(
        date: '2026-07-19',
        mealType: 'breakfast',
        foodId: referencedId,
        servings: 1,
        foodNameSnapshot: '已使用',
        caloriesSnapshot: 70,
        proteinSnapshot: 6,
        carbsSnapshot: 0,
        fatSnapshot: 0,
      ),
    );

    expect(await repository.getFoodReferenceCount(referencedId), 1);
    expect(
      await repository.removeFood(referencedId),
      FoodRemovalResult.archived,
    );
    expect(await repository.getFoods(), isEmpty);
    expect(await databaseHelper.getAllMealRecords(), hasLength(1));
  });
}
