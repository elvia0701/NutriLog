import '../database/database_helper.dart';
import '../models/food.dart';
import 'food_repository.dart';

class SqliteFoodRepository implements FoodRepository {
  final DatabaseHelper databaseHelper;

  const SqliteFoodRepository(this.databaseHelper);

  @override
  Future<List<Food>> getFoods() => databaseHelper.getFoods();

  @override
  Future<Food> insertFood(Food food) async {
    final id = await databaseHelper.insertFood(food);
    return food.copyWith(id: id);
  }

  @override
  Future<int> updateFood(Food food) => databaseHelper.updateFood(food);

  @override
  Future<int> getFoodReferenceCount(Food food) {
    final foodId = food.id;
    if (foodId == null) return Future.value(0);
    return databaseHelper.getFoodReferenceCount(foodId);
  }

  @override
  Future<FoodRemovalResult> removeFood(Food food) {
    final foodId = food.id;
    if (foodId == null) return Future.value(FoodRemovalResult.notFound);
    return databaseHelper.removeFood(foodId);
  }
}
