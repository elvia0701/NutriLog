import 'package:flutter/material.dart';
import 'database/database_helper.dart';
import 'pages/home_page.dart';
import 'repositories/nutrition_goal_repository.dart';
import 'repositories/sqlite_nutrition_goal_repository.dart';
import 'repositories/sqlite_weight_repository.dart';
import 'repositories/weight_repository.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(
    NutriLogApp(
      weightRepository: SqliteWeightRepository(DatabaseHelper.instance),
      nutritionGoalRepository: SqliteNutritionGoalRepository(
        DatabaseHelper.instance,
      ),
    ),
  );
}

class NutriLogApp extends StatelessWidget {
  final WeightRepository weightRepository;
  final NutritionGoalRepository nutritionGoalRepository;

  const NutriLogApp({
    super.key,
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
        weightRepository: weightRepository,
        nutritionGoalRepository: nutritionGoalRepository,
      ),
    );
  }
}
