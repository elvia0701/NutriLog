import 'package:flutter/material.dart';

import '../models/food.dart';
import '../models/meal_record.dart';
import '../repositories/food_repository.dart';
import '../repositories/meal_repository.dart';
import 'add_food_page.dart';

class FoodDatabasePage extends StatefulWidget {
  final String mealType;
  final String date;
  final FoodRepository foodRepository;
  final MealRepository mealRepository;

  const FoodDatabasePage({
    super.key,
    required this.mealType,
    required this.date,
    required this.foodRepository,
    required this.mealRepository,
  });

  @override
  State<FoodDatabasePage> createState() => _FoodDatabasePageState();
}

class _FoodDatabasePageState extends State<FoodDatabasePage> {
  List<Food> _foods = [];
  String _query = '';
  bool _isLoading = true;
  bool _isMutating = false;
  Object? _loadError;
  String? _loadErrorMessage;

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
    return widget.foodRepository.getFoods();
  }

  Future<Food> _createFood(Food food) {
    return widget.foodRepository.insertFood(food);
  }

  Future<int> _updateFood(Food food) {
    return widget.foodRepository.updateFood(food);
  }

  Future<MealRecord> _createMealRecord(MealRecord mealRecord) {
    return widget.mealRepository.insertMealRecord(mealRecord);
  }

  Future<int> _getFoodReferenceCount(Food food) {
    return widget.foodRepository.getFoodReferenceCount(food);
  }

  Future<FoodRemovalResult> _removeFood(Food food) {
    return widget.foodRepository.removeFood(food);
  }

  Future<void> _loadFoods() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _loadError = null;
        _loadErrorMessage = null;
      });
    }

    List<Food>? foods;
    Object? loadError;
    try {
      foods = await _getFoods();
    } catch (error, stackTrace) {
      loadError = error;
      debugPrint('FoodDatabasePage failed to load foods: $error');
      debugPrintStack(stackTrace: stackTrace);
    } finally {
      if (mounted) {
        setState(() {
          if (loadError == null && foods != null) {
            _foods = foods;
          }
          _loadError = loadError;
          _loadErrorMessage = _messageForError(loadError);
          _isLoading = false;
        });
      }
    }
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
    if (food.id == null && food.cloudId == null) {
      throw const MealRepositoryException(
        MealRepositoryFailureKind.invalidData,
        '食品識別資料不完整，請重新載入食品後再試。',
      );
    }
    await _createMealRecord(
      MealRecord(
        date: widget.date,
        mealType: widget.mealType,
        foodId: food.id,
        foodCloudId: food.cloudId,
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
    if (food.id == null && food.cloudId == null) return;

    final servings = await _askForServings(food);
    if (servings == null) return;

    var saved = false;
    await _runMutation(() async {
      await _saveMealRecord(food: food, servings: servings);
      saved = true;
    });
    if (saved && mounted) Navigator.pop(context, true);
  }

  Future<void> _createAndAddFood() async {
    final result = await Navigator.push<AddFoodResult>(
      context,
      MaterialPageRoute(
        builder: (context) => AddFoodPage(mealType: widget.mealType),
      ),
    );
    if (result == null) return;

    await _runMutation(() async {
      final createdFood = await _createFood(result.food);
      await _saveMealRecord(food: createdFood, servings: result.servings);
      if (!mounted) return;
      Navigator.pop(context, true);
    });
  }

  Future<void> _editFood(Food food) async {
    final result = await Navigator.push<AddFoodResult>(
      context,
      MaterialPageRoute(builder: (context) => AddFoodPage(initialFood: food)),
    );
    if (result == null) return;
    await _runMutation(() async {
      await _updateFood(result.food);
      await _loadFoods();
      if (mounted) _showMessage('食物已更新。');
    });
  }

  Future<void> _toggleFavorite(Food food) async {
    await _runMutation(() async {
      await _updateFood(food.copyWith(favorite: !food.favorite));
      await _loadFoods();
    });
  }

  Future<void> _confirmAndRemoveFood(Food food) async {
    if (food.id == null && food.cloudId == null) return;

    int referenceCount;
    try {
      referenceCount = await _getFoodReferenceCount(food);
    } catch (error, stackTrace) {
      debugPrint('FoodDatabasePage failed to check food references: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (mounted) _showMessage(_messageForError(error));
      return;
    }
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

    FoodRemovalResult? result;
    await _runMutation(() async {
      result = await _removeFood(food);
    });
    if (!mounted || result == null) return;

    if (result == FoodRemovalResult.notFound) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('找不到這項食物，列表將重新整理。')));
      await _loadFoods();
      return;
    }

    setState(() {
      _foods.removeWhere(
        (item) => item.id == food.id && item.cloudId == food.cloudId,
      );
    });

    if (result == FoodRemovalResult.archived) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('食物已封存，歷史餐點仍會保留。')));
    }
  }

  Future<void> _runMutation(Future<void> Function() action) async {
    if (_isMutating) return;
    if (mounted) setState(() => _isMutating = true);
    try {
      await action();
    } catch (error, stackTrace) {
      debugPrint('FoodDatabasePage food operation failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (mounted) _showMessage(_messageForError(error));
    } finally {
      if (mounted) setState(() => _isMutating = false);
    }
  }

  String _messageForError(Object? error) {
    if (error is FoodRepositoryException) return error.message;
    if (error is MealRepositoryException) return error.message;
    return '無法存取食物資料，請稍後再試。';
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
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

  Widget _buildLoadError() {
    final message = _loadErrorMessage ?? '無法載入食物資料，請稍後再試。';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_outlined,
              size: 48,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              '無法載入食物資料',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 20),
            FilledButton.icon(
              key: const Key('retryLoadFoodsButton'),
              onPressed: _loadFoods,
              icon: const Icon(Icons.refresh),
              label: const Text('重新載入'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadedContent() {
    final filteredFoods = _filteredFoods;
    return Padding(
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
              onPressed: _isMutating ? null : _createAndAddFood,
              icon: const Icon(Icons.add),
              label: const Text('建立新食物'),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _foods.isEmpty
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
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              key: ValueKey(
                                'favorite_food_${food.id ?? food.cloudId}',
                              ),
                              onPressed: _isMutating
                                  ? null
                                  : () => _toggleFavorite(food),
                              tooltip: food.favorite ? '取消常用' : '標記為常用',
                              icon: Icon(
                                food.favorite
                                    ? Icons.star
                                    : Icons.star_border_outlined,
                              ),
                            ),
                            IconButton(
                              key: ValueKey(
                                'edit_food_${food.id ?? food.cloudId}',
                              ),
                              onPressed:
                                  _isMutating ||
                                      (food.id == null && food.cloudId == null)
                                  ? null
                                  : () => _editFood(food),
                              tooltip: '編輯食物',
                              icon: const Icon(Icons.edit_outlined),
                            ),
                            IconButton(
                              key: ValueKey(
                                'delete_food_${food.id ?? food.cloudId}',
                              ),
                              onPressed:
                                  _isMutating ||
                                      (food.id == null && food.cloudId == null)
                                  ? null
                                  : () => _confirmAndRemoveFood(food),
                              tooltip: '移除食物',
                              icon: const Icon(Icons.delete_outline),
                            ),
                          ],
                        ),
                        onTap: () => _selectFood(food),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('食物資料庫')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
          ? _buildLoadError()
          : _buildLoadedContent(),
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
