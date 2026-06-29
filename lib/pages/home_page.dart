import 'package:flutter/material.dart';

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
            children: const [
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

              SummaryCard(
                emoji: '🔥',
                title: '熱量',
                value: '$currentCalories / $calorieGoal kcal',
              ),

              SummaryCard(
                emoji: '🥩',
                title: '蛋白質',
                value: '$currentProtein / $proteinGoal g',
              ),

              SummaryCard(
                emoji: '⚖️',
                title: '體重',
                value: '$currentWeight kg',
              ),

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

class SummaryCard extends StatelessWidget {
  final String emoji;
  final String title;
  final String value;

  const SummaryCard({
    super.key,
    required this.emoji,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Text(
          emoji,
          style: const TextStyle(fontSize: 28),
        ),
        title: Text(title),
        subtitle: Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

class MealSection extends StatelessWidget {
  final String title;

  const MealSection({
    super.key,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        trailing: const Icon(Icons.add_circle_outline),
      ),
    );
  }
}