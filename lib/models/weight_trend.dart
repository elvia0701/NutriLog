import '../utils/local_date.dart';
import 'weight_record.dart';

enum WeightTrendPeriod { sevenDays, thirtyDays, ninetyDays, all }

extension WeightTrendPeriodDetails on WeightTrendPeriod {
  String get label => switch (this) {
    WeightTrendPeriod.sevenDays => '7 天',
    WeightTrendPeriod.thirtyDays => '30 天',
    WeightTrendPeriod.ninetyDays => '90 天',
    WeightTrendPeriod.all => '全部',
  };

  int? get dayCount => switch (this) {
    WeightTrendPeriod.sevenDays => 7,
    WeightTrendPeriod.thirtyDays => 30,
    WeightTrendPeriod.ninetyDays => 90,
    WeightTrendPeriod.all => null,
  };
}

List<WeightRecord> filterWeightRecords({
  required List<WeightRecord> records,
  required WeightTrendPeriod period,
  required DateTime today,
}) {
  final localToday = localDateOnly(today);
  final dayCount = period.dayCount;
  final startDate = dayCount == null
      ? null
      : DateTime(
          localToday.year,
          localToday.month,
          localToday.day - (dayCount - 1),
        );

  final filtered = records.where((record) {
    if (startDate == null) return true;
    final date = parseDatabaseDate(record.date);
    return !date.isBefore(startDate) && !date.isAfter(localToday);
  }).toList()..sort((a, b) => a.date.compareTo(b.date));
  return filtered;
}

class WeightTrendSummary {
  final WeightRecord? first;
  final WeightRecord? latest;

  const WeightTrendSummary({required this.first, required this.latest});

  factory WeightTrendSummary.fromRecords(List<WeightRecord> records) {
    if (records.isEmpty) {
      return const WeightTrendSummary(first: null, latest: null);
    }
    final sorted = records.toList()..sort((a, b) => a.date.compareTo(b.date));
    return WeightTrendSummary(first: sorted.first, latest: sorted.last);
  }

  String get changeLabel {
    if (first == null || latest == null || first == latest) {
      return '資料不足，尚無法計算變化';
    }
    final change = latest!.weight - first!.weight;
    if (change == 0) return '持平';
    final amount = _formatNumber(change.abs());
    return change < 0 ? '下降 $amount kg' : '上升 $amount kg';
  }

  static String formatWeight(double? value) {
    return value == null ? '—' : '${_formatNumber(value)} kg';
  }

  static String _formatNumber(num value) {
    return value.toStringAsFixed(6).replaceFirst(RegExp(r'\.?0+$'), '');
  }
}
