import 'package:flutter/material.dart';

import '../models/food.dart';

class AddFoodResult {
  final Food food;
  final double servings;

  const AddFoodResult({required this.food, required this.servings});
}

class AddFoodPage extends StatefulWidget {
  final String? mealType;
  final Food? initialFood;

  const AddFoodPage({super.key, this.mealType, this.initialFood});

  @override
  State<AddFoodPage> createState() => _AddFoodPageState();
}

class _AddFoodPageState extends State<AddFoodPage> {
  final formKey = GlobalKey<FormState>();
  late final TextEditingController nameController;
  late final TextEditingController caloriesController;
  late final TextEditingController proteinController;
  late final TextEditingController carbsController;
  late final TextEditingController fatController;
  final servingsController = TextEditingController(text: '1');

  bool get isEditing => widget.initialFood != null;

  @override
  void initState() {
    super.initState();
    final food = widget.initialFood;
    nameController = TextEditingController(text: food?.name ?? '');
    caloriesController = TextEditingController(
      text: food == null ? '' : food.calories.toString(),
    );
    proteinController = TextEditingController(
      text: food == null ? '' : _formatNumber(food.protein),
    );
    carbsController = TextEditingController(
      text: food == null ? '' : _formatNumber(food.carbs),
    );
    fatController = TextEditingController(
      text: food == null ? '' : _formatNumber(food.fat),
    );
  }

  String _formatNumber(num value) {
    return value.toStringAsFixed(6).replaceFirst(RegExp(r'\.?0+$'), '');
  }

  @override
  void dispose() {
    nameController.dispose();
    caloriesController.dispose();
    proteinController.dispose();
    carbsController.dispose();
    fatController.dispose();
    servingsController.dispose();
    super.dispose();
  }

  String? _validateName(String? input) {
    if ((input ?? '').trim().isEmpty) return '請輸入食物名稱';
    return null;
  }

  String? _validateCalories(String? input) {
    final text = (input ?? '').trim();
    if (text.isEmpty) return '請輸入熱量';
    final value = int.tryParse(text);
    if (value == null) return '熱量必須是整數';
    if (value < 0) return '熱量不可小於 0';
    return null;
  }

  String? _validateNutrient(String? input, String label) {
    final text = (input ?? '').trim();
    if (text.isEmpty) return '請輸入$label';
    final value = double.tryParse(text);
    if (value == null || !value.isFinite) return '$label必須是數字';
    if (value < 0) return '$label不可小於 0';
    return null;
  }

  String? _validateServings(String? input) {
    final servings = double.tryParse((input ?? '').trim());
    if (servings == null || !servings.isFinite || servings <= 0) {
      return '份數必須是大於 0 的數字';
    }
    return null;
  }

  void saveFood() {
    if (formKey.currentState?.validate() != true) return;

    final original = widget.initialFood;
    final result = AddFoodResult(
      food: Food(
        id: original?.id,
        name: nameController.text.trim(),
        calories: int.parse(caloriesController.text.trim()),
        protein: double.parse(proteinController.text.trim()),
        carbs: double.parse(carbsController.text.trim()),
        fat: double.parse(fatController.text.trim()),
        favorite: original?.favorite ?? false,
        isArchived: original?.isArchived ?? false,
      ),
      servings: widget.mealType == null
          ? 1
          : double.parse(servingsController.text.trim()),
    );

    Navigator.pop(context, result);
  }

  @override
  Widget build(BuildContext context) {
    final title = isEditing
        ? '編輯食物'
        : widget.mealType == null
        ? '建立新食物'
        : '加入食物';
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Form(
        key: formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              key: const Key('foodNameField'),
              controller: nameController,
              decoration: const InputDecoration(labelText: '食物名稱'),
              validator: _validateName,
            ),
            const SizedBox(height: 16),
            TextFormField(
              key: const Key('foodCaloriesField'),
              controller: caloriesController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: '熱量 kcal'),
              validator: _validateCalories,
            ),
            const SizedBox(height: 16),
            TextFormField(
              key: const Key('foodProteinField'),
              controller: proteinController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: '蛋白質 g'),
              validator: (value) => _validateNutrient(value, '蛋白質'),
            ),
            const SizedBox(height: 16),
            TextFormField(
              key: const Key('foodCarbsField'),
              controller: carbsController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: '碳水 g'),
              validator: (value) => _validateNutrient(value, '碳水'),
            ),
            const SizedBox(height: 16),
            TextFormField(
              key: const Key('foodFatField'),
              controller: fatController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: '脂肪 g'),
              validator: (value) => _validateNutrient(value, '脂肪'),
            ),
            if (widget.mealType != null) ...[
              const SizedBox(height: 16),
              TextFormField(
                key: const Key('servingsField'),
                controller: servingsController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(labelText: '份數'),
                validator: _validateServings,
              ),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                key: const Key('saveFoodButton'),
                onPressed: saveFood,
                child: Text(
                  isEditing
                      ? '儲存修改'
                      : widget.mealType == null
                      ? '建立食物'
                      : '建立並加入這一餐',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
