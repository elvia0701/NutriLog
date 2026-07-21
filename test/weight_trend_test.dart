import 'package:flutter_test/flutter_test.dart';

import 'package:nutrilog/models/weight_record.dart';
import 'package:nutrilog/models/weight_trend.dart';
import 'package:nutrilog/utils/local_date.dart';

WeightRecord record(DateTime date, double weight) {
  return WeightRecord(date: databaseDate(date), weight: weight);
}

void main() {
  final today = DateTime(2026, 7, 21);

  test('7 day period includes today and previous 6 local dates', () {
    final filtered = filterWeightRecords(
      records: [
        record(DateTime(2026, 7, 14), 92),
        record(DateTime(2026, 7, 15), 91.5),
        record(DateTime(2026, 7, 21), 90.5),
        record(DateTime(2026, 7, 22), 90),
      ],
      period: WeightTrendPeriod.sevenDays,
      today: today,
    );

    expect(filtered.map((item) => item.date), ['2026-07-15', '2026-07-21']);
  });

  test('30 day period includes today and previous 29 local dates', () {
    final filtered = filterWeightRecords(
      records: [
        record(DateTime(2026, 6, 21), 93),
        record(DateTime(2026, 6, 22), 92.5),
        record(DateTime(2026, 7, 21), 90.5),
      ],
      period: WeightTrendPeriod.thirtyDays,
      today: today,
    );

    expect(filtered.map((item) => item.date), ['2026-06-22', '2026-07-21']);
  });

  test('90 day period includes today and previous 89 local dates', () {
    final start = DateTime(today.year, today.month, today.day - 89);
    final beforeStart = DateTime(start.year, start.month, start.day - 1);
    final filtered = filterWeightRecords(
      records: [
        record(beforeStart, 94),
        record(start, 93.5),
        record(today, 90.5),
      ],
      period: WeightTrendPeriod.ninetyDays,
      today: today,
    );

    expect(filtered.map((item) => item.date), [
      databaseDate(start),
      databaseDate(today),
    ]);
  });

  test('filtered results are oldest first and do not invent missing dates', () {
    final filtered = filterWeightRecords(
      records: [
        record(DateTime(2026, 7, 21), 90.5),
        record(DateTime(2026, 7, 17), 91),
      ],
      period: WeightTrendPeriod.sevenDays,
      today: today,
    );

    expect(filtered, hasLength(2));
    expect(filtered.map((item) => item.date), ['2026-07-17', '2026-07-21']);
    expect(filtered.map((item) => item.weight), [91, 90.5]);
  });

  test('all period keeps every record and sorts it oldest first', () {
    final filtered = filterWeightRecords(
      records: [
        record(DateTime(2026, 7, 21), 90.5),
        record(DateTime(2025, 1, 1), 100),
        record(DateTime(2026, 7, 22), 90),
      ],
      period: WeightTrendPeriod.all,
      today: today,
    );

    expect(filtered.map((item) => item.date), [
      '2025-01-01',
      '2026-07-21',
      '2026-07-22',
    ]);
  });

  test('summary reports decrease, increase, unchanged, and single record', () {
    expect(
      WeightTrendSummary.fromRecords([
        record(DateTime(2026, 7, 1), 92.8),
        record(DateTime(2026, 7, 21), 90.5),
      ]).changeLabel,
      '下降 2.3 kg',
    );
    expect(
      WeightTrendSummary.fromRecords([
        record(DateTime(2026, 7, 1), 90),
        record(DateTime(2026, 7, 21), 91.2),
      ]).changeLabel,
      '上升 1.2 kg',
    );
    expect(
      WeightTrendSummary.fromRecords([
        record(DateTime(2026, 7, 1), 90),
        record(DateTime(2026, 7, 21), 90),
      ]).changeLabel,
      '持平',
    );
    expect(
      WeightTrendSummary.fromRecords([
        record(DateTime(2026, 7, 21), 90),
      ]).changeLabel,
      '資料不足，尚無法計算變化',
    );
  });
}
