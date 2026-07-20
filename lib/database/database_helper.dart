import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/food.dart';
import '../models/meal_record.dart';
import '../models/meal_item.dart';
import '../models/weight_record.dart';

enum FoodRemovalResult { deleted, archived, notFound }

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._();
  static const databaseVersion = 5;

  final DatabaseFactory? _databaseFactoryOverride;
  final String? _databasePathOverride;

  DatabaseHelper._({this._databaseFactoryOverride, this._databasePathOverride});

  DatabaseHelper.forTesting(
    DatabaseFactory databaseFactory, {
    String databasePath = inMemoryDatabasePath,
  }) : this._(
         databaseFactoryOverride: databaseFactory,
         databasePathOverride: databasePath,
       );

  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;

    _database = await _initDatabase();

    return _database!;
  }

  Future<Database> _initDatabase() async {
    final factory = _databaseFactoryOverride ?? databaseFactory;
    final path =
        _databasePathOverride ??
        join(await factory.getDatabasesPath(), 'health_app.db');

    return factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: databaseVersion,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      ),
    );
  }

  Future<void> close() async {
    final db = _database;
    if (db == null) return;

    await db.close();
    _database = null;
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE foods (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        calories INTEGER NOT NULL,
        protein REAL NOT NULL,
        carbs REAL NOT NULL DEFAULT 0,
        fat REAL NOT NULL DEFAULT 0,
        favorite INTEGER NOT NULL DEFAULT 0,
        is_archived INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await _createMealRecordsTable(db);
    await _createWeightRecordsTable(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _createMealRecordsTable(db);
    }
    if (oldVersion < 3) {
      await db.execute(
        'ALTER TABLE foods '
        'ADD COLUMN is_archived INTEGER NOT NULL DEFAULT 0',
      );
    }
    if (oldVersion >= 2 && oldVersion < 4) {
      await _addMealRecordSnapshots(db);
    }
    if (oldVersion < 5) {
      await _createWeightRecordsTable(db);
    }
  }

  Future<void> _addMealRecordSnapshots(Database db) async {
    await db.execute(
      "ALTER TABLE meal_records ADD COLUMN food_name_snapshot "
      "TEXT NOT NULL DEFAULT '未知食物'",
    );
    await db.execute(
      'ALTER TABLE meal_records ADD COLUMN calories_snapshot '
      'REAL NOT NULL DEFAULT 0',
    );
    await db.execute(
      'ALTER TABLE meal_records ADD COLUMN protein_snapshot '
      'REAL NOT NULL DEFAULT 0',
    );
    await db.execute(
      'ALTER TABLE meal_records ADD COLUMN carbs_snapshot '
      'REAL NOT NULL DEFAULT 0',
    );
    await db.execute(
      'ALTER TABLE meal_records ADD COLUMN fat_snapshot '
      'REAL NOT NULL DEFAULT 0',
    );
    await db.execute('''
      UPDATE meal_records
      SET
        food_name_snapshot = COALESCE(
          (SELECT name FROM foods WHERE foods.id = meal_records.food_id),
          '未知食物'
        ),
        calories_snapshot = COALESCE(
          (SELECT calories FROM foods WHERE foods.id = meal_records.food_id),
          0
        ),
        protein_snapshot = COALESCE(
          (SELECT protein FROM foods WHERE foods.id = meal_records.food_id),
          0
        ),
        carbs_snapshot = COALESCE(
          (SELECT carbs FROM foods WHERE foods.id = meal_records.food_id),
          0
        ),
        fat_snapshot = COALESCE(
          (SELECT fat FROM foods WHERE foods.id = meal_records.food_id),
          0
        )
    ''');
  }

  Future<void> _createMealRecordsTable(Database db) async {
    await db.execute('''
      CREATE TABLE meal_records (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT NOT NULL,
        meal_type TEXT NOT NULL,
        food_id INTEGER NOT NULL,
        servings REAL NOT NULL DEFAULT 1,
        food_name_snapshot TEXT NOT NULL DEFAULT '未知食物',
        calories_snapshot REAL NOT NULL DEFAULT 0,
        protein_snapshot REAL NOT NULL DEFAULT 0,
        carbs_snapshot REAL NOT NULL DEFAULT 0,
        fat_snapshot REAL NOT NULL DEFAULT 0,
        FOREIGN KEY (food_id) REFERENCES foods (id)
      )
    ''');
  }

  Future<void> _createWeightRecordsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS weight_records (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT NOT NULL UNIQUE,
        weight REAL NOT NULL CHECK (weight >= 20 AND weight <= 500)
      )
    ''');
  }

  // --------------------
  // Foods
  // --------------------

  Future<int> insertFood(Food food) async {
    final db = await database;

    return db.insert(
      'foods',
      food.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Food>> getFoods() async {
    final db = await database;

    final List<Map<String, dynamic>> maps = await db.query(
      'foods',
      where: 'is_archived = 0',
      orderBy: 'name ASC',
    );

    return maps.map((map) => Food.fromMap(map)).toList();
  }

  Future<int> getFoodReferenceCount(int foodId) async {
    final db = await database;
    final countResult = await db.rawQuery(
      'SELECT COUNT(*) FROM meal_records WHERE food_id = ?',
      [foodId],
    );
    return Sqflite.firstIntValue(countResult) ?? 0;
  }

  Future<FoodRemovalResult> removeFood(int foodId) async {
    final db = await database;

    return db.transaction((transaction) async {
      final countResult = await transaction.rawQuery(
        'SELECT COUNT(*) FROM meal_records WHERE food_id = ?',
        [foodId],
      );
      final referenceCount = Sqflite.firstIntValue(countResult) ?? 0;
      if (referenceCount > 0) {
        final archivedRows = await transaction.update(
          'foods',
          {'is_archived': 1},
          where: 'id = ?',
          whereArgs: [foodId],
        );
        return archivedRows > 0
            ? FoodRemovalResult.archived
            : FoodRemovalResult.notFound;
      }

      final deletedRows = await transaction.delete(
        'foods',
        where: 'id = ?',
        whereArgs: [foodId],
      );
      return deletedRows > 0
          ? FoodRemovalResult.deleted
          : FoodRemovalResult.notFound;
    });
  }

  // --------------------
  // Meal records
  // --------------------

  Future<int> insertMealRecord(MealRecord mealRecord) async {
    final db = await database;

    return db.insert(
      'meal_records',
      mealRecord.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<MealRecord>> getAllMealRecords() async {
    final db = await database;

    final List<Map<String, dynamic>> maps = await db.query('meal_records');

    return maps.map((map) => MealRecord.fromMap(map)).toList();
  }

  Future<List<MealRecord>> getMealRecordsByDate(String date) async {
    final db = await database;

    final List<Map<String, dynamic>> maps = await db.query(
      'meal_records',
      where: 'date = ?',
      whereArgs: [date],
      orderBy: 'id ASC',
    );

    return maps.map((map) => MealRecord.fromMap(map)).toList();
  }

  Future<List<MealRecord>> getMealRecordsByDateAndMealType(
    String date,
    String mealType,
  ) async {
    final db = await database;

    final List<Map<String, dynamic>> maps = await db.query(
      'meal_records',
      where: 'date = ? AND meal_type = ?',
      whereArgs: [date, mealType],
      orderBy: 'id ASC',
    );

    return maps.map((map) => MealRecord.fromMap(map)).toList();
  }

  Future<List<MealItem>> getMealItemsByDateAndMealType(
    String date,
    String mealType,
  ) async {
    final db = await database;

    final List<Map<String, dynamic>> maps = await db.rawQuery(
      '''
    SELECT
      meal_records.id AS record_id,
      meal_records.date,
      meal_records.meal_type,
      meal_records.food_id,
      meal_records.servings,
      meal_records.food_name_snapshot AS food_name,
      meal_records.calories_snapshot AS calories,
      meal_records.protein_snapshot AS protein,
      meal_records.carbs_snapshot AS carbs,
      meal_records.fat_snapshot AS fat
    FROM meal_records
    WHERE meal_records.date = ?
      AND meal_records.meal_type = ?
    ORDER BY meal_records.id ASC
    ''',
      [date, mealType],
    );

    return maps.map((map) => MealItem.fromMap(map)).toList();
  }

  Future<int> deleteMealRecord(int id) async {
    final db = await database;

    return db.delete('meal_records', where: 'id = ?', whereArgs: [id]);
  }

  // --------------------
  // Weight records
  // --------------------

  Future<void> saveWeightRecord(String date, double weight) async {
    final hasAtMostOneDecimal =
        ((weight * 10) - (weight * 10).round()).abs() < 0.0000001;
    if (!weight.isFinite ||
        weight < 20 ||
        weight > 500 ||
        !hasAtMostOneDecimal) {
      throw ArgumentError.value(
        weight,
        'weight',
        'Weight must be 20–500 kg with at most one decimal place.',
      );
    }
    final db = await database;
    await db.transaction((transaction) async {
      final updated = await transaction.update(
        'weight_records',
        {'weight': weight},
        where: 'date = ?',
        whereArgs: [date],
      );
      if (updated == 0) {
        await transaction.insert('weight_records', {
          'date': date,
          'weight': weight,
        });
      }
    });
  }

  Future<WeightRecord?> getWeightRecordByDate(String date) async {
    final db = await database;
    final maps = await db.query(
      'weight_records',
      where: 'date = ?',
      whereArgs: [date],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return WeightRecord.fromMap(maps.single);
  }

  Future<List<WeightRecord>> getWeightRecords() async {
    final db = await database;
    final maps = await db.query('weight_records', orderBy: 'date DESC');
    return maps.map(WeightRecord.fromMap).toList();
  }

  Future<int> deleteWeightRecord(String date) async {
    final db = await database;
    return db.delete('weight_records', where: 'date = ?', whereArgs: [date]);
  }
}
