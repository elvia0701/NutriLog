import 'package:flutter/material.dart';

import '../models/food.dart';

class AddFoodResult {
  final Food food;
  final double servings;

  const AddFoodResult({required this.food, required this.servings});
}

class AddFoodPage extends StatefulWidget {
  final String? mealType;

  const AddFoodPage({super.key, this.mealType});

  @override
  State<AddFoodPage> createState() => _AddFoodPageState();
}

class _AddFoodPageState extends State<AddFoodPage> {
  final nameController = TextEditingController();
  final caloriesController = TextEditingController();
  final proteinController = TextEditingController();
  final servingsController = TextEditingController(text: '1');

  @override
  void dispose() {
    nameController.dispose();
    caloriesController.dispose();
    proteinController.dispose();
    servingsController.dispose();
    super.dispose();
  }

  Future<void> saveFood() async {
    final name = nameController.text.trim();
    final calories = int.tryParse(caloriesController.text.trim());
    final protein = double.tryParse(proteinController.text.trim());
    final servings = double.tryParse(servingsController.text.trim());

    if (name.isEmpty || calories == null || protein == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('請正確填寫食物名稱、熱量與蛋白質')));
      return;
    }

    if (servings == null || !servings.isFinite || servings <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('份數必須是大於 0 的數字')));
      return;
    }

    final result = AddFoodResult(
      food: Food(name: name, calories: calories, protein: protein),
      servings: servings,
    );

    Navigator.pop(context, result);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.mealType == null ? '建立新食物' : '加入食物')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: '食物名稱',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            TextField(
              controller: caloriesController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: '熱量 kcal',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            TextField(
              controller: proteinController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: '蛋白質 g',
                border: OutlineInputBorder(),
              ),
            ),

            if (widget.mealType != null) ...[
              const SizedBox(height: 16),
              TextField(
                key: const Key('servingsField'),
                controller: servingsController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: '份數',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: saveFood,
                child: Text(widget.mealType == null ? '建立食物' : '建立並加入這一餐'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
