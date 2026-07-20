import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/food.dart';
import '../models/meal_record.dart';
import '../models/meal_item.dart';

enum FoodRemovalResult { deleted, archived, notFound }

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._();
  static const databaseVersion = 3;

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
  }

  Future<void> _createMealRecordsTable(Database db) async {
    await db.execute('''
      CREATE TABLE meal_records (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT NOT NULL,
        meal_type TEXT NOT NULL,
        food_id INTEGER NOT NULL,
        servings REAL NOT NULL DEFAULT 1,
        FOREIGN KEY (food_id) REFERENCES foods (id)
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
      foods.name AS food_name,
      foods.calories,
      foods.protein
    FROM meal_records
    INNER JOIN foods
      ON meal_records.food_id = foods.id
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
}
