import '../database/database_helper.dart';
import '../models/meal_item.dart';
import '../models/meal_record.dart';
import 'meal_repository.dart';

class SqliteMealRepository implements MealRepository {
  final DatabaseHelper databaseHelper;

  const SqliteMealRepository(this.databaseHelper);

  @override
  Future<int> insertMealRecord(MealRecord mealRecord) {
    return databaseHelper.insertMealRecord(mealRecord);
  }

  @override
  Future<List<MealRecord>> getAllMealRecords() {
    return databaseHelper.getAllMealRecords();
  }

  @override
  Future<List<MealRecord>> getMealRecordsByDate(String date) {
    return databaseHelper.getMealRecordsByDate(date);
  }

  @override
  Future<List<MealRecord>> getMealRecordsByDateAndMealType(
    String date,
    String mealType,
  ) {
    return databaseHelper.getMealRecordsByDateAndMealType(date, mealType);
  }

  @override
  Future<List<MealItem>> getMealItemsByDateAndMealType(
    String date,
    String mealType,
  ) {
    return databaseHelper.getMealItemsByDateAndMealType(date, mealType);
  }

  @override
  Future<void> deleteMealRecord(int id) async {
    await databaseHelper.deleteMealRecord(id);
  }
}
