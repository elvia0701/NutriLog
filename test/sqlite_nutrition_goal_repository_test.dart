import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:nutrilog/database/database_helper.dart';
import 'package:nutrilog/models/nutrition_goal.dart';
import 'package:nutrilog/repositories/sqlite_nutrition_goal_repository.dart';

void main() {
  sqfliteFfiInit();

  late DatabaseHelper databaseHelper;
  late SqliteNutritionGoalRepository repository;

  setUp(() {
    databaseHelper = DatabaseHelper.forTesting(databaseFactoryFfi);
    repository = SqliteNutritionGoalRepository(databaseHelper);
  });

  tearDown(() => databaseHelper.close());

  test(
    'SQLite repository preserves version lookup and same-date upsert',
    () async {
      await repository.saveGoal(
        const NutritionGoal(
          effectiveDate: '2026-07-01',
          calorieTarget: 1600,
          proteinTarget: 100,
        ),
      );
      await repository.saveGoal(
        const NutritionGoal(
          effectiveDate: '2026-08-01',
          calorieTarget: 1800,
          proteinTarget: 120,
        ),
      );
      await repository.saveGoal(
        const NutritionGoal(
          effectiveDate: '2026-08-01',
          calorieTarget: 1750,
          proteinTarget: 115,
        ),
      );

      expect(await repository.getGoalForDate('2026-06-30'), isNull);
      expect(
        (await repository.getGoalForDate('2026-07-31'))?.calorieTarget,
        1600,
      );
      expect(
        (await repository.getGoalForDate('2026-08-15'))?.calorieTarget,
        1750,
      );

      final history = await repository.getGoalHistory();
      expect(history, hasLength(2));
      expect(history.map((goal) => goal.effectiveDate), [
        '2026-07-01',
        '2026-08-01',
      ]);
      expect(history.last.proteinTarget, 115);
    },
  );

  test('SQLite repository keeps DatabaseHelper goal validation', () async {
    await expectLater(
      repository.saveGoal(
        const NutritionGoal(
          effectiveDate: '2026-07-01',
          calorieTarget: 99,
          proteinTarget: 100,
        ),
      ),
      throwsArgumentError,
    );
    await expectLater(
      repository.saveGoal(
        const NutritionGoal(
          effectiveDate: '2026-07-01',
          calorieTarget: 1600,
          proteinTarget: 0,
        ),
      ),
      throwsArgumentError,
    );
  });
}
