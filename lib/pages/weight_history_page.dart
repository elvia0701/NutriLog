import 'package:flutter/material.dart';

import '../database/database_helper.dart';
import '../models/weight_record.dart';

class WeightHistoryPage extends StatefulWidget {
  final Future<List<WeightRecord>> Function()? loadRecords;

  const WeightHistoryPage({super.key, this.loadRecords});

  @override
  State<WeightHistoryPage> createState() => _WeightHistoryPageState();
}

class _WeightHistoryPageState extends State<WeightHistoryPage> {
  List<WeightRecord>? records;

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

  String _formatNumber(num value) {
    return value.toStringAsFixed(1).replaceFirst(RegExp(r'\.0$'), '');
  }

  @override
  Widget build(BuildContext context) {
    final loadedRecords = records;
    return Scaffold(
      appBar: AppBar(title: const Text('體重歷史')),
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
