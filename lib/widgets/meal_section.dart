import 'package:flutter/material.dart';

import '../models/meal_item.dart';
import '../pages/food_database_page.dart';
import '../repositories/food_repository.dart';
import '../repositories/meal_repository.dart';

class MealSection extends StatelessWidget {
  final String title;
  final String mealType;
  final String date;
  final bool canEdit;
  final FoodRepository foodRepository;
  final MealRepository mealRepository;
  final List<MealItem> items;
  final Future<void> Function() onMealAdded;
  final Future<void> Function(MealItem item) onDelete;
  final bool mealActionsEnabled;

  const MealSection({
    super.key,
    required this.title,
    required this.mealType,
    required this.date,
    required this.canEdit,
    required this.foodRepository,
    required this.mealRepository,
    required this.items,
    required this.onMealAdded,
    required this.onDelete,
    this.mealActionsEnabled = true,
  });

  String _formatNumber(num value) {
    return value.toStringAsFixed(6).replaceFirst(RegExp(r'\.?0+$'), '');
  }

  Future<void> _confirmDelete(BuildContext context, MealItem item) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('刪除餐點紀錄？'),
        content: Text('確定要刪除「${item.foodName}」嗎？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('刪除'),
          ),
        ],
      ),
    );

    if (shouldDelete == true) await onDelete(item);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$title・${items.length} 項', style: textTheme.titleMedium),
            const SizedBox(height: 12),
            if (items.isEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  '尚無餐點',
                  style: textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              )
            else
              for (var index = 0; index < items.length; index++) ...[
                _MealItemRow(
                  item: items[index],
                  canEdit: canEdit,
                  nutritionText:
                      '${_formatNumber(items[index].servings)} 份・'
                      '${_formatNumber(items[index].totalCalories)} kcal・'
                      '${_formatNumber(items[index].totalProtein)} g 蛋白質',
                  onDelete: () => _confirmDelete(context, items[index]),
                ),
                if (index != items.length - 1) const Divider(height: 17),
              ],
            if (items.isNotEmpty) const SizedBox(height: 12),
            if (canEdit)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final added = await Navigator.push<bool>(
                      context,
                      MaterialPageRoute(
                        builder: (context) => FoodDatabasePage(
                          mealType: mealType,
                          date: date,
                          foodRepository: foodRepository,
                          mealRepository: mealRepository,
                          mealActionsEnabled: mealActionsEnabled,
                        ),
                      ),
                    );
                    if (added == true) await onMealAdded();
                  },
                  icon: const Icon(Icons.add, size: 20),
                  label: const Text('新增餐點'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MealItemRow extends StatelessWidget {
  final MealItem item;
  final bool canEdit;
  final String nutritionText;
  final VoidCallback onDelete;

  const _MealItemRow({
    required this.item,
    required this.canEdit,
    required this.nutritionText,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.foodName,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 3),
                Text(
                  nutritionText,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          if (canEdit)
            IconButton(
              onPressed: onDelete,
              tooltip: '刪除餐點',
              color: colors.onSurfaceVariant,
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.delete_outline, size: 20),
            ),
        ],
      ),
    );
  }
}
