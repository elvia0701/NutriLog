import 'package:flutter/material.dart';

import '../database/database_helper.dart';
import '../models/food.dart';
import '../models/meal_record.dart';

class AddFoodPage extends StatefulWidget {
  final String? mealType;

  const AddFoodPage({
    super.key,
    this.mealType,
  });

  @override
  State<AddFoodPage> createState() => _AddFoodPageState();
}

class _AddFoodPageState extends State<AddFoodPage> {
  final nameController = TextEditingController();
  final caloriesController = TextEditingController();
  final proteinController = TextEditingController();

  @override
  void dispose() {
    nameController.dispose();
    caloriesController.dispose();
    proteinController.dispose();
    super.dispose();
  }

  Future<void> saveFood() async {
    final name = nameController.text.trim();
    final calories = int.tryParse(caloriesController.text.trim());
    final protein = double.tryParse(proteinController.text.trim());

    if (name.isEmpty || calories == null || protein == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('請正確填寫食物名稱、熱量與蛋白質'),
        ),
      );
      return;
    }

    final newFood = Food(
      name: name,
      calories: calories,
      protein: protein,
    );

    // 從首頁右下角按鈕進入：
    // 只回傳 Food，由 HomePage 負責寫入 foods。
    if (widget.mealType == null) {
      Navigator.pop(context, newFood);
      return;
    }

    // 從早餐、午餐、晚餐或點心進入：
    // 先新增 Food，再建立 MealRecord。
    final foodId = await DatabaseHelper.instance.insertFood(newFood);

    final today = DateTime.now().toIso8601String().substring(0, 10);

    final mealRecord = MealRecord(
      date: today,
      mealType: widget.mealType!,
      foodId: foodId,
      servings: 1,
    );

    await DatabaseHelper.instance.insertMealRecord(mealRecord);

    if (!mounted) return;

    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.mealType == null ? '建立新食物' : '加入食物',
        ),
      ),
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
            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: saveFood,
                child: Text(
                  widget.mealType == null ? '建立食物' : '加入這一餐',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}