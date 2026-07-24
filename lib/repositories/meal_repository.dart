import '../models/meal_item.dart';
import '../models/meal_record.dart';

enum MealRepositoryFailureKind {
  unauthenticated,
  network,
  permissionDenied,
  foodUnavailable,
  invalidData,
  notFound,
  unknown,
}

class MealRepositoryException implements Exception {
  final MealRepositoryFailureKind kind;
  final String message;

  const MealRepositoryException(this.kind, this.message);

  @override
  String toString() => message;
}

abstract interface class MealRepository {
  Future<MealRecord> insertMealRecord(MealRecord mealRecord);

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

  Future<void> deleteMealRecord(MealItem item);
}
