import 'package:flutter/material.dart';

import '../database/database_helper.dart';
import '../models/weight_record.dart';
import '../utils/local_date.dart';
import '../widgets/weight_entry_dialog.dart';
import 'weight_trend_page.dart';

class WeightHistoryPage extends StatefulWidget {
  final Future<List<WeightRecord>> Function()? loadRecords;
  final Future<void> Function(String date, double weight)? saveWeight;
  final DateTime? todayOverride;
  final Future<DateTime?> Function(DateTime today)? pickBackfillDate;

  const WeightHistoryPage({
    super.key,
    this.loadRecords,
    this.saveWeight,
    this.todayOverride,
    this.pickBackfillDate,
  });

  @override
  State<WeightHistoryPage> createState() => _WeightHistoryPageState();
}

class _WeightHistoryPageState extends State<WeightHistoryPage> {
  List<WeightRecord>? records;

  DateTime get today => localDateOnly(widget.todayOverride ?? DateTime.now());

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final loaded =
        await (widget.loadRecords?.call() ??
            DatabaseHelper.instance.getWeightRecords());
    if (!mounted) return;
    setState(() {
      records = loaded.toList()..sort((a, b) => b.date.compareTo(a.date));
    });
  }

  Future<void> _openTrend() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (context) => WeightTrendPage(
          todayOverride: widget.todayOverride,
          loadRecords: widget.loadRecords,
          saveWeight: widget.saveWeight,
        ),
      ),
    );
    await _load();
  }

  Future<DateTime?> _pickDate() {
    final picker = widget.pickBackfillDate;
    if (picker != null) return picker(today);
    return showDatePicker(
      context: context,
      initialDate: today,
      firstDate: DateTime(1900),
      lastDate: today,
    );
  }

  Future<void> _backfillWeight() async {
    final selected = await _pickDate();
    if (selected == null || !mounted) return;
    final localSelected = localDateOnly(selected);
    if (localSelected.isAfter(today)) return;
    final date = databaseDate(localSelected);
    final matching = records
        ?.where((record) => record.date == date)
        .firstOrNull;

    if (matching != null) {
      final shouldUpdate = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('此日期已有體重紀錄'),
          content: Text('$date 已記錄 ${_formatNumber(matching.weight)} kg，是否更新？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('確認更新'),
            ),
          ],
        ),
      );
      if (shouldUpdate != true || !mounted) return;
    }

    final weight = await showDialog<double>(
      context: context,
      builder: (context) => WeightEntryDialog(initialWeight: matching?.weight),
    );
    if (weight == null) return;

    final saver = widget.saveWeight;
    if (saver != null) {
      await saver(date, weight);
    } else {
      await DatabaseHelper.instance.saveWeightRecord(date, weight);
    }
    await _load();
  }

  String _formatNumber(num value) {
    return value.toStringAsFixed(1).replaceFirst(RegExp(r'\.0$'), '');
  }

  @override
  Widget build(BuildContext context) {
    final loadedRecords = records;
    return Scaffold(
      appBar: AppBar(
        title: const Text('體重歷史'),
        actions: [
          TextButton.icon(
            key: const Key('openWeightTrendButton'),
            onPressed: _openTrend,
            icon: const Icon(Icons.show_chart),
            label: const Text('查看趨勢'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('backfillWeightButton'),
        onPressed: records == null ? null : _backfillWeight,
        icon: const Icon(Icons.add),
        label: const Text('補登體重'),
      ),
      body: loadedRecords == null
          ? const Center(child: CircularProgressIndicator())
          : loadedRecords.isEmpty
          ? const Center(child: Text('尚無體重紀錄'))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: loadedRecords.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final record = loadedRecords[index];
                return ListTile(
                  key: ValueKey('weight_${record.date}'),
                  leading: const Icon(Icons.monitor_weight_outlined),
                  title: Text(record.date),
                  trailing: Text(
                    '${_formatNumber(record.weight)} kg',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                );
              },
            ),
    );
  }
}
