import 'package:flutter/material.dart';
import 'database/database_helper.dart';
import 'pages/home_page.dart';
import 'repositories/food_repository.dart';
import 'repositories/meal_repository.dart';
import 'repositories/nutrition_goal_repository.dart';
import 'repositories/sqlite_food_repository.dart';
import 'repositories/sqlite_meal_repository.dart';
import 'repositories/sqlite_nutrition_goal_repository.dart';
import 'repositories/sqlite_weight_repository.dart';
import 'repositories/weight_repository.dart';
import 'theme/app_theme.dart';

void main() {
  final databaseHelper = DatabaseHelper.instance;
  runApp(
    NutriLogApp(
      foodRepository: SqliteFoodRepository(databaseHelper),
      mealRepository: SqliteMealRepository(databaseHelper),
      weightRepository: SqliteWeightRepository(databaseHelper),
      nutritionGoalRepository: SqliteNutritionGoalRepository(databaseHelper),
    ),
  );
}

class NutriLogApp extends StatelessWidget {
  final FoodRepository foodRepository;
  final MealRepository mealRepository;
  final WeightRepository weightRepository;
  final NutritionGoalRepository nutritionGoalRepository;

  const NutriLogApp({
    super.key,
    required this.foodRepository,
    required this.mealRepository,
    required this.weightRepository,
    required this.nutritionGoalRepository,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'NutriLog',
      theme: AppTheme.light,
      home: HomePage(
        foodRepository: foodRepository,
        mealRepository: mealRepository,
        weightRepository: weightRepository,
        nutritionGoalRepository: nutritionGoalRepository,
      ),
    );
  }
}
