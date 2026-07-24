import '../models/food.dart';

enum FoodRemovalResult { deleted, archived, notFound }

enum FoodRepositoryFailureKind {
  unauthenticated,
  network,
  permissionDenied,
  invalidData,
  notFound,
  unknown,
}

class FoodRepositoryException implements Exception {
  final FoodRepositoryFailureKind kind;
  final String message;

  const FoodRepositoryException(this.kind, this.message);

  @override
  String toString() => message;
}

abstract interface class FoodRepository {
  Future<List<Food>> getFoods();

  Future<Food> insertFood(Food food);

  Future<int> updateFood(Food food);

  Future<int> getFoodReferenceCount(Food food);

  Future<FoodRemovalResult> removeFood(Food food);
}
