import 'package:flutter/material.dart';

import '../models/nutrition_goal.dart';

class DashboardSummary extends StatelessWidget {
  final double totalCalories;
  final double totalProtein;
  final NutritionGoal? goal;
  final VoidCallback? onOpenGoalSettings;
  final double? weight;
  final bool canEditWeight;
  final VoidCallback? onEditWeight;
  final VoidCallback? onDeleteWeight;
  final VoidCallback? onOpenWeightHistory;

  const DashboardSummary({
    super.key,
    required this.totalCalories,
    required this.totalProtein,
    this.goal,
    this.onOpenGoalSettings,
    this.weight,
    this.canEditWeight = false,
    this.onEditWeight,
    this.onDeleteWeight,
    this.onOpenWeightHistory,
  });

  String _formatNumber(num value) {
    return value.toStringAsFixed(6).replaceFirst(RegExp(r'\.?0+$'), '');
  }

  Widget _buildNutritionSummary() {
    final currentGoal = goal;
    if (currentGoal == null) {
      return Column(
        children: [
          Text(
            '🔥 熱量：已攝取 ${_formatNumber(totalCalories)} kcal',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Text(
            '🥩 蛋白質：已攝取 ${_formatNumber(totalProtein)} g',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          const Text('尚未設定目標'),
        ],
      );
    }

    final calorieDifference = currentGoal.calorieTarget - totalCalories;
    final proteinDifference = currentGoal.proteinTarget - totalProtein;
    return Column(
      children: [
        Text(
          '🔥 熱量：${_formatNumber(totalCalories)} / '
          '${_formatNumber(currentGoal.calorieTarget)} kcal',
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Text(
          '🥩 蛋白質：${_formatNumber(totalProtein)} / '
          '${_formatNumber(currentGoal.proteinTarget)} g',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        Text(
          calorieDifference >= 0
              ? '剩餘熱量：${_formatNumber(calorieDifference)} kcal'
              : '超出熱量：${_formatNumber(-calorieDifference)} kcal',
        ),
        const SizedBox(height: 4),
        Text(
          proteinDifference >= 0
              ? '剩餘蛋白質：${_formatNumber(proteinDifference)} g'
              : '超出蛋白質：${_formatNumber(-proteinDifference)} g',
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildNutritionSummary(),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                key: const Key('nutritionGoalSettingsButton'),
                onPressed: onOpenGoalSettings,
                icon: const Icon(Icons.tune),
                label: const Text('營養目標設定'),
              ),
            ),
            const Divider(height: 28),
            Row(
              children: [
                Expanded(
                  child: Text(
                    weight == null
                        ? '⚖️ 體重：尚未記錄'
                        : '⚖️ 體重：${_formatNumber(weight!)} kg',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (canEditWeight)
                  TextButton(
                    key: const Key('editWeightButton'),
                    onPressed: onEditWeight,
                    child: Text(weight == null ? '記錄體重' : '修改體重'),
                  ),
                if (canEditWeight && weight != null)
                  IconButton(
                    key: const Key('deleteWeightButton'),
                    onPressed: onDeleteWeight,
                    tooltip: '刪除體重紀錄',
                    icon: const Icon(Icons.delete_outline),
                  ),
              ],
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                key: const Key('weightHistoryButton'),
                onPressed: onOpenWeightHistory,
                icon: const Icon(Icons.history),
                label: const Text('體重歷史'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
