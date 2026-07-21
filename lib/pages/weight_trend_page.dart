import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../database/database_helper.dart';
import '../models/weight_record.dart';
import '../models/weight_trend.dart';
import '../utils/local_date.dart';
import '../widgets/weight_entry_dialog.dart';

class WeightTrendPage extends StatefulWidget {
  final DateTime? todayOverride;
  final Future<List<WeightRecord>> Function()? loadRecords;
  final Future<void> Function(String date, double weight)? saveWeight;

  const WeightTrendPage({
    super.key,
    this.todayOverride,
    this.loadRecords,
    this.saveWeight,
  });

  @override
  State<WeightTrendPage> createState() => _WeightTrendPageState();
}

class _WeightTrendPageState extends State<WeightTrendPage> {
  List<WeightRecord>? allRecords;
  WeightTrendPeriod period = WeightTrendPeriod.thirtyDays;

  DateTime get today => localDateOnly(widget.todayOverride ?? DateTime.now());

  List<WeightRecord> get filteredRecords => filterWeightRecords(
    records: allRecords ?? const [],
    period: period,
    today: today,
  );

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final records =
        await (widget.loadRecords?.call() ??
            DatabaseHelper.instance.getWeightRecords());
    if (!mounted) return;
    setState(() => allRecords = records);
  }

  Future<void> _recordTodayWeight() async {
    final date = databaseDate(today);
    final todayRecord = allRecords
        ?.where((record) => record.date == date)
        .firstOrNull;
    final weight = await showDialog<double>(
      context: context,
      builder: (context) =>
          WeightEntryDialog(initialWeight: todayRecord?.weight),
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

  Widget _buildPeriodSelector() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: WeightTrendPeriod.values.map((option) {
        return ChoiceChip(
          key: ValueKey('weightPeriod_${option.name}'),
          label: Text(option.label),
          selected: period == option,
          onSelected: (_) => setState(() => period = option),
        );
      }).toList(),
    );
  }

  Widget _buildSummary(List<WeightRecord> records) {
    final summary = WeightTrendSummary.fromRecords(records);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('期間摘要', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Text(
              '第一筆：${WeightTrendSummary.formatWeight(summary.first?.weight)}',
            ),
            const SizedBox(height: 4),
            Text(
              '最新：${WeightTrendSummary.formatWeight(summary.latest?.weight)}',
            ),
            const SizedBox(height: 4),
            Text('變化：${summary.changeLabel}'),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyAll() {
    return Expanded(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.show_chart, size: 48),
            const SizedBox(height: 12),
            const Text('尚無體重紀錄'),
            const SizedBox(height: 8),
            const Text('先記錄今天的體重，就能開始查看趨勢。'),
            const SizedBox(height: 16),
            FilledButton.icon(
              key: const Key('emptyRecordWeightButton'),
              onPressed: _recordTodayWeight,
              icon: const Icon(Icons.add),
              label: const Text('記錄體重'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final records = allRecords;
    final filtered = filteredRecords;
    final todayDate = databaseDate(today);
    final hasTodayRecord =
        records?.any((record) => record.date == todayDate) ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('體重趨勢'),
        actions: [
          TextButton(
            key: const Key('trendRecordWeightButton'),
            onPressed: records == null ? null : _recordTodayWeight,
            child: Text(hasTodayRecord ? '修改今日體重' : '記錄體重'),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: records == null
            ? const Center(child: CircularProgressIndicator())
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (records.isNotEmpty) _buildPeriodSelector(),
                  if (records.isNotEmpty) const SizedBox(height: 16),
                  if (records.isEmpty)
                    _buildEmptyAll()
                  else if (filtered.isEmpty)
                    const Expanded(child: Center(child: Text('此期間尚無體重紀錄')))
                  else
                    Expanded(
                      child: ListView(
                        children: [
                          SizedBox(
                            height: 300,
                            child: WeightTrendChart(records: filtered),
                          ),
                          const SizedBox(height: 16),
                          _buildSummary(filtered),
                        ],
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}

class WeightTrendChart extends StatelessWidget {
  final List<WeightRecord> records;

  const WeightTrendChart({super.key, required this.records});

  static const _millisecondsPerDay = Duration.millisecondsPerDay;

  double _dateX(WeightRecord record) {
    return parseDatabaseDate(record.date).millisecondsSinceEpoch /
        _millisecondsPerDay;
  }

  String _formatNumber(num value) {
    return value.toStringAsFixed(6).replaceFirst(RegExp(r'\.?0+$'), '');
  }

  String _axisDate(double value) {
    final date = DateTime.fromMillisecondsSinceEpoch(
      (value * _millisecondsPerDay).round(),
    );
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$month/$day';
  }

  @override
  Widget build(BuildContext context) {
    final sorted = records.toList()..sort((a, b) => a.date.compareTo(b.date));
    final spots = sorted
        .map((record) => FlSpot(_dateX(record), record.weight))
        .toList();
    final weights = sorted.map((record) => record.weight);
    final dataMinY = weights.reduce(math.min);
    final dataMaxY = weights.reduce(math.max);
    final yRange = dataMaxY - dataMinY;
    final yPadding = yRange == 0 ? 1.0 : math.max(0.5, yRange * 0.15);
    final minY = dataMinY - yPadding;
    final maxY = dataMaxY + yPadding;
    final dataMinX = spots.first.x;
    final dataMaxX = spots.last.x;
    final minX = dataMinX == dataMaxX ? dataMinX - 1 : dataMinX;
    final maxX = dataMinX == dataMaxX ? dataMaxX + 1 : dataMaxX;
    final bottomInterval = math.max(1.0, (maxX - minX) / 3);
    final yInterval = math.max(0.5, (maxY - minY) / 4);
    final color = Theme.of(context).colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.only(right: 12, top: 16),
      child: LineChart(
        LineChartData(
          minX: minX,
          maxX: maxX,
          minY: minY,
          maxY: maxY,
          gridData: FlGridData(
            drawVerticalLine: false,
            horizontalInterval: yInterval,
          ),
          borderData: FlBorderData(
            show: true,
            border: Border(
              left: BorderSide(color: Theme.of(context).dividerColor),
              bottom: BorderSide(color: Theme.of(context).dividerColor),
            ),
          ),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 54,
                interval: yInterval,
                getTitlesWidget: (value, meta) => SideTitleWidget(
                  meta: meta,
                  child: Text(
                    '${_formatNumber(value)} kg',
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 32,
                interval: bottomInterval,
                getTitlesWidget: (value, meta) => SideTitleWidget(
                  meta: meta,
                  child: Text(
                    _axisDate(value),
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
              ),
            ),
          ),
          lineTouchData: LineTouchData(
            enabled: true,
            touchSpotThreshold: 24,
            touchTooltipData: LineTouchTooltipData(
              fitInsideHorizontally: true,
              fitInsideVertically: true,
              maxContentWidth: 180,
              getTooltipItems: (touchedSpots) => touchedSpots.map((spot) {
                final record = sorted[spot.spotIndex];
                final date = slashLocalDate(parseDatabaseDate(record.date));
                return LineTooltipItem(
                  '$date・${_formatNumber(record.weight)} kg',
                  const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                );
              }).toList(),
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: false,
              color: color,
              barWidth: 3,
              dotData: FlDotData(
                show: true,
                getDotPainter: (_, _, _, _) => FlDotCirclePainter(
                  radius: 4,
                  color: color,
                  strokeWidth: 2,
                  strokeColor: Theme.of(context).colorScheme.surface,
                ),
              ),
              belowBarData: BarAreaData(
                show: true,
                color: color.withValues(alpha: 0.12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
