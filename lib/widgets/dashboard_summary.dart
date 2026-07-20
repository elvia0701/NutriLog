import 'package:flutter/material.dart';

class DashboardSummary extends StatelessWidget {
  final double totalCalories;
  final double totalProtein;
  final double? weight;
  final bool canEditWeight;
  final VoidCallback? onEditWeight;
  final VoidCallback? onDeleteWeight;
  final VoidCallback? onOpenWeightHistory;

  const DashboardSummary({
    super.key,
    required this.totalCalories,
    required this.totalProtein,
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
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              '🔥 ${_formatNumber(totalCalories)} / 1600 kcal',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 12),

            Text(
              '🥩 ${_formatNumber(totalProtein)} / 100 g',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
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
