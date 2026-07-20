import 'package:flutter/material.dart';

import '../database/database_helper.dart';
import '../models/food.dart';
import '../models/meal_record.dart';
import 'add_food_page.dart';

class FoodDatabasePage extends StatefulWidget {
  final String mealType;
  final String date;
  final Future<List<Food>> Function()? loadFoods;
  final Future<int> Function(Food food)? insertFood;
  final Future<int> Function(MealRecord mealRecord)? insertMealRecord;
  final Future<int> Function(int foodId)? getFoodReferenceCount;
  final Future<FoodRemovalResult> Function(int foodId)? removeFood;

  const FoodDatabasePage({
    super.key,
    required this.mealType,
    required this.date,
    this.loadFoods,
    this.insertFood,
    this.insertMealRecord,
    this.getFoodReferenceCount,
    this.removeFood,
  });

  @override
  State<FoodDatabasePage> createState() => _FoodDatabasePageState();
}

class _FoodDatabasePageState extends State<FoodDatabasePage> {
  List<Food> _foods = [];
  String _query = '';
  bool _isLoading = true;

  List<Food> get _filteredFoods {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return _foods;

    return _foods
        .where((food) => food.name.toLowerCase().contains(query))
        .toList();
  }

  @override
  void initState() {
    super.initState();
    _loadFoods();
  }

  Future<List<Food>> _getFoods() {
    if (widget.loadFoods != null) return widget.loadFoods!();
    return DatabaseHelper.instance.getFoods();
  }

  Future<int> _createFood(Food food) {
    if (widget.insertFood != null) return widget.insertFood!(food);
    return DatabaseHelper.instance.insertFood(food);
  }

  Future<int> _createMealRecord(MealRecord mealRecord) {
    if (widget.insertMealRecord != null) {
      return widget.insertMealRecord!(mealRecord);
    }
    return DatabaseHelper.instance.insertMealRecord(mealRecord);
  }

  Future<int> _getFoodReferenceCount(int foodId) {
    if (widget.getFoodReferenceCount != null) {
      return widget.getFoodReferenceCount!(foodId);
    }
    return DatabaseHelper.instance.getFoodReferenceCount(foodId);
  }

  Future<FoodRemovalResult> _removeFood(int foodId) {
    if (widget.removeFood != null) {
      return widget.removeFood!(foodId);
    }
    return DatabaseHelper.instance.removeFood(foodId);
  }

  Future<void> _loadFoods() async {
    final foods = await _getFoods();
    if (!mounted) return;

    setState(() {
      _foods = foods;
      _isLoading = false;
    });
  }

  String _formatNumber(num value) {
    return value.toStringAsFixed(6).replaceFirst(RegExp(r'\.?0+$'), '');
  }

  Future<double?> _askForServings(Food food) async {
    return showDialog<double>(
      context: context,
      builder: (context) => _ServingsDialog(foodName: food.name),
    );
  }

  Future<void> _saveMealRecord({
    required Food food,
    required double servings,
  }) async {
    final foodId = food.id;
    if (foodId == null) return;
    await _createMealRecord(
      MealRecord(
        date: widget.date,
        mealType: widget.mealType,
        foodId: foodId,
        servings: servings,
        foodNameSnapshot: food.name,
        caloriesSnapshot: food.calories.toDouble(),
        proteinSnapshot: food.protein,
        carbsSnapshot: food.carbs,
        fatSnapshot: food.fat,
      ),
    );
  }

  Future<void> _selectFood(Food food) async {
    final foodId = food.id;
    if (foodId == null) return;

    final servings = await _askForServings(food);
    if (servings == null) return;

    await _saveMealRecord(food: food, servings: servings);
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  Future<void> _createAndAddFood() async {
    final result = await Navigator.push<AddFoodResult>(
      context,
      MaterialPageRoute(
        builder: (context) => AddFoodPage(mealType: widget.mealType),
      ),
    );
    if (result == null) return;

    final foodId = await _createFood(result.food);
    final createdFood = Food(
      id: foodId,
      name: result.food.name,
      calories: result.food.calories,
      protein: result.food.protein,
      carbs: result.food.carbs,
      fat: result.food.fat,
      favorite: result.food.favorite,
      isArchived: result.food.isArchived,
    );
    await _saveMealRecord(food: createdFood, servings: result.servings);
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  Future<void> _confirmAndRemoveFood(Food food) async {
    final foodId = food.id;
    if (foodId == null) return;

    final referenceCount = await _getFoodReferenceCount(foodId);
    if (!mounted) return;
    final hasReferences = referenceCount > 0;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('移除食物？'),
        content: Text(
          hasReferences
              ? '「${food.name}」曾用於歷史飲食紀錄。'
                    '移除後會封存並從可選食物中隱藏，歷史餐點會保留。'
              : '確定要永久刪除「${food.name}」嗎？此操作無法復原。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('移除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final result = await _removeFood(foodId);
    if (!mounted) return;

    if (result == FoodRemovalResult.notFound) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('找不到這項食物，列表將重新整理。')));
      await _loadFoods();
      return;
    }

    setState(() {
      _foods.removeWhere((item) => item.id == foodId);
    });

    if (result == FoodRemovalResult.archived) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('食物已封存，歷史餐點仍會保留。')));
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('食物資料庫目前沒有食物'),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _createAndAddFood,
            child: const Text('建立第一個食物'),
          ),
        ],
      ),
    );
  }

  Widget _buildNoResults() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('找不到食物'),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: _createAndAddFood,
            child: const Text('建立新食物'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredFoods = _filteredFoods;

    return Scaffold(
      appBar: AppBar(title: const Text('食物資料庫')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              key: const Key('foodSearchField'),
              onChanged: (value) => setState(() => _query = value),
              decoration: const InputDecoration(
                labelText: '搜尋食物',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                key: const Key('createNewFoodButton'),
                onPressed: _createAndAddFood,
                icon: const Icon(Icons.add),
                label: const Text('建立新食物'),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _foods.isEmpty
                  ? _buildEmptyState()
                  : filteredFoods.isEmpty
                  ? _buildNoResults()
                  : ListView.separated(
                      itemCount: filteredFoods.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final food = filteredFoods[index];
                        return ListTile(
                          key: ValueKey('food_${food.id}_$index'),
                          title: Text(food.name),
                          subtitle: Text(
                            '每份 ${food.calories} kcal • '
                            '蛋白質 ${_formatNumber(food.protein)} g',
                          ),
                          trailing: IconButton(
                            key: ValueKey('delete_food_${food.id}'),
                            onPressed: food.id == null
                                ? null
                                : () => _confirmAndRemoveFood(food),
                            tooltip: '移除食物',
                            icon: const Icon(Icons.delete_outline),
                          ),
                          onTap: () => _selectFood(food),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ServingsDialog extends StatefulWidget {
  final String foodName;

  const _ServingsDialog({required this.foodName});

  @override
  State<_ServingsDialog> createState() => _ServingsDialogState();
}

class _ServingsDialogState extends State<_ServingsDialog> {
  final controller = TextEditingController(text: '1');
  String? errorText;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void _submit() {
    final servings = double.tryParse(controller.text.trim());
    if (servings == null || !servings.isFinite || servings <= 0) {
      setState(() {
        errorText = '份數必須是大於 0 的數字';
      });
      return;
    }

    Navigator.pop(context, servings);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('加入「${widget.foodName}」'),
      content: TextField(
        key: const Key('existingFoodServingsField'),
        controller: controller,
        autofocus: true,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText: '份數',
          errorText: errorText,
          border: const OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(onPressed: _submit, child: const Text('加入餐點')),
      ],
    );
  }
}
