import '../database/database_helper.dart';
import '../models/food.dart';
import 'food_repository.dart';

class SqliteFoodRepository implements FoodRepository {
  final DatabaseHelper databaseHelper;

  const SqliteFoodRepository(this.databaseHelper);

  @override
  Future<List<Food>> getFoods() => databaseHelper.getFoods();

  @override
  Future<int> insertFood(Food food) => databaseHelper.insertFood(food);

  @override
  Future<int> updateFood(Food food) => databaseHelper.updateFood(food);

  @override
  Future<int> getFoodReferenceCount(int foodId) {
    return databaseHelper.getFoodReferenceCount(foodId);
  }

  @override
  Future<FoodRemovalResult> removeFood(int foodId) {
    return databaseHelper.removeFood(foodId);
  }
}
