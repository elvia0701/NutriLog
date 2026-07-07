import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:health_app/models/food.dart';

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

    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
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
  }
  Future<int> insertFood(Food food) async {
  final db = await database;

  return await db.insert(
    'foods',
    food.toMap(),
    conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
  Future<List<Food>> getFoods() async {
  final db = await database;

  final List<Map<String, dynamic>> maps = await db.query('foods');

  return maps.map((map) => Food.fromMap(map)).toList();
  }
}