import 'package:flutter/material.dart';
import '../widgets/dashboard_summary.dart';
import '../widgets/meal_section.dart';
import 'add_food_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

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
              Text(
                'YL-Health',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8),

              Text(
                '今天',
                style: TextStyle(
                  fontSize: 20,
                  color: Colors.grey,
                ),
              ),

              SizedBox(height: 24),

              DashboardSummary(),

              SizedBox(height: 24),

              MealSection(title: '早餐'),
              MealSection(title: '午餐'),
              MealSection(title: '晚餐'),
              MealSection(title: '點心'),
            ],
          ),
        ),
      ),
    );
  }
}

