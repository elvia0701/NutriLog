import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:nutrilog/database/database_helper.dart';
import 'package:nutrilog/repositories/sqlite_weight_repository.dart';

void main() {
  sqfliteFfiInit();

  late DatabaseHelper databaseHelper;
  late SqliteWeightRepository repository;

  setUp(() {
    databaseHelper = DatabaseHelper.forTesting(databaseFactoryFfi);
    repository = SqliteWeightRepository(databaseHelper);
  });

  tearDown(() => databaseHelper.close());

  test(
    'SQLite repository preserves upsert, lookup, sorting, and deletion',
    () async {
      await repository.saveWeight('2026-07-18', 91.2);
      await repository.saveWeight('2026-07-20', 90.5);
      await repository.saveWeight('2026-07-19', 90.8);
      await repository.saveWeight('2026-07-20', 90.3);

      expect((await repository.getWeightForDate('2026-07-20'))?.weight, 90.3);
      expect(
        (await repository.getWeightHistory()).map((record) => record.date),
        ['2026-07-20', '2026-07-19', '2026-07-18'],
      );

      await repository.deleteWeight('2026-07-19');
      expect(await repository.getWeightForDate('2026-07-19'), isNull);
    },
  );

  test('SQLite repository keeps DatabaseHelper weight validation', () async {
    await expectLater(
      repository.saveWeight('2026-07-20', 19.9),
      throwsArgumentError,
    );
    await expectLater(
      repository.saveWeight('2026-07-20', 90.55),
      throwsArgumentError,
    );
  });
}
