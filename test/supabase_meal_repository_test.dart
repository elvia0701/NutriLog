import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart';
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:nutrilog/models/meal_item.dart';
import 'package:nutrilog/models/meal_record.dart';
import 'package:nutrilog/repositories/meal_repository.dart';
import 'package:nutrilog/repositories/supabase_meal_repository.dart';

const _userId = '11111111-1111-4111-8111-111111111111';
const _foodId = '22222222-2222-4222-8222-222222222222';
const _mealId = '33333333-3333-4333-8333-333333333333';

Map<String, dynamic> mealRow({
  String id = _mealId,
  String date = '2026-07-24',
  String mealType = 'breakfast',
  String foodId = _foodId,
  num servings = 1.5,
  String foodName = '原始食品名稱',
  num calories = 120,
  num protein = 8.5,
  num carbs = 10.25,
  num fat = 4.75,
}) {
  return {
    'id': id,
    'entry_date': date,
    'meal_type': mealType,
    'food_id': foodId,
    'servings': servings,
    'food_name_snapshot': foodName,
    'calories_snapshot': calories,
    'protein_snapshot': protein,
    'carbs_snapshot': carbs,
    'fat_snapshot': fat,
  };
}

Response jsonResponse(Request request, Object body, {int statusCode = 200}) {
  return Response(
    jsonEncode(body),
    statusCode,
    headers: {'content-type': 'application/json'},
    request: request,
  );
}

SupabaseMealRepository buildRepository(
  Future<Response> Function(Request request) handler, {
  String? userId = _userId,
}) {
  final client = SupabaseClient(
    'https://example.supabase.co',
    'test-anon-key',
    accessToken: () async => 'test-access-token',
    httpClient: MockClient(handler),
  );
  return SupabaseMealRepository(client, currentUserId: () => userId);
}

MealRecord newCloudMeal({
  String mealType = 'breakfast',
  double servings = 1.5,
}) {
  return MealRecord(
    date: '2026-07-24',
    mealType: mealType,
    foodCloudId: _foodId,
    servings: servings,
    foodNameSnapshot: '用戶端食品名稱',
    caloriesSnapshot: 999,
    proteinSnapshot: 999,
    carbsSnapshot: 999,
    fatSnapshot: 999,
  );
}

