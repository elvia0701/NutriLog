import 'package:flutter/material.dart';
import '../pages/food_database_page.dart';
import '../models/meal_item.dart';

class MealSection extends StatelessWidget {
  final String title;
  final String mealType;
  final String date;
  final bool canEdit;
  final List<MealItem> items;
  final Future<void> Function() onMealAdded;
  final Future<void> Function(MealItem item) onDelete;

  const MealSection({
    super.key,
    required this.title,
    required this.mealType,
    required this.date,
    required this.canEdit,
    required this.items,
    required this.onMealAdded,
    required this.onDelete,
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

    if (shouldDelete == true) {
      await onDelete(item);
    }
  }

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
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            if (items.isEmpty)
              const Text('尚無紀錄', style: TextStyle(color: Colors.grey))
            else
              ...items.map(
                (item) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(item.foodName),
                  subtitle: Text(
                    '${_formatNumber(item.servings)} 份 • '
                    '${_formatNumber(item.totalCalories)} kcal • '
                    '${_formatNumber(item.totalProtein)} g',
                  ),
                  trailing: canEdit
                      ? IconButton(
                          onPressed: () => _confirmDelete(context, item),
                          tooltip: '刪除餐點',
                          icon: const Icon(Icons.delete_outline),
                        )
                      : null,
                ),
              ),
            if (canEdit)
              OutlinedButton.icon(
                onPressed: () async {
                  final added = await Navigator.push<bool>(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          FoodDatabasePage(mealType: mealType, date: date),
                    ),
                  );

                  if (added == true) {
                    await onMealAdded();
                  }
                },
                icon: const Icon(Icons.add),
                label: const Text('新增餐點'),
              ),
          ],
        ),
      ),
    );
  }
}
