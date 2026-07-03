import 'package:flutter/material.dart';
import '../widgets/dashboard_summary.dart';
import '../widgets/meal_section.dart';
import '../models/food.dart';
import 'add_food_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final List<Food> foods = [];

  @override
  Widget build(BuildContext context) {
    const calorieGoal = 1600;
    const proteinGoal = 100;
    const currentCalories = 0;
    const currentProtein = 0;
    const currentWeight = 91.3;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: ListView(
            children:  [
              const Text(
                'YL-Health',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),

              const Text(
                '今天',
                style: TextStyle(
                  fontSize: 20,
                  color: Colors.grey,
                ),
              ),

              const SizedBox(height: 24),

              const DashboardSummary(),

              const SizedBox(height: 24),

              MealSection(
                title: '早餐',
                foods: foods,
              ),

              MealSection(
                title: '午餐',
                foods: foods,
              ),

              MealSection(
                title: '晚餐',
                foods: foods,
              ),

              MealSection(
                title: '點心',
                foods: foods,
              ),
            ],
          ),
        ),
      ),

      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final Food? food = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AddFoodPage(),
            ),
          );
            if (food != null) {
            setState(() {
              foods.add(food);
            });
          }
        },
        child: const Icon(Icons.add),
    ),
    );
  }
}