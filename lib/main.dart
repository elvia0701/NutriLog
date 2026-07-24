import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth/auth_gate.dart';
import 'auth/auth_service.dart';
import 'auth/supabase_auth_service.dart';
import 'config/supabase_config.dart';
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

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final supabaseConfig = SupabaseConfig.fromEnvironment();
  final configurationError = supabaseConfig.validationError;

  if (configurationError != null) {
    runApp(_ConfigurationErrorApp(message: configurationError));
    return;
  }

  supabaseConfig.debugPrintSummary();
  await Supabase.initialize(
    url: supabaseConfig.url,
    publishableKey: supabaseConfig.anonKey,
  );
  final databaseHelper = DatabaseHelper.instance;
  final authService = SupabaseAuthService(Supabase.instance.client);
  runApp(
    NutriLogApp(
      authService: authService,
      foodRepository: SqliteFoodRepository(databaseHelper),
      mealRepository: SqliteMealRepository(databaseHelper),
      weightRepository: SqliteWeightRepository(databaseHelper),
      nutritionGoalRepository: SqliteNutritionGoalRepository(databaseHelper),
    ),
  );
}

class NutriLogApp extends StatelessWidget {
  final AuthService authService;
  final FoodRepository foodRepository;
  final MealRepository mealRepository;
  final WeightRepository weightRepository;
  final NutritionGoalRepository nutritionGoalRepository;

  const NutriLogApp({
    super.key,
    required this.authService,
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
      home: AuthGate(
        authService: authService,
        signedInChild: HomePage(
          foodRepository: foodRepository,
          mealRepository: mealRepository,
          weightRepository: weightRepository,
          nutritionGoalRepository: nutritionGoalRepository,
          authService: authService,
        ),
      ),
    );
  }
}

class _ConfigurationErrorApp extends StatelessWidget {
  final String message;

  const _ConfigurationErrorApp({required this.message});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'NutriLog',
      theme: AppTheme.light,
      home: Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(message, textAlign: TextAlign.center),
            ),
          ),
        ),
      ),
    );
  }
}
