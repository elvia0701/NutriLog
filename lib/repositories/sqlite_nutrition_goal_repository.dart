import '../database/database_helper.dart';
import '../models/nutrition_goal.dart';
import 'nutrition_goal_repository.dart';

class SqliteNutritionGoalRepository implements NutritionGoalRepository {
  final DatabaseHelper databaseHelper;

  const SqliteNutritionGoalRepository(this.databaseHelper);

  @override
  Future<NutritionGoal?> getGoalForDate(String date) {
    return databaseHelper.getNutritionGoalForDate(date);
  }

  @override
  Future<List<NutritionGoal>> getGoalHistory() {
    return databaseHelper.getNutritionGoals();
  }

  @override
  Future<void> saveGoal(NutritionGoal goal) {
    return databaseHelper.saveNutritionGoal(goal);
  }
}
