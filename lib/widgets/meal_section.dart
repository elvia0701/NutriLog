import '../pages/add_food_page.dart';
import 'package:flutter/material.dart';

class MealSection extends StatelessWidget {
  final String title;

  const MealSection({
  super.key,
  required this.title,
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
        OutlinedButton.icon(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const AddFoodPage(),
              ),
            );
          },
          icon: const Icon(Icons.add),
          label: const Text("新增食物"),
          ),
        ],
      ),
    ),
    );
  }
}