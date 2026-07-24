import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/food.dart';
import 'food_repository.dart';

class SupabaseFoodRepository implements FoodRepository {
  static const _foodColumns =
      'id, name, calories, protein, carbs, fat, favorite, is_archived';
  static final _uuidPattern = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-'
    r'[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
    caseSensitive: false,
  );

  final SupabaseClient _client;
  final String? Function() _currentUserId;

  SupabaseFoodRepository(
    SupabaseClient client, {
    String? Function()? currentUserId,
  }) : _client = client,
       _currentUserId = currentUserId ?? (() => client.auth.currentUser?.id);

  @override
  Future<List<Food>> getFoods() {
    return _execute('讀取食物', () async {
      _requireUserId();
      final rows = await _client
          .from('foods')
          .select(_foodColumns)
          .eq('is_archived', false)
          .order('name', ascending: true)
          .order('created_at', ascending: true);
      return rows.map(_foodFromRow).toList(growable: false);
    });
  }

  @override
  Future<Food> insertFood(Food food) {
    return _execute('建立食物', () async {
      final userId = _requireUserId();
      final row = await _client
          .from('foods')
          .insert({..._foodValues(food), 'user_id': userId})
          .select(_foodColumns)
          .single();
      return _foodFromRow(row);
    });
  }

  @override
  Future<int> updateFood(Food food) {
    return _execute('更新食物', () async {
      _requireUserId();
      final cloudId = _requireCloudId(food);
      final rows = await _client
          .from('foods')
          .update(_foodValues(food))
          .eq('id', cloudId)
          .select('id');
      if (rows.isEmpty) {
        throw const FoodRepositoryException(
          FoodRepositoryFailureKind.notFound,
          '找不到這項食物，請重新載入列表。',
        );
      }
      return rows.length;
    });
  }

  @override
  Future<int> getFoodReferenceCount(Food food) {
    return _execute('檢查食物引用', () async {
      _requireUserId();
      final cloudId = _requireCloudId(food);
      final rows = await _client
          .from('meal_records')
          .select('id')
          .eq('food_id', cloudId);
      return rows.length;
    });
  }

  @override
  Future<FoodRemovalResult> removeFood(Food food) async {
    try {
      return await _execute('移除食物', () async {
        _requireUserId();
        final result = await _client.rpc(
          'remove_food',
          params: {'food_id': _requireCloudId(food)},
        );
        return switch (result) {
          'deleted' => FoodRemovalResult.deleted,
          'archived' => FoodRemovalResult.archived,
          _ => throw const FormatException('Unexpected remove_food result'),
        };
      });
    } on FoodRepositoryException catch (error) {
      if (error.kind == FoodRepositoryFailureKind.notFound) {
        return FoodRemovalResult.notFound;
      }
      rethrow;
    }
  }

  String _requireUserId() {
    final userId = _currentUserId();
    if (userId == null || userId.isEmpty) {
      throw const FoodRepositoryException(
        FoodRepositoryFailureKind.unauthenticated,
        '登入狀態已失效，請重新登入後再試。',
      );
    }
    return userId;
  }

  String _requireCloudId(Food food) {
    final cloudId = food.cloudId;
    if (cloudId == null || !_uuidPattern.hasMatch(cloudId)) {
      throw const FoodRepositoryException(
        FoodRepositoryFailureKind.invalidData,
        '食物識別資料不完整，請重新載入後再試。',
      );
    }
    return cloudId;
  }

  Map<String, Object> _foodValues(Food food) {
    return {
      'name': food.name.trim(),
      'calories': food.calories,
      'protein': food.protein,
      'carbs': food.carbs,
      'fat': food.fat,
      'favorite': food.favorite,
      'is_archived': food.isArchived,
    };
  }

  Food _foodFromRow(Map<String, dynamic> row) {
    final id = row['id'];
    final name = row['name'];
    final calories = row['calories'];
    final protein = row['protein'];
    final carbs = row['carbs'];
    final fat = row['fat'];
    final favorite = row['favorite'];
    final isArchived = row['is_archived'];

    if (id is! String ||
        !_uuidPattern.hasMatch(id) ||
        name is! String ||
        name.trim().isEmpty ||
        calories is! num ||
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
        fat < 0 ||
        favorite is! bool ||
        isArchived is! bool) {
      throw const FormatException('Invalid foods row');
    }

    return Food(
      cloudId: id,
      name: name,
      calories: calories.toInt(),
      protein: protein.toDouble(),
      carbs: carbs.toDouble(),
      fat: fat.toDouble(),
      favorite: favorite,
      isArchived: isArchived,
    );
  }

  Future<T> _execute<T>(String operation, Future<T> Function() request) async {
    try {
      return await request();
    } on FoodRepositoryException {
      rethrow;
    } on PostgrestException catch (error, stackTrace) {
      _debugPrintFailure(operation, error, stackTrace);
      final code = error.code?.toUpperCase() ?? '';
      if (code == '42501' || code == 'PGRST301' || code == 'PGRST302') {
        throw const FoodRepositoryException(
          FoodRepositoryFailureKind.permissionDenied,
          '沒有權限存取這筆食物資料，請重新登入後再試。',
        );
      }
      throw FoodRepositoryException(
        code == 'P0002'
            ? FoodRepositoryFailureKind.notFound
            : FoodRepositoryFailureKind.unknown,
        code == 'P0002' ? '找不到這項食物，請重新載入列表。' : '食物資料操作失敗，請稍後再試。',
      );
    } on FormatException catch (error, stackTrace) {
      _debugPrintFailure(operation, error, stackTrace);
      throw const FoodRepositoryException(
        FoodRepositoryFailureKind.invalidData,
        '收到的食物資料格式不正確，請重新載入；若持續發生請回報。',
      );
    } on TypeError catch (error, stackTrace) {
      _debugPrintFailure(operation, error, stackTrace);
      throw const FoodRepositoryException(
        FoodRepositoryFailureKind.invalidData,
        '收到的食物資料格式不正確，請重新載入；若持續發生請回報。',
      );
    } on TimeoutException catch (error, stackTrace) {
      _debugPrintFailure(operation, error, stackTrace);
      throw const FoodRepositoryException(
        FoodRepositoryFailureKind.network,
        '網路連線逾時，請確認連線後再試。',
      );
    } catch (error, stackTrace) {
      _debugPrintFailure(operation, error, stackTrace);
      if (_looksLikeNetworkError(error)) {
        throw const FoodRepositoryException(
          FoodRepositoryFailureKind.network,
          '無法連線至雲端服務，請確認網路後再試。',
        );
      }
      throw const FoodRepositoryException(
        FoodRepositoryFailureKind.unknown,
        '食物資料操作失敗，請稍後再試。',
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
    debugPrint('SupabaseFoodRepository $operation failed: $error');
    debugPrintStack(stackTrace: stackTrace);
  }
}
