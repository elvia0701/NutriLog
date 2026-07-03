import 'package:flutter/material.dart';
import '../models/food.dart';

class MealSection extends StatelessWidget {
  final String title;
  final List<Food> foods;

  const MealSection({
  super.key,
  required this.title,
  required this.foods,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
  margin: const EdgeInsets.symmetric(vertical: 8),
    child: Padding(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),

            for (final food in foods)
              Text(
                '${food.name}｜${food.calories} kcal｜${food.protein} g',
                style: const TextStyle(fontSize: 16),
              ),
          ],
        ),
      ),
    );
  }
}