import 'package:flutter/material.dart';

import '../database/database_helper.dart';
import '../models/food.dart';
import '../models/meal_record.dart';
import 'add_food_page.dart';

class FoodDatabasePage extends StatefulWidget {
  final String mealType;
  final Future<List<Food>> Function()? loadFoods;
  final Future<int> Function(Food food)? insertFood;
  final Future<int> Function(MealRecord mealRecord)? insertMealRecord;

  const FoodDatabasePage({
    super.key,
    required this.mealType,
    this.loadFoods,
    this.insertFood,
    this.insertMealRecord,
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
    required int foodId,
    required double servings,
  }) async {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    await _createMealRecord(
      MealRecord(
        date: today,
        mealType: widget.mealType,
        foodId: foodId,
        servings: servings,
      ),
    );
  }

  Future<void> _selectFood(Food food) async {
    final foodId = food.id;
    if (foodId == null) return;

    final servings = await _askForServings(food);
    if (servings == null) return;

    await _saveMealRecord(foodId: foodId, servings: servings);
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
    await _saveMealRecord(foodId: foodId, servings: result.servings);
    if (!mounted) return;
    Navigator.pop(context, true);
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
                          trailing: const Icon(Icons.chevron_right),
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
