import '../models/weight_record.dart';

abstract interface class WeightRepository {
  Future<WeightRecord?> getWeightForDate(String date);

  Future<List<WeightRecord>> getWeightHistory();

  Future<void> saveWeight(String date, double weight);

  Future<void> deleteWeight(String date);
}
