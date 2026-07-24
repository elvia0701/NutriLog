import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart';
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:nutrilog/models/food.dart';
import 'package:nutrilog/repositories/food_repository.dart';
import 'package:nutrilog/repositories/supabase_food_repository.dart';

const _userId = '11111111-1111-4111-8111-111111111111';
const _foodId = '22222222-2222-4222-8222-222222222222';

Map<String, dynamic> foodRow({
  String id = _foodId,
  String name = '無糖茶',
  int calories = 0,
  num protein = 0,
  num carbs = 0,
  num fat = 0,
  bool favorite = false,
  bool isArchived = false,
}) {
  return {
    'id': id,
    'name': name,
    'calories': calories,
    'protein': protein,
    'carbs': carbs,
    'fat': fat,
    'favorite': favorite,
    'is_archived': isArchived,
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

SupabaseFoodRepository buildRepository(
  Future<Response> Function(Request request) handler, {
  String? userId = _userId,
}) {
  final client = SupabaseClient(
    'https://example.supabase.co',
    'test-anon-key',
    accessToken: () async => 'test-access-token',
    httpClient: MockClient(handler),
  );
  return SupabaseFoodRepository(client, currentUserId: () => userId);
}

void main() {
  test(
    'lists active same-name foods and maps zero nutrients with UUIDs',
    () async {
      final secondId = '33333333-3333-4333-8333-333333333333';
      final repository = buildRepository((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/rest/v1/foods');
        expect(request.url.queryParameters['is_archived'], 'eq.false');
        expect(
          request.url.queryParameters['order'],
          'name.asc.nullslast,created_at.asc.nullslast',
        );
        expect(request.headers['authorization'], 'Bearer test-access-token');
        return jsonResponse(request, [foodRow(), foodRow(id: secondId)]);
      });

      final foods = await repository.getFoods();

      expect(foods, hasLength(2));
      expect(foods.map((food) => food.name), everyElement('無糖茶'));
      expect(foods.first.cloudId, _foodId);
      expect(foods.last.cloudId, secondId);
      expect(foods.first.id, isNull);
      expect(foods.first.calories, 0);
      expect(foods.first.protein, 0);
      expect(foods.first.carbs, 0);
      expect(foods.first.fat, 0);
    },
  );

  test(
    'creates, updates favorite, counts references, and deletes food',
    () async {
      var requestNumber = 0;
      final repository = buildRepository((request) async {
        requestNumber += 1;
        switch (requestNumber) {
          case 1:
            expect(request.method, 'POST');
            expect(request.url.path, '/rest/v1/foods');
            final body = jsonDecode(request.body) as Map<String, dynamic>;
            expect(body['user_id'], _userId);
            expect(body['name'], '優格');
            expect(body['calories'], 0);
            expect(body['protein'], 0);
            expect(body['carbs'], 0);
            expect(body['fat'], 0);
            expect(body.containsKey('id'), isFalse);
            return jsonResponse(request, foodRow(name: '優格'));
          case 2:
            expect(request.method, 'PATCH');
            expect(request.url.path, '/rest/v1/foods');
            expect(request.url.queryParameters['id'], 'eq.$_foodId');
            final body = jsonDecode(request.body) as Map<String, dynamic>;
            expect(body['favorite'], isTrue);
            expect(body.containsKey('user_id'), isFalse);
            return jsonResponse(request, [
              {'id': _foodId},
            ]);
          case 3:
            expect(request.method, 'GET');
            expect(request.url.path, '/rest/v1/meal_records');
            expect(request.url.queryParameters['food_id'], 'eq.$_foodId');
            return jsonResponse(request, [
              {'id': 'meal-1'},
              {'id': 'meal-2'},
            ]);
          case 4:
            expect(request.method, 'POST');
            expect(request.url.path, '/rest/v1/rpc/remove_food');
            expect(jsonDecode(request.body), {'food_id': _foodId});
            return jsonResponse(request, 'deleted');
          default:
            fail('Unexpected request: ${request.method} ${request.url}');
        }
      });

      final created = await repository.insertFood(
        Food(name: '優格', calories: 0, protein: 0, carbs: 0, fat: 0),
      );
      expect(created.cloudId, _foodId);
      expect(await repository.updateFood(created.copyWith(favorite: true)), 1);
      expect(await repository.getFoodReferenceCount(created), 2);
      expect(await repository.removeFood(created), FoodRemovalResult.deleted);
      expect(requestNumber, 4);
    },
  );

  test('maps remove_food archived and not-found results', () async {
    var requestNumber = 0;
    final repository = buildRepository((request) async {
      requestNumber += 1;
      if (requestNumber == 1) return jsonResponse(request, 'archived');
      return jsonResponse(request, {
        'code': 'P0002',
        'message': 'Food not found',
      }, statusCode: 400);
    });
    final food = Food(cloudId: _foodId, name: '茶葉蛋', calories: 70, protein: 6);

    expect(await repository.removeFood(food), FoodRemovalResult.archived);
    expect(await repository.removeFood(food), FoodRemovalResult.notFound);
  });

  test(
    'rejects calls without a signed-in user before sending requests',
    () async {
      var requests = 0;
      final repository = buildRepository((request) async {
        requests += 1;
        return jsonResponse(request, []);
      }, userId: null);

      await expectLater(
        repository.getFoods(),
        throwsA(
          isA<FoodRepositoryException>()
              .having(
                (error) => error.kind,
                'kind',
                FoodRepositoryFailureKind.unauthenticated,
              )
              .having((error) => error.message, 'message', contains('重新登入')),
        ),
      );
      expect(requests, 0);
    },
  );

  test('maps RLS, network, and malformed response failures', () async {
    final rlsRepository = buildRepository(
      (request) async => jsonResponse(request, {
        'code': '42501',
        'message': 'permission denied',
      }, statusCode: 403),
    );
    await expectLater(
      rlsRepository.getFoods(),
      throwsA(
        isA<FoodRepositoryException>().having(
          (error) => error.kind,
          'kind',
          FoodRepositoryFailureKind.permissionDenied,
        ),
      ),
    );

    final networkRepository = buildRepository(
      (request) async => throw ClientException('Failed to fetch', request.url),
    );
    await expectLater(
      networkRepository.getFoods(),
      throwsA(
        isA<FoodRepositoryException>().having(
          (error) => error.kind,
          'kind',
          FoodRepositoryFailureKind.network,
        ),
      ),
    );

    final malformedRepository = buildRepository(
      (request) async => jsonResponse(request, [
        {...foodRow(), 'calories': 'not-a-number'},
      ]),
    );
    await expectLater(
      malformedRepository.getFoods(),
      throwsA(
        isA<FoodRepositoryException>().having(
          (error) => error.kind,
          'kind',
          FoodRepositoryFailureKind.invalidData,
        ),
      ),
    );
  });
}
