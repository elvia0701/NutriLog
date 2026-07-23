import '../models/meal_item.dart';
import '../models/meal_record.dart';

abstract interface class MealRepository {
  Future<int> insertMealRecord(MealRecord mealRecord);

  Future<List<MealRecord>> getAllMealRecords();

  Future<List<MealRecord>> getMealRecordsByDate(String date);

  Future<List<MealRecord>> getMealRecordsByDateAndMealType(
    String date,
    String mealType,
  );

  Future<List<MealItem>> getMealItemsByDateAndMealType(
    String date,
    String mealType,
  );

  Future<void> deleteMealRecord(int id);
}
