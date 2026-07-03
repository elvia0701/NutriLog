import 'package:flutter/material.dart';
import '../models/food.dart';

class AddFoodPage extends StatefulWidget {
  const AddFoodPage({super.key});

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('新增食物'),
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
              decoration: const  InputDecoration(
                labelText: '熱量 kcal',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            TextField(
              controller: proteinController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: '蛋白質 g',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
              onPressed: () {
                  Food newFood = Food(
                    name: nameController.text,
                    calories: int.parse(caloriesController.text),
                    protein: double.parse(proteinController.text),
                  );

                  Navigator.pop(context, newFood);
                },
                child: const Text('新增'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}