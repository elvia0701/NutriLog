import '../database/database_helper.dart';
import '../models/weight_record.dart';
import 'weight_repository.dart';

class SqliteWeightRepository implements WeightRepository {
  final DatabaseHelper databaseHelper;

  const SqliteWeightRepository(this.databaseHelper);

  @override
  Future<WeightRecord?> getWeightForDate(String date) {
    return databaseHelper.getWeightRecordByDate(date);
  }

  @override
  Future<List<WeightRecord>> getWeightHistory() {
    return databaseHelper.getWeightRecords();
  }

  @override
  Future<void> saveWeight(String date, double weight) {
    return databaseHelper.saveWeightRecord(date, weight);
  }

  @override
  Future<void> deleteWeight(String date) async {
    await databaseHelper.deleteWeightRecord(date);
  }
}
