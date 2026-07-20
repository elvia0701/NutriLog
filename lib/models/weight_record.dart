class WeightRecord {
  final int? id;
  final String date;
  final double weight;

  const WeightRecord({this.id, required this.date, required this.weight});

  Map<String, dynamic> toMap() {
    return {'id': id, 'date': date, 'weight': weight};
  }

  factory WeightRecord.fromMap(Map<String, dynamic> map) {
    return WeightRecord(
      id: map['id'] as int?,
      date: map['date'] as String,
      weight: (map['weight'] as num).toDouble(),
    );
  }
}
