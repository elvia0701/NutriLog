import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/meal_item.dart';
import '../models/meal_record.dart';
import 'meal_repository.dart';

class SupabaseMealRepository implements MealRepository {
  static const _mealColumns =
      'id, entry_date, meal_type, food_id, servings, food_name_snapshot, '
      'calories_snapshot, protein_snapshot, carbs_snapshot, fat_snapshot';
  static const _mealTypes = {'breakfast', 'lunch', 'dinner', 'snack'};
  static final _uuidPattern = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-'
    r'[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
    caseSensitive: false,
  );
  static final _datePattern = RegExp(r'^\d{4}-\d{2}-\d{2}$');

  final SupabaseClient _client;
  final String? Function() _currentUserId;

  SupabaseMealRepository(
    SupabaseClient client, {
    String? Function()? currentUserId,
  }) : _client = client,
       _currentUserId = currentUserId ?? (() => client.auth.currentUser?.id);

  @override
  Future<MealRecord> insertMealRecord(MealRecord mealRecord) {
    return _execute('新增餐點', () async {
      _requireUser();
      final foodCloudId = _requireFoodCloudId(mealRecord);
      _validateDate(mealRecord.date);
      _validateMealType(mealRecord.mealType);
      _validateServings(mealRecord.servings);

      final result = await _client.rpc(
        'add_meal_record',
        params: {
          'food_id': foodCloudId,
          'entry_date': mealRecord.date,
          'meal_type': mealRecord.mealType,
          'servings': mealRecord.servings,
        },
      );
      if (result is! String || !_uuidPattern.hasMatch(result)) {
        throw const FormatException('Invalid add_meal_record result');
      }
      return mealRecord.copyWith(cloudId: result);
    });
  }

  @override
  Future<List<MealRecord>> getAllMealRecords() {
    return _execute('讀取餐點', () async {
      _requireUser();
      final rows = await _client
          .from('meal_records')
          .select(_mealColumns)
          .order('entry_date', ascending: true)
          .order('created_at', ascending: true);
      return rows.map(_recordFromRow).toList(growable: false);
    });
  }

  @override
  Future<List<MealRecord>> getMealRecordsByDate(String date) {
    return _execute('讀取指定日期餐點', () async {
      _requireUser();
      _validateDate(date);
      final rows = await _client
          .from('meal_records')
          .select(_mealColumns)
          .eq('entry_date', date)
          .order('created_at', ascending: true);
      return rows.map(_recordFromRow).toList(growable: false);
    });
  }

  @override
  Future<List<MealRecord>> getMealRecordsByDateAndMealType(
    String date,
    String mealType,
  ) {
    return _execute('讀取指定餐別', () async {
      _requireUser();
      _validateDate(date);
      _validateMealType(mealType);
      final rows = await _client
          .from('meal_records')
          .select(_mealColumns)
          .eq('entry_date', date)
          .eq('meal_type', mealType)
          .order('created_at', ascending: true);
      return rows.map(_recordFromRow).toList(growable: false);
    });
  }

  @override
  Future<List<MealItem>> getMealItemsByDateAndMealType(
    String date,
    String mealType,
  ) {
    return _execute('讀取指定餐別', () async {
      _requireUser();
      _validateDate(date);
      _validateMealType(mealType);
      final rows = await _client
          .from('meal_records')
          .select(_mealColumns)
          .eq('entry_date', date)
          .eq('meal_type', mealType)
          .order('created_at', ascending: true);
      return rows.map(_itemFromRow).toList(growable: false);
    });
  }

  @override
  Future<void> deleteMealRecord(MealItem item) {
    return _execute('刪除餐點', () async {
      _requireUser();
      final cloudId = item.cloudRecordId;
      if (cloudId == null || !_uuidPattern.hasMatch(cloudId)) {
        throw const MealRepositoryException(
          MealRepositoryFailureKind.invalidData,
          '餐點識別資料不完整，請重新載入後再試。',
        );
      }
      final rows = await _client
          .from('meal_records')
          .delete()
          .eq('id', cloudId)
          .select('id');
      if (rows.isEmpty) {
        throw const MealRepositoryException(
          MealRepositoryFailureKind.notFound,
          '找不到這筆餐點，請重新載入。',
        );
      }
    });
  }

  MealRecord _recordFromRow(Map<String, dynamic> row) {
    final values = _validatedRow(row);
    return MealRecord(
      cloudId: values.id,
      date: values.date,
      mealType: values.mealType,
      foodCloudId: values.foodId,
      servings: values.servings,
      foodNameSnapshot: values.foodName,
      caloriesSnapshot: values.calories,
      proteinSnapshot: values.protein,
      carbsSnapshot: values.carbs,
      fatSnapshot: values.fat,
    );
  }

  MealItem _itemFromRow(Map<String, dynamic> row) {
    final values = _validatedRow(row);
    return MealItem(
      cloudRecordId: values.id,
      foodCloudId: values.foodId,
      date: values.date,
      mealType: values.mealType,
      servings: values.servings,
      foodName: values.foodName,
      calories: values.calories,
      protein: values.protein,
      carbs: values.carbs,
      fat: values.fat,
    );
  }

  _MealRow _validatedRow(Map<String, dynamic> row) {
    final id = row['id'];
    final date = row['entry_date'];
    final mealType = row['meal_type'];
    final foodId = row['food_id'];
    final servings = row['servings'];
    final foodName = row['food_name_snapshot'];
    final calories = row['calories_snapshot'];
    final protein = row['protein_snapshot'];
    final carbs = row['carbs_snapshot'];
    final fat = row['fat_snapshot'];

    if (id is! String ||
        !_uuidPattern.hasMatch(id) ||
        date is! String ||
        !_datePattern.hasMatch(date) ||
        mealType is! String ||
        !_mealTypes.contains(mealType) ||
        foodId is! String ||
        !_uuidPattern.hasMatch(foodId) ||
        servings is! num ||
        !servings.isFinite ||
        servings <= 0 ||
        foodName is! String ||
        foodName.trim().isEmpty ||
        calories is! num ||
        !calories.isFinite ||
        calories.toInt() != calories ||
        calories < 0 ||
        protein is! num ||
        !protein.isFinite ||
        protein < 0 ||
        carbs is! num ||
        !carbs.isFinite ||
        carbs < 0 ||
        fat is! num ||
        !fat.isFinite ||
        fat < 0) {
      throw const FormatException('Invalid meal_records row');
    }

    return _MealRow(
      id: id,
      date: date,
      mealType: mealType,
      foodId: foodId,
      servings: servings.toDouble(),
      foodName: foodName,
      calories: calories.toDouble(),
      protein: protein.toDouble(),
      carbs: carbs.toDouble(),
      fat: fat.toDouble(),
    );
  }

  void _requireUser() {
    final userId = _currentUserId();
    if (userId == null || userId.isEmpty) {
      throw const MealRepositoryException(
        MealRepositoryFailureKind.unauthenticated,
        '登入狀態已失效，請重新登入後再試。',
      );
    }
  }

  String _requireFoodCloudId(MealRecord record) {
    final foodCloudId = record.foodCloudId;
    if (foodCloudId == null || !_uuidPattern.hasMatch(foodCloudId)) {
      throw const MealRepositoryException(
        MealRepositoryFailureKind.invalidData,
        '食品識別資料不完整，請重新載入食品後再試。',
      );
    }
    return foodCloudId;
  }

  void _validateDate(String date) {
    if (!_datePattern.hasMatch(date) || DateTime.tryParse(date) == null) {
      throw const MealRepositoryException(
        MealRepositoryFailureKind.invalidData,
        '餐點日期格式不正確，請重新選擇日期。',
      );
    }
  }

  void _validateMealType(String mealType) {
    if (!_mealTypes.contains(mealType)) {
      throw const MealRepositoryException(
        MealRepositoryFailureKind.invalidData,
        '餐別不正確，請重新選擇早餐、午餐、晚餐或點心。',
      );
    }
  }

  void _validateServings(double servings) {
    if (!servings.isFinite || servings <= 0) {
      throw const MealRepositoryException(
        MealRepositoryFailureKind.invalidData,
        '份數必須是大於 0 的數字。',
      );
    }
  }

  Future<T> _execute<T>(String operation, Future<T> Function() request) async {
    try {
      return await request();
    } on MealRepositoryException {
      rethrow;
    } on PostgrestException catch (error, stackTrace) {
      _debugPrintFailure(operation, error, stackTrace);
      final code = error.code?.toUpperCase() ?? '';
      if (code == '42501' || code == 'PGRST301' || code == 'PGRST302') {
        throw const MealRepositoryException(
          MealRepositoryFailureKind.permissionDenied,
          '沒有權限存取這筆餐點資料，請重新登入後再試。',
        );
      }
      if (code == 'P0002' || code == '23503') {
        throw const MealRepositoryException(
          MealRepositoryFailureKind.foodUnavailable,
          '這項食品不存在、已封存或無法使用，請重新選擇食品。',
        );
      }
      if (code == '23514' || code == '22004' || code == '22P02') {
        throw const MealRepositoryException(
          MealRepositoryFailureKind.invalidData,
          '餐點資料不符合要求，請檢查日期、餐別與份數。',
        );
      }
      throw const MealRepositoryException(
        MealRepositoryFailureKind.unknown,
        '餐點資料操作失敗，請稍後再試。',
      );
    } on FormatException catch (error, stackTrace) {
      _debugPrintFailure(operation, error, stackTrace);
      throw const MealRepositoryException(
        MealRepositoryFailureKind.invalidData,
        '收到的餐點資料格式不正確，請重新載入；若持續發生請回報。',
      );
    } on TypeError catch (error, stackTrace) {
      _debugPrintFailure(operation, error, stackTrace);
      throw const MealRepositoryException(
        MealRepositoryFailureKind.invalidData,
        '收到的餐點資料格式不正確，請重新載入；若持續發生請回報。',
      );
    } on TimeoutException catch (error, stackTrace) {
      _debugPrintFailure(operation, error, stackTrace);
      throw const MealRepositoryException(
        MealRepositoryFailureKind.network,
        '網路連線逾時，請確認連線後再試。',
      );
    } catch (error, stackTrace) {
      _debugPrintFailure(operation, error, stackTrace);
      if (_looksLikeNetworkError(error)) {
        throw const MealRepositoryException(
          MealRepositoryFailureKind.network,
          '無法連線至雲端服務，請確認網路後再試。',
        );
      }
      throw const MealRepositoryException(
        MealRepositoryFailureKind.unknown,
        '餐點資料操作失敗，請稍後再試。',
      );
    }
  }

  bool _looksLikeNetworkError(Object error) {
    final message = error.toString().toLowerCase();
    return message.contains('failed to fetch') ||
        message.contains('clientexception') ||
        message.contains('socketexception') ||
        message.contains('xmlhttprequest') ||
        message.contains('connection refused') ||
        message.contains('connection reset') ||
        message.contains('failed host lookup');
  }

  void _debugPrintFailure(
    String operation,
    Object error,
    StackTrace stackTrace,
  ) {
    if (!kDebugMode) return;
    debugPrint('SupabaseMealRepository $operation failed: $error');
    debugPrintStack(stackTrace: stackTrace);
  }
}

class _MealRow {
  final String id;
  final String date;
  final String mealType;
  final String foodId;
  final double servings;
  final String foodName;
  final double calories;
  final double protein;
  final double carbs;
  final double fat;

  const _MealRow({
    required this.id,
    required this.date,
    required this.mealType,
    required this.foodId,
    required this.servings,
    required this.foodName,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
  });
}
