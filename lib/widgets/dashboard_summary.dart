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

  @override
  Widget build(BuildContext context) {
    final currentGoal = goal;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _NutritionMetricCard(
                label: '剩餘熱量',
                consumed: totalCalories,
                target: currentGoal?.calorieTarget,
                unit: 'kcal',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _NutritionMetricCard(
                label: '剩餘蛋白質',
                consumed: totalProtein,
                target: currentGoal?.proteinTarget,
                unit: 'g',
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: Tooltip(
            message: '營養目標設定',
            child: TextButton.icon(
              key: const Key('nutritionGoalSettingsButton'),
              onPressed: onOpenGoalSettings,
              icon: const Icon(Icons.settings_outlined, size: 19),
              label: Text(currentGoal == null ? '設定營養目標' : '目標設定'),
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        _WeightCard(
          weight: weight,
          canEdit: canEditWeight,
          onEdit: onEditWeight,
          onDelete: onDeleteWeight,
          onOpenHistory: onOpenWeightHistory,
          formatNumber: _formatNumber,
        ),
      ],
    );
  }
}

class _NutritionMetricCard extends StatelessWidget {
  final String label;
  final double consumed;
  final double? target;
  final String unit;

  const _NutritionMetricCard({
    required this.label,
    required this.consumed,
    required this.target,
    required this.unit,
  });

  String _formatNumber(num value) {
    return value.toStringAsFixed(6).replaceFirst(RegExp(r'\.?0+$'), '');
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final metricTarget = target;
    final isOver = metricTarget != null && consumed > metricTarget;
    final remaining = metricTarget == null ? null : metricTarget - consumed;
    final progress = metricTarget == null
        ? 0.0
        : (consumed / metricTarget).clamp(0.0, 1.0).toDouble();
    final prominentText = metricTarget == null
        ? '尚未設定目標'
        : isOver
        ? '超出 ${_formatNumber(-remaining!)} $unit'
        : '${_formatNumber(remaining!)} $unit';
    final supportingText = metricTarget == null
        ? '已攝取 ${_formatNumber(consumed)} $unit'
        : '${_formatNumber(consumed)} / ${_formatNumber(metricTarget)} $unit';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  prominentText,
                  maxLines: 1,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: isOver ? colors.error : colors.primary,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                supportingText,
                maxLines: 1,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
              ),
            ),
            const SizedBox(height: 10),
            LinearProgressIndicator(
              value: progress,
              minHeight: 7,
              borderRadius: BorderRadius.circular(99),
              color: isOver ? colors.error : colors.primary,
              backgroundColor: colors.surfaceContainerHighest,
            ),
          ],
        ),
      ),
    );
  }
}

class _WeightCard extends StatelessWidget {
  final double? weight;
  final bool canEdit;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onOpenHistory;
  final String Function(num value) formatNumber;

  const _WeightCard({
    required this.weight,
    required this.canEdit,
    required this.onEdit,
    required this.onDelete,
    required this.onOpenHistory,
    required this.formatNumber,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('當日體重', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(
              weight == null ? '尚未記錄' : '${formatNumber(weight!)} kg',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(color: colors.onSurface),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                if (canEdit)
                  TextButton.icon(
                    key: const Key('editWeightButton'),
                    onPressed: onEdit,
                    icon: Icon(
                      weight == null ? Icons.add : Icons.edit_outlined,
                      size: 19,
                    ),
                    label: Text(weight == null ? '記錄體重' : '修改體重'),
                  ),
                TextButton.icon(
                  key: const Key('weightHistoryButton'),
                  onPressed: onOpenHistory,
                  icon: const Icon(Icons.history, size: 19),
                  label: const Text('體重歷史'),
                ),
                if (canEdit && weight != null)
                  IconButton(
                    key: const Key('deleteWeightButton'),
                    onPressed: onDelete,
                    tooltip: '刪除體重紀錄',
                    color: colors.onSurfaceVariant,
                    icon: const Icon(Icons.delete_outline, size: 20),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
