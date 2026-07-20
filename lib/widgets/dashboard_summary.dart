import 'package:flutter/material.dart';

class DashboardSummary extends StatelessWidget {
  final double totalCalories;
  final double totalProtein;

  const DashboardSummary({
    super.key,
    required this.totalCalories,
    required this.totalProtein,
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
          ],
        ),
      ),
    );
  }
}
