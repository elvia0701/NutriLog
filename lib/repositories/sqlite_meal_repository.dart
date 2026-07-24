import '../database/database_helper.dart';
import '../models/meal_item.dart';
import '../models/meal_record.dart';
import 'meal_repository.dart';

class SqliteMealRepository implements MealRepository {
  final DatabaseHelper databaseHelper;

  const SqliteMealRepository(this.databaseHelper);

  @override
  Future<MealRecord> insertMealRecord(MealRecord mealRecord) async {
    final id = await databaseHelper.insertMealRecord(mealRecord);
    return mealRecord.copyWith(id: id);
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
  Future<void> deleteMealRecord(MealItem item) async {
    final id = item.recordId;
    if (id == null) {
      throw const MealRepositoryException(
        MealRepositoryFailureKind.invalidData,
        '餐點識別資料不完整，請重新載入後再試。',
      );
    }
    await databaseHelper.deleteMealRecord(id);
  }
}
