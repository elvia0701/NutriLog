import 'package:flutter/material.dart';
import '../pages/add_food_page.dart';
import '../models/meal_item.dart';

class MealSection extends StatelessWidget {
  final String title;
  final String mealType;
  final List<MealItem> items;

  const MealSection({
  super.key,
  required this.title,
  required this.mealType,
  required this.items,
  });

  @override
  Widget build(BuildContext context) {
    debugPrint('$title MealSection 收到 ${items.length} 筆');
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$title（${items.length}）',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            if (items.isEmpty)
              const Text(
                '尚無紀錄',
                style: TextStyle(color: Colors.grey),
              )
            else
              ...items.map(
                (item) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(item.foodName),
                  subtitle: Text(
                    '${item.totalCalories.toStringAsFixed(0)} kcal • '
                    '${item.totalProtein.toStringAsFixed(1)} g',
                  ),
                ),
              ),
            OutlinedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AddFoodPage(
                      mealType: mealType,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.add),
              label: const Text('新增食物'),
            ),
          ],
        ),
      ),
    );
  }
}