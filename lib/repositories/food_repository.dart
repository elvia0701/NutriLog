import '../models/food.dart';

enum FoodRemovalResult { deleted, archived, notFound }

abstract interface class FoodRepository {
  Future<List<Food>> getFoods();

  Future<int> insertFood(Food food);

  Future<int> updateFood(Food food);

  Future<int> getFoodReferenceCount(int foodId);

  Future<FoodRemovalResult> removeFood(int foodId);
}