void main() {
  test(
    'maps Supabase UUIDs and reads a specified date and meal type',
    () async {
      final repository = buildRepository((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/rest/v1/meal_records');
        expect(request.url.queryParameters['entry_date'], 'eq.2026-07-24');
        expect(request.url.queryParameters['meal_type'], 'eq.breakfast');
        expect(request.headers['authorization'], 'Bearer test-access-token');
        return jsonResponse(request, [mealRow()]);
      });

      final items = await repository.getMealItemsByDateAndMealType(
        '2026-07-24',
        'breakfast',
      );

      expect(items, hasLength(1));
      expect(items.single.recordId, isNull);
      expect(items.single.cloudRecordId, _mealId);
      expect(items.single.foodId, isNull);
      expect(items.single.foodCloudId, _foodId);
      expect(items.single.servings, 1.5);
    },
  );

  test('supports all four meal types and empty results', () async {
    const types = ['breakfast', 'lunch', 'dinner', 'snack'];
    var requestIndex = 0;
    final repository = buildRepository((request) async {
      final expectedType = types[requestIndex];
      requestIndex += 1;
      expect(request.url.queryParameters['meal_type'], 'eq.$expectedType');
      if (expectedType == 'snack') return jsonResponse(request, []);
      return jsonResponse(request, [mealRow(mealType: expectedType)]);
    });

    for (final type in types) {
      final records = await repository.getMealRecordsByDateAndMealType(
        '2026-07-24',
        type,
      );
      if (type == 'snack') {
        expect(records, isEmpty);
      } else {
        expect(records.single.mealType, type);
      }
    }
  });

  test('lists all records and filters records by date', () async {
    var requestNumber = 0;
    final repository = buildRepository((request) async {
      requestNumber += 1;
      if (requestNumber == 1) {
        expect(request.url.queryParameters.containsKey('entry_date'), isFalse);
        return jsonResponse(request, [
          mealRow(),
          mealRow(
            id: '44444444-4444-4444-8444-444444444444',
            date: '2026-07-23',
          ),
        ]);
      }
      expect(request.url.queryParameters['entry_date'], 'eq.2026-07-24');
      return jsonResponse(request, [mealRow()]);
    });

    expect(await repository.getAllMealRecords(), hasLength(2));
    final dated = await repository.getMealRecordsByDate('2026-07-24');
    expect(dated, hasLength(1));
    expect(dated.single.date, '2026-07-24');
  });

  test('adds a fractional serving through RPC without a user_id', () async {
    final repository = buildRepository((request) async {
      expect(request.method, 'POST');
      expect(request.url.path, '/rest/v1/rpc/add_meal_record');
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      expect(body, {
        'food_id': _foodId,
        'entry_date': '2026-07-24',
        'meal_type': 'dinner',
        'servings': 2.5,
      });
      expect(body.containsKey('user_id'), isFalse);
      expect(body.keys.any((key) => key.contains('snapshot')), isFalse);
      return jsonResponse(request, _mealId);
    });

    final created = await repository.insertMealRecord(
      newCloudMeal(mealType: 'dinner', servings: 2.5),
    );

    expect(created.cloudId, _mealId);
    expect(created.foodCloudId, _foodId);
    expect(created.servings, 2.5);
  });

  test('uses stored snapshots for history and nutrition totals', () async {
    final repository = buildRepository(
      (request) async => jsonResponse(request, [
        mealRow(
          foodName: '建立餐點時名稱',
          calories: 120,
          protein: 8.5,
          carbs: 10.25,
          fat: 4.75,
          servings: 1.5,
        ),
      ]),
    );

    final item = (await repository.getMealItemsByDateAndMealType(
      '2026-07-24',
      'breakfast',
    )).single;

    expect(item.foodName, '建立餐點時名稱');
    expect(item.calories, 120);
    expect(item.protein, 8.5);
    expect(item.carbs, 10.25);
    expect(item.fat, 4.75);
    expect(item.totalCalories, 180);
    expect(item.totalProtein, 12.75);
    expect(item.totalCarbs, 15.375);
    expect(item.totalFat, 7.125);
  });

  test('deletes a cloud meal only after Supabase confirms the row', () async {
    final repository = buildRepository((request) async {
      expect(request.method, 'DELETE');
      expect(request.url.path, '/rest/v1/meal_records');
      expect(request.url.queryParameters['id'], 'eq.$_mealId');
      return jsonResponse(request, [
        {'id': _mealId},
      ]);
    });

    await repository.deleteMealRecord(
      MealItem(
        cloudRecordId: _mealId,
        foodCloudId: _foodId,
        date: '2026-07-24',
        mealType: 'breakfast',
        servings: 1,
        foodName: '食品',
        calories: 100,
        protein: 10,
      ),
    );
  });

  test('rejects requests without a signed-in user', () async {
    var requests = 0;
    final repository = buildRepository((request) async {
      requests += 1;
      return jsonResponse(request, []);
    }, userId: null);

    await expectLater(
      repository.getMealRecordsByDate('2026-07-24'),
      throwsA(
        isA<MealRepositoryException>().having(
          (error) => error.kind,
          'kind',
          MealRepositoryFailureKind.unauthenticated,
        ),
      ),
    );
    expect(requests, 0);
  });

  test('maps RLS, missing food, foreign key, and network failures', () async {
    Future<void> expectFailure(
      String code,
      MealRepositoryFailureKind expectedKind,
    ) async {
      final repository = buildRepository(
        (request) async => jsonResponse(request, {
          'code': code,
          'message': 'database error',
        }, statusCode: 400),
      );
      await expectLater(
        repository.insertMealRecord(newCloudMeal()),
        throwsA(
          isA<MealRepositoryException>().having(
            (error) => error.kind,
            'kind',
            expectedKind,
          ),
        ),
      );
    }

    await expectFailure('42501', MealRepositoryFailureKind.permissionDenied);
    await expectFailure('P0002', MealRepositoryFailureKind.foodUnavailable);
    await expectFailure('23503', MealRepositoryFailureKind.foodUnavailable);

    final networkRepository = buildRepository(
      (request) async => throw ClientException('Failed to fetch', request.url),
    );
    await expectLater(
      networkRepository.getMealRecordsByDate('2026-07-24'),
      throwsA(
        isA<MealRepositoryException>().having(
          (error) => error.kind,
          'kind',
          MealRepositoryFailureKind.network,
        ),
      ),
    );
  });

  test('rejects malformed Supabase meal data', () async {
    final repository = buildRepository(
      (request) async => jsonResponse(request, [
        {...mealRow(), 'servings': 'not-a-number'},
      ]),
    );

    await expectLater(
      repository.getMealItemsByDateAndMealType('2026-07-24', 'breakfast'),
      throwsA(
        isA<MealRepositoryException>().having(
          (error) => error.kind,
          'kind',
          MealRepositoryFailureKind.invalidData,
        ),
      ),
    );
  });
}
