import '../models/nutrition_goal.dart';

abstract interface class NutritionGoalRepository {
  Future<NutritionGoal?> getGoalForDate(String date);

  Future<List<NutritionGoal>> getGoalHistory();

  Future<void> saveGoal(NutritionGoal goal);
}
