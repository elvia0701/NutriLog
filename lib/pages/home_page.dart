import 'package:flutter/material.dart';
import 'package:nutrilog/models/food.dart';
import 'add_food_page.dart';

import '../widgets/dashboard_summary.dart';
import '../widgets/meal_section.dart';
import '../database/database_helper.dart';
import '../models/meal_item.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<Food> foods = [];

  List<MealItem> breakfastItems = [];
  List<MealItem> lunchItems = [];
  List<MealItem> dinnerItems = [];
  List<MealItem> snackItems = [];

  List<MealItem> get allMealItems => [
    ...breakfastItems,
    ...lunchItems,
    ...dinnerItems,
    ...snackItems,
  ];

  double get totalCalories =>
      allMealItems.fold(0, (total, item) => total + item.totalCalories);

  double get totalProtein =>
      allMealItems.fold(0, (total, item) => total + item.totalProtein);

  @override
  void initState() {
    super.initState();
    loadFoods();
    loadMealItems();
  }

  Future<void> loadFoods() async {
    final loadedFoods = await DatabaseHelper.instance.getFoods();

    final meals = await DatabaseHelper.instance.getAllMealRecords();

    debugPrint('========== MEAL RECORDS：${meals.length} ==========');

    setState(() {
      foods = loadedFoods;
    });
  }

  Future<void> loadMealItems() async {
    final today = DateTime.now().toIso8601String().substring(0, 10);

    final loadedBreakfast = await DatabaseHelper.instance
        .getMealItemsByDateAndMealType(today, 'breakfast');

    final loadedLunch = await DatabaseHelper.instance
        .getMealItemsByDateAndMealType(today, 'lunch');

    final loadedDinner = await DatabaseHelper.instance
        .getMealItemsByDateAndMealType(today, 'dinner');

    final loadedSnack = await DatabaseHelper.instance
        .getMealItemsByDateAndMealType(today, 'snack');

    if (!mounted) return;

    setState(() {
      breakfastItems = loadedBreakfast;
      lunchItems = loadedLunch;
      dinnerItems = loadedDinner;
      snackItems = loadedSnack;
    });

    debugPrint('早餐紀錄：${breakfastItems.length}');
    debugPrint('午餐紀錄：${lunchItems.length}');
    debugPrint('晚餐紀錄：${dinnerItems.length}');
    debugPrint('點心紀錄：${snackItems.length}');
  }

  Future<void> deleteMealItem(MealItem item) async {
    await DatabaseHelper.instance.deleteMealRecord(item.recordId);
    await loadMealItems();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: ListView(
            children: [
              const Text(
                'NutriLog',
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),

              const Text(
                '今天',
                style: TextStyle(fontSize: 20, color: Colors.grey),
              ),

              const SizedBox(height: 24),

              DashboardSummary(
                totalCalories: totalCalories,
                totalProtein: totalProtein,
              ),

              const SizedBox(height: 24),

              MealSection(
                title: '早餐',
                mealType: 'breakfast',
                items: breakfastItems,
                onMealAdded: loadMealItems,
                onDelete: deleteMealItem,
              ),
              MealSection(
                title: '午餐',
                mealType: 'lunch',
                items: lunchItems,
                onMealAdded: loadMealItems,
                onDelete: deleteMealItem,
              ),

              MealSection(
                title: '晚餐',
                mealType: 'dinner',
                items: dinnerItems,
                onMealAdded: loadMealItems,
                onDelete: deleteMealItem,
              ),

              MealSection(
                title: '點心',
                mealType: 'snack',
                items: snackItems,
                onMealAdded: loadMealItems,
                onDelete: deleteMealItem,
              ),
            ],
          ),
        ),
      ),

      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final AddFoodResult? result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddFoodPage()),
          );
          if (result != null) {
            await DatabaseHelper.instance.insertFood(result.food);
            await loadFoods();
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
