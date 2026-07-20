import 'package:flutter/material.dart';

import '../database/database_helper.dart';
import '../models/nutrition_goal.dart';
import '../utils/local_date.dart';

class NutritionGoalPage extends StatefulWidget {
  final DateTime? todayOverride;
  final NutritionGoal? initialGoal;
  final Future<void> Function(NutritionGoal goal)? saveGoal;

  const NutritionGoalPage({
    super.key,
    this.todayOverride,
    this.initialGoal,
    this.saveGoal,
  });

  @override
  State<NutritionGoalPage> createState() => _NutritionGoalPageState();
}

class _NutritionGoalPageState extends State<NutritionGoalPage> {
  final formKey = GlobalKey<FormState>();
  late final TextEditingController calorieController;
  late final TextEditingController proteinController;
  late DateTime effectiveDate;
  bool isSaving = false;

  DateTime get today => localDateOnly(widget.todayOverride ?? DateTime.now());

  @override
  void initState() {
    super.initState();
    effectiveDate = today;
    calorieController = TextEditingController(
      text: _formatNumber(widget.initialGoal?.calorieTarget ?? 1600),
    );
    proteinController = TextEditingController(
      text: _formatNumber(widget.initialGoal?.proteinTarget ?? 100),
    );
  }

  String _formatNumber(num value) {
    return value.toStringAsFixed(6).replaceFirst(RegExp(r'\.?0+$'), '');
  }

  @override
  void dispose() {
    calorieController.dispose();
    proteinController.dispose();
    super.dispose();
  }

  String? _validateCalories(String? input) {
    final value = double.tryParse(input?.trim() ?? '');
    if (value == null || !value.isFinite) return '請輸入有效的每日熱量目標';
    if (value < 100 || value > 10000) {
      return '每日熱量目標必須介於 100–10000 kcal';
    }
    return null;
  }

  String? _validateProtein(String? input) {
    final value = double.tryParse(input?.trim() ?? '');
    if (value == null || !value.isFinite) return '請輸入有效的每日蛋白質目標';
    if (value < 1 || value > 1000) {
      return '每日蛋白質目標必須介於 1–1000 g';
    }
    return null;
  }

  Future<void> _pickEffectiveDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: effectiveDate,
      firstDate: today,
      lastDate: DateTime(today.year + 100, 12, 31),
    );
    if (picked != null) {
      setState(() => effectiveDate = localDateOnly(picked));
    }
  }

  Future<void> _save() async {
    if (!(formKey.currentState?.validate() ?? false)) return;
    setState(() => isSaving = true);
    final goal = NutritionGoal(
      effectiveDate: databaseDate(effectiveDate),
      calorieTarget: double.parse(calorieController.text.trim()),
      proteinTarget: double.parse(proteinController.text.trim()),
    );
    final saver = widget.saveGoal;
    if (saver != null) {
      await saver(goal);
    } else {
      await DatabaseHelper.instance.saveNutritionGoal(goal);
    }
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('營養目標設定')),
      body: Form(
        key: formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              '目標不會隨體重自動變更',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              widget.initialGoal == null
                  ? '目前顯示建議值；完成儲存前尚未建立目標。'
                  : '修改後會從指定生效日期起套用，不影響更早日期。',
              style: TextStyle(color: Theme.of(context).colorScheme.secondary),
            ),
            const SizedBox(height: 20),
            TextFormField(
              key: const Key('calorieTargetField'),
              controller: calorieController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: '每日熱量目標（kcal）',
                border: OutlineInputBorder(),
              ),
              validator: _validateCalories,
            ),
            const SizedBox(height: 16),
            TextFormField(
              key: const Key('proteinTargetField'),
              controller: proteinController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: '每日蛋白質目標（g）',
                border: OutlineInputBorder(),
              ),
              validator: _validateProtein,
            ),
            const SizedBox(height: 16),
            ListTile(
              key: const Key('effectiveDatePicker'),
              contentPadding: EdgeInsets.zero,
              title: const Text('生效日期'),
              subtitle: Text(databaseDate(effectiveDate)),
              trailing: const Icon(Icons.calendar_today),
              onTap: _pickEffectiveDate,
            ),
            const SizedBox(height: 20),
            FilledButton(
              key: const Key('saveNutritionGoalButton'),
              onPressed: isSaving ? null : _save,
              child: const Text('儲存目標'),
            ),
          ],
        ),
      ),
    );
  }
}
