import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/food.dart';
import '../models/meal_record.dart';
import '../models/meal_item.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._();

  DatabaseHelper._();

  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;

    _database = await _initDatabase();

    return _database!;
  }

  Future<Database> _initDatabase() async {
    final databasePath = await getDatabasesPath();
    final path = join(databasePath, 'health_app.db');

    return openDatabase(
      path,
      version: 2,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
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
        favorite INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await _createMealRecordsTable(db);
  }

  Future<void> _onUpgrade(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion < 2) {
      await _createMealRecordsTable(db);
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
      orderBy: 'name ASC',
    );

    return maps.map((map) => Food.fromMap(map)).toList();
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

  final List<Map<String, dynamic>> maps =
      await db.query('meal_records');

  return maps
      .map((map) => MealRecord.fromMap(map))
      .toList();
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

    return db.delete(
      'meal_records',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}