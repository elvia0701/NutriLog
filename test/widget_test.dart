// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fl_chart/fl_chart.dart';

import 'package:nutrilog/models/food.dart';
import 'package:nutrilog/pages/add_food_page.dart';
import 'package:nutrilog/models/meal_item.dart';
import 'package:nutrilog/models/meal_record.dart';
import 'package:nutrilog/models/weight_record.dart';
import 'package:nutrilog/models/nutrition_goal.dart';
import 'package:nutrilog/pages/food_database_page.dart';
import 'package:nutrilog/pages/home_page.dart';
import 'package:nutrilog/pages/weight_history_page.dart';
import 'package:nutrilog/pages/weight_trend_page.dart';
import 'package:nutrilog/pages/nutrition_goal_page.dart';
import 'package:nutrilog/repositories/nutrition_goal_repository.dart';
import 'package:nutrilog/repositories/food_repository.dart';
import 'package:nutrilog/repositories/meal_repository.dart';
import 'package:nutrilog/repositories/weight_repository.dart';
import 'package:nutrilog/theme/app_theme.dart';
import 'package:nutrilog/widgets/dashboard_summary.dart';
import 'package:nutrilog/widgets/meal_section.dart';
import 'package:nutrilog/widgets/weight_entry_dialog.dart';

Widget buildPageLauncher(Widget page) {
  return MaterialApp(
    home: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: ElevatedButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => page),
            ),
            child: const Text('開啟頁面'),
          ),
        ),
      ),
    ),
  );
}

class FakeWeightRepository implements WeightRepository {
  final List<WeightRecord> records;
  int saveCalls = 0;
  int deleteCalls = 0;

  FakeWeightRepository([List<WeightRecord>? records])
    : records = records ?? <WeightRecord>[];

  @override
  Future<WeightRecord?> getWeightForDate(String date) async {
    for (final record in records) {
      if (record.date == date) return record;
    }
    return null;
  }

  @override
  Future<List<WeightRecord>> getWeightHistory() async => records.toList();

  @override
  Future<void> saveWeight(String date, double weight) async {
    saveCalls += 1;
    final index = records.indexWhere((record) => record.date == date);
    final record = WeightRecord(date: date, weight: weight);
    if (index == -1) {
      records.add(record);
    } else {
      records[index] = record;
    }
  }

  @override
  Future<void> deleteWeight(String date) async {
    deleteCalls += 1;
    records.removeWhere((record) => record.date == date);
  }
}

class FakeNutritionGoalRepository implements NutritionGoalRepository {
  final List<NutritionGoal> goals;
  int saveCalls = 0;

  FakeNutritionGoalRepository([List<NutritionGoal>? goals])
    : goals = goals ?? <NutritionGoal>[];

  @override
  Future<NutritionGoal?> getGoalForDate(String date) async {
    final effective =
        goals.where((goal) => goal.effectiveDate.compareTo(date) <= 0).toList()
          ..sort((a, b) => b.effectiveDate.compareTo(a.effectiveDate));
    return effective.isEmpty ? null : effective.first;
  }

  @override
  Future<List<NutritionGoal>> getGoalHistory() async {
    return goals.toList()
      ..sort((a, b) => a.effectiveDate.compareTo(b.effectiveDate));
  }

  @override
  Future<void> saveGoal(NutritionGoal goal) async {
    saveCalls += 1;
    final index = goals.indexWhere(
      (existing) => existing.effectiveDate == goal.effectiveDate,
    );
    if (index == -1) {
      goals.add(goal);
    } else {
      goals[index] = goal;
    }
  }
}

class FakeFoodRepository implements FoodRepository {
  final Future<List<Food>> Function()? loadFoods;
  final Future<Food> Function(Food food)? createFood;
  final Future<int> Function(Food food)? editFood;
  final Future<int> Function(Food food)? referenceCount;
  final Future<FoodRemovalResult> Function(Food food)? remove;

  FakeFoodRepository({
    this.loadFoods,
    this.createFood,
    this.editFood,
    this.referenceCount,
    this.remove,
  });

  @override
  Future<List<Food>> getFoods() async => loadFoods?.call() ?? [];

  @override
  Future<Food> insertFood(Food food) async {
    return createFood?.call(food) ?? food.copyWith(id: 1);
  }

  @override
  Future<int> updateFood(Food food) async => editFood?.call(food) ?? 1;

  @override
  Future<int> getFoodReferenceCount(Food food) async {
    return referenceCount?.call(food) ?? 0;
  }

  @override
  Future<FoodRemovalResult> removeFood(Food food) async {
    return remove?.call(food) ?? FoodRemovalResult.deleted;
  }
}

class FakeMealRepository implements MealRepository {
  final Future<int> Function(MealRecord mealRecord)? createMealRecord;
  final Future<List<MealItem>> Function(String date, String mealType)?
  loadMealItems;
  final Future<void> Function(MealItem item)? deleteRecord;

  FakeMealRepository({
    this.createMealRecord,
    this.loadMealItems,
    this.deleteRecord,
  });

  @override
  Future<MealRecord> insertMealRecord(MealRecord mealRecord) async {
    final id = await createMealRecord?.call(mealRecord) ?? 1;
    return mealRecord.copyWith(id: id);
  }

  @override
  Future<List<MealRecord>> getAllMealRecords() async => [];

  @override
  Future<List<MealRecord>> getMealRecordsByDate(String date) async => [];

  @override
  Future<List<MealRecord>> getMealRecordsByDateAndMealType(
    String date,
    String mealType,
  ) async => [];

  @override
  Future<List<MealItem>> getMealItemsByDateAndMealType(
    String date,
    String mealType,
  ) async {
    return loadMealItems?.call(date, mealType) ?? [];
  }

  @override
  Future<void> deleteMealRecord(MealItem item) async {
    await deleteRecord?.call(item);
  }
}

void main() {
  testWidgets('Add food page renders its input fields', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: AddFoodPage()));

    expect(find.text('建立新食物'), findsOneWidget);
    expect(find.text('食物名稱'), findsOneWidget);
    expect(find.text('熱量 kcal'), findsOneWidget);
    expect(find.text('蛋白質 g'), findsOneWidget);
    expect(find.text('碳水 g'), findsOneWidget);
    expect(find.text('脂肪 g'), findsOneWidget);
    expect(find.text('建立食物'), findsOneWidget);
  });

  testWidgets('Zero values are valid for every food nutrient', (
    WidgetTester tester,
  ) async {
    Food? insertedFood;
    final page = FoodDatabasePage(
      mealType: 'snack',
      date: '2026-07-21',
      foodRepository: FakeFoodRepository(
        loadFoods: () async => [],
        createFood: (food) async {
          insertedFood = food;
          return food.copyWith(id: 1);
        },
      ),
      mealRepository: FakeMealRepository(createMealRecord: (_) async => 1),
    );
    await tester.pumpWidget(buildPageLauncher(page));
    await tester.tap(find.text('開啟頁面'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('createNewFoodButton')));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('foodNameField')), '無糖茶');
    await tester.enterText(find.byKey(const Key('foodCaloriesField')), '0');
    await tester.enterText(find.byKey(const Key('foodProteinField')), '0');
    await tester.enterText(find.byKey(const Key('foodCarbsField')), '0');
    await tester.enterText(find.byKey(const Key('foodFatField')), '0');
    await tester.ensureVisible(find.byKey(const Key('saveFoodButton')));
    await tester.tap(find.byKey(const Key('saveFoodButton')));
    await tester.pumpAndSettle();

    expect(insertedFood?.calories, 0);
    expect(insertedFood?.protein, 0);
    expect(insertedFood?.carbs, 0);
    expect(insertedFood?.fat, 0);
  });

  testWidgets('Food nutrients reject negative, blank, and non-numeric input', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: AddFoodPage()));
    await tester.enterText(find.byKey(const Key('foodNameField')), '   ');
    await tester.enterText(find.byKey(const Key('foodCaloriesField')), '-1');
    await tester.enterText(find.byKey(const Key('foodProteinField')), '-0.1');
    await tester.enterText(find.byKey(const Key('foodCarbsField')), '');
    await tester.enterText(find.byKey(const Key('foodFatField')), 'abc');
    await tester.ensureVisible(find.byKey(const Key('saveFoodButton')));
    await tester.tap(find.byKey(const Key('saveFoodButton')));
    await tester.pump();

    expect(find.text('請輸入食物名稱'), findsOneWidget);
    expect(find.text('熱量不可小於 0'), findsOneWidget);
    expect(find.text('蛋白質不可小於 0'), findsOneWidget);
    expect(find.text('請輸入碳水'), findsOneWidget);
    expect(find.text('脂肪必須是數字'), findsOneWidget);
  });

  testWidgets('Zero nutrient meal renders and summarizes without errors', (
    WidgetTester tester,
  ) async {
    final item = MealItem(
      recordId: 88,
      foodId: 8,
      date: '2026-07-21',
      mealType: 'snack',
      servings: 2,
      foodName: '無糖茶',
      calories: 0,
      protein: 0,
      carbs: 0,
      fat: 0,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            children: [
              const DashboardSummary(
                totalCalories: 0,
                totalProtein: 0,
                goal: NutritionGoal(
                  effectiveDate: '2026-07-21',
                  calorieTarget: 1600,
                  proteinTarget: 100,
                ),
              ),
              MealSection(
                title: '點心',
                mealType: 'snack',
                date: '2026-07-21',
                canEdit: false,
                foodRepository: FakeFoodRepository(),
                mealRepository: FakeMealRepository(),
                items: [item],
                onMealAdded: () async {},
                onDelete: (_) async {},
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('0 / 1600 kcal'), findsOneWidget);
    expect(find.text('0 / 100 g'), findsOneWidget);
    expect(find.text('2 份・0 kcal・0 g 蛋白質'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Editing a food uses the same zero-friendly validation', (
    WidgetTester tester,
  ) async {
    Food? updatedFood;
    final original = Food(
      id: 8,
      name: '原食物',
      calories: 100,
      protein: 10,
      carbs: 20,
      fat: 5,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: FoodDatabasePage(
          mealType: 'lunch',
          date: '2026-07-21',
          foodRepository: FakeFoodRepository(
            loadFoods: () async =>
                updatedFood == null ? [original] : [updatedFood!],
            editFood: (food) async {
              updatedFood = food;
              return 1;
            },
          ),
          mealRepository: FakeMealRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('edit_food_8')));
    await tester.pumpAndSettle();

    expect(find.text('編輯食物'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('foodCaloriesField')), '0');
    await tester.enterText(find.byKey(const Key('foodProteinField')), '0');
    await tester.enterText(find.byKey(const Key('foodCarbsField')), '0');
    await tester.enterText(find.byKey(const Key('foodFatField')), '0');
    await tester.ensureVisible(find.byKey(const Key('saveFoodButton')));
    await tester.tap(find.byKey(const Key('saveFoodButton')));
    await tester.pumpAndSettle();

    expect(updatedFood?.id, 8);
    expect(updatedFood?.protein, 0);
    expect(updatedFood?.carbs, 0);
    expect(updatedFood?.fat, 0);
  });

  testWidgets('Dashboard summary displays daily totals', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: DashboardSummary(
            totalCalories: 450,
            totalProtein: 32.5,
            goal: NutritionGoal(
              effectiveDate: '2026-07-20',
              calorieTarget: 1600,
              proteinTarget: 100,
            ),
          ),
        ),
      ),
    );

    expect(find.text('剩餘熱量'), findsOneWidget);
    expect(find.text('1150 kcal'), findsOneWidget);
    expect(find.text('450 / 1600 kcal'), findsOneWidget);
    expect(find.text('剩餘蛋白質'), findsOneWidget);
    expect(find.text('67.5 g'), findsOneWidget);
    expect(find.text('32.5 / 100 g'), findsOneWidget);
  });

  testWidgets(
    'Homepage summary remains usable on a narrow screen with large text',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      tester.view.platformDispatcher.textScaleFactorTestValue = 1.6;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.platformDispatcher.clearTextScaleFactorTestValue);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(
            body: SingleChildScrollView(
              child: DashboardSummary(
                totalCalories: 1800,
                totalProtein: 120,
                goal: NutritionGoal(
                  effectiveDate: '2026-07-20',
                  calorieTarget: 1600,
                  proteinTarget: 100,
                ),
                weight: 90.5,
                canEditWeight: true,
              ),
            ),
          ),
        ),
      );

      expect(find.text('超出 200 kcal'), findsOneWidget);
      expect(find.text('超出 20 g'), findsOneWidget);
      expect(find.text('90.5 kg'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Meal servings default to one', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: AddFoodPage(mealType: 'breakfast')),
    );

    final servingsField = tester.widget<TextFormField>(
      find.byKey(const Key('servingsField')),
    );

    expect(servingsField.controller?.text, '1');
  });

  for (final invalidServings in ['', '0', '-1', 'not-a-number']) {
    testWidgets('Meal servings reject "$invalidServings"', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: AddFoodPage(mealType: 'breakfast')),
      );

      await tester.enterText(find.widgetWithText(TextField, '食物名稱'), '茶葉蛋');
      await tester.enterText(find.widgetWithText(TextField, '熱量 kcal'), '70');
      await tester.enterText(find.widgetWithText(TextField, '蛋白質 g'), '6');
      await tester.enterText(find.widgetWithText(TextField, '碳水 g'), '0');
      await tester.enterText(find.widgetWithText(TextField, '脂肪 g'), '0');
      await tester.enterText(
        find.byKey(const Key('servingsField')),
        invalidServings,
      );
      await tester.tap(find.text('建立並加入這一餐'));
      await tester.pump();

      expect(find.text('份數必須是大於 0 的數字'), findsOneWidget);
    });
  }

  testWidgets('Food database lists and searches foods case-insensitively', (
    WidgetTester tester,
  ) async {
    final foods = [
      Food(id: 1, name: 'Apple', calories: 95, protein: 0.5),
      Food(id: 2, name: 'Apple', calories: 120, protein: 1),
      Food(id: 3, name: '茶葉蛋', calories: 70, protein: 6),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: FoodDatabasePage(
          mealType: 'breakfast',
          date: '2026-07-20',
          foodRepository: FakeFoodRepository(loadFoods: () async => foods),
          mealRepository: FakeMealRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Apple'), findsNWidgets(2));
    expect(find.text('每份 95 kcal • 蛋白質 0.5 g'), findsOneWidget);
    expect(find.text('茶葉蛋'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('foodSearchField')), 'APPLE');
    await tester.pump();

    expect(find.text('Apple'), findsNWidgets(2));
    expect(find.text('茶葉蛋'), findsNothing);

    await tester.enterText(find.byKey(const Key('foodSearchField')), '不存在');
    await tester.pump();

    expect(find.text('找不到食物'), findsOneWidget);
    expect(find.text('建立新食物'), findsWidgets);
  });

  testWidgets('Food database ends loading and displays loaded foods', (
    WidgetTester tester,
  ) async {
    final pendingFoods = Completer<List<Food>>();
    await tester.pumpWidget(
      MaterialApp(
        home: FoodDatabasePage(
          mealType: 'breakfast',
          date: '2026-07-20',
          foodRepository: FakeFoodRepository(
            loadFoods: () => pendingFoods.future,
          ),
          mealRepository: FakeMealRepository(),
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    pendingFoods.complete([
      Food(id: 1, name: '香蕉', calories: 90, protein: 1.1),
    ]);
    await tester.pumpAndSettle();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('香蕉'), findsOneWidget);
  });

  testWidgets(
    'Food database shows repository error and can retry successfully',
    (WidgetTester tester) async {
      var loadCalls = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: FoodDatabasePage(
            mealType: 'breakfast',
            date: '2026-07-20',
            foodRepository: FakeFoodRepository(
              loadFoods: () async {
                loadCalls += 1;
                if (loadCalls == 1) {
                  throw const FoodRepositoryException(
                    FoodRepositoryFailureKind.network,
                    '無法連線至雲端服務，請確認網路後再試。',
                  );
                }
                return [Food(id: 2, name: '蘋果', calories: 95, protein: 0.5)];
              },
            ),
            mealRepository: FakeMealRepository(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('無法載入食物資料'), findsOneWidget);
      expect(find.text('無法連線至雲端服務，請確認網路後再試。'), findsOneWidget);
      expect(find.byKey(const Key('retryLoadFoodsButton')), findsOneWidget);
      expect(find.byKey(const Key('foodSearchField')), findsNothing);

      await tester.tap(find.byKey(const Key('retryLoadFoodsButton')));
      await tester.pumpAndSettle();

      expect(loadCalls, 2);
      expect(find.text('無法載入食物資料'), findsNothing);
      expect(find.text('蘋果'), findsOneWidget);
    },
  );

  testWidgets('Empty food database offers first food creation', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: FoodDatabasePage(
          mealType: 'lunch',
          date: '2026-07-20',
          foodRepository: FakeFoodRepository(loadFoods: () async => []),
          mealRepository: FakeMealRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('食物資料庫目前沒有食物'), findsOneWidget);
    expect(find.text('建立第一個食物'), findsOneWidget);
  });

  testWidgets(
    'Cloud food creation writes a cloud meal without a SQLite food id',
    (WidgetTester tester) async {
      var mealInsertCalls = 0;
      MealRecord? insertedMeal;
      final page = FoodDatabasePage(
        mealType: 'lunch',
        date: '2026-07-20',
        foodRepository: FakeFoodRepository(
          loadFoods: () async => [],
          createFood: (food) async =>
              food.copyWith(cloudId: '22222222-2222-4222-8222-222222222222'),
        ),
        mealRepository: FakeMealRepository(
          createMealRecord: (record) async {
            mealInsertCalls += 1;
            insertedMeal = record;
            return 1;
          },
        ),
      );
      await tester.pumpWidget(buildPageLauncher(page));
      await tester.tap(find.text('開啟頁面'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('createNewFoodButton')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('servingsField')), findsOneWidget);
      expect(find.text('建立並加入這一餐'), findsOneWidget);

      await tester.enterText(find.byKey(const Key('foodNameField')), '無糖茶');
      await tester.enterText(find.byKey(const Key('foodCaloriesField')), '0');
      await tester.enterText(find.byKey(const Key('foodProteinField')), '0');
      await tester.enterText(find.byKey(const Key('foodCarbsField')), '0');
      await tester.enterText(find.byKey(const Key('foodFatField')), '0');
      await tester.enterText(find.byKey(const Key('servingsField')), '1.5');
      await tester.tap(find.byKey(const Key('saveFoodButton')));
      await tester.pumpAndSettle();

      expect(mealInsertCalls, 1);
      expect(insertedMeal?.foodId, isNull);
      expect(insertedMeal?.foodCloudId, '22222222-2222-4222-8222-222222222222');
      expect(insertedMeal?.servings, 1.5);
      expect(insertedMeal?.foodNameSnapshot, '無糖茶');
    },
  );

  testWidgets('Favorite button updates a cloud food through repository', (
    WidgetTester tester,
  ) async {
    var food = Food(
      cloudId: '22222222-2222-4222-8222-222222222222',
      name: '優格',
      calories: 100,
      protein: 8,
    );
    Food? updatedFood;
    await tester.pumpWidget(
      MaterialApp(
        home: FoodDatabasePage(
          mealType: 'snack',
          date: '2026-07-20',
          foodRepository: FakeFoodRepository(
            loadFoods: () async => [food],
            editFood: (updated) async {
              updatedFood = updated;
              food = updated;
              return 1;
            },
          ),
          mealRepository: FakeMealRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(
        const ValueKey('favorite_food_22222222-2222-4222-8222-222222222222'),
      ),
    );
    await tester.pumpAndSettle();

    expect(updatedFood?.cloudId, food.cloudId);
    expect(updatedFood?.favorite, isTrue);
    expect(find.byTooltip('取消常用'), findsOneWidget);
  });

  testWidgets('Unused food can be deleted without clearing search', (
    WidgetTester tester,
  ) async {
    int? deletedFoodId;
    await tester.pumpWidget(
      MaterialApp(
        home: FoodDatabasePage(
          mealType: 'breakfast',
          date: '2026-07-20',
          foodRepository: FakeFoodRepository(
            loadFoods: () async => [
              Food(id: 1, name: 'Apple', calories: 95, protein: 0.5),
              Food(id: 2, name: '香蕉', calories: 90, protein: 1.1),
            ],
            referenceCount: (food) async => 0,
            remove: (food) async {
              deletedFoodId = food.id;
              return FoodRemovalResult.deleted;
            },
          ),
          mealRepository: FakeMealRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('foodSearchField')), 'app');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('delete_food_1')));
    await tester.pumpAndSettle();

    expect(find.text('確定要永久刪除「Apple」嗎？此操作無法復原。'), findsOneWidget);

    await tester.tap(find.text('移除'));
    await tester.pumpAndSettle();

    expect(deletedFoodId, 1);
    expect(find.text('Apple'), findsNothing);
    expect(find.text('app'), findsOneWidget);
    expect(find.text('找不到食物'), findsOneWidget);
  });

  testWidgets('Referenced food is archived and removed from search results', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: FoodDatabasePage(
          mealType: 'lunch',
          date: '2026-07-20',
          foodRepository: FakeFoodRepository(
            loadFoods: () async => [
              Food(id: 7, name: '茶葉蛋', calories: 70, protein: 6),
            ],
            referenceCount: (food) async => 1,
            remove: (food) async => FoodRemovalResult.archived,
          ),
          mealRepository: FakeMealRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('foodSearchField')), '茶葉');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('delete_food_7')));
    await tester.pumpAndSettle();

    expect(
      find.text(
        '「茶葉蛋」曾用於歷史飲食紀錄。'
        '移除後會封存並從可選食物中隱藏，歷史餐點會保留。',
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('移除'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('茶葉蛋'), findsNothing);
    expect(find.text('茶葉'), findsOneWidget);
    expect(find.text('食物已封存，歷史餐點仍會保留。'), findsOneWidget);
  });

  testWidgets('Cancelling food deletion leaves the food unchanged', (
    WidgetTester tester,
  ) async {
    var deleteCalls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: FoodDatabasePage(
          mealType: 'snack',
          date: '2026-07-20',
          foodRepository: FakeFoodRepository(
            loadFoods: () async => [
              Food(id: 9, name: '優格', calories: 100, protein: 8),
            ],
            referenceCount: (food) async => 0,
            remove: (food) async {
              deleteCalls += 1;
              return FoodRemovalResult.deleted;
            },
          ),
          mealRepository: FakeMealRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('delete_food_9')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();

    expect(deleteCalls, 0);
    expect(find.text('優格'), findsOneWidget);
  });

  testWidgets('Selecting an existing food only creates a meal record', (
    WidgetTester tester,
  ) async {
    var insertedFoodCount = 0;
    MealRecord? insertedMealRecord;
    final page = FoodDatabasePage(
      mealType: 'dinner',
      date: '2026-07-19',
      foodRepository: FakeFoodRepository(
        loadFoods: () async => [
          Food(id: 7, name: '茶葉蛋', calories: 70, protein: 6),
        ],
        createFood: (food) async {
          insertedFoodCount += 1;
          return food.copyWith(id: 99);
        },
      ),
      mealRepository: FakeMealRepository(
        createMealRecord: (mealRecord) async {
          insertedMealRecord = mealRecord;
          return 1;
        },
      ),
    );

    await tester.pumpWidget(buildPageLauncher(page));
    await tester.tap(find.text('開啟頁面'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('茶葉蛋'));
    await tester.pumpAndSettle();

    final servingsField = tester.widget<TextField>(
      find.byKey(const Key('existingFoodServingsField')),
    );
    expect(servingsField.controller?.text, '1');

    await tester.enterText(
      find.byKey(const Key('existingFoodServingsField')),
      '0',
    );
    await tester.tap(find.text('加入餐點'));
    await tester.pump();

    expect(find.text('份數必須是大於 0 的數字'), findsOneWidget);
    expect(insertedMealRecord, isNull);

    await tester.enterText(
      find.byKey(const Key('existingFoodServingsField')),
      '2',
    );
    await tester.tap(find.text('加入餐點'));
    await tester.pumpAndSettle();

    expect(insertedFoodCount, 0);
    expect(insertedMealRecord?.foodId, 7);
    expect(insertedMealRecord?.mealType, 'dinner');
    expect(insertedMealRecord?.date, '2026-07-19');
    expect(insertedMealRecord?.servings, 2);
    expect(insertedMealRecord?.foodNameSnapshot, '茶葉蛋');
    expect(insertedMealRecord?.caloriesSnapshot, 70);
    expect(insertedMealRecord?.proteinSnapshot, 6);
  });

  testWidgets('Failed cloud meal insert stays on food page and shows error', (
    WidgetTester tester,
  ) async {
    final page = FoodDatabasePage(
      mealType: 'dinner',
      date: '2026-07-24',
      foodRepository: FakeFoodRepository(
        loadFoods: () async => [
          Food(
            cloudId: '22222222-2222-4222-8222-222222222222',
            name: '已封存食品',
            calories: 70,
            protein: 6,
          ),
        ],
      ),
      mealRepository: FakeMealRepository(
        createMealRecord: (_) async {
          throw const MealRepositoryException(
            MealRepositoryFailureKind.foodUnavailable,
            '這項食品不存在、已封存或無法使用，請重新選擇食品。',
          );
        },
      ),
    );
    await tester.pumpWidget(buildPageLauncher(page));
    await tester.tap(find.text('開啟頁面'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('已封存食品'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('加入餐點'));
    await tester.pumpAndSettle();

    expect(find.text('食物資料庫'), findsOneWidget);
    expect(find.text('這項食品不存在、已封存或無法使用，請重新選擇食品。'), findsOneWidget);
  });

  testWidgets('Creating a new food inserts one food and one meal record', (
    WidgetTester tester,
  ) async {
    var insertedFoodCount = 0;
    var insertedMealCount = 0;
    Food? insertedFood;
    MealRecord? insertedMealRecord;
    final page = FoodDatabasePage(
      mealType: 'snack',
      date: '2026-07-20',
      foodRepository: FakeFoodRepository(
        loadFoods: () async => [
          Food(id: 1, name: '香蕉', calories: 90, protein: 1.1),
        ],
        createFood: (food) async {
          insertedFoodCount += 1;
          insertedFood = food;
          return food.copyWith(id: 42);
        },
      ),
      mealRepository: FakeMealRepository(
        createMealRecord: (mealRecord) async {
          insertedMealCount += 1;
          insertedMealRecord = mealRecord;
          return 8;
        },
      ),
    );

    await tester.pumpWidget(buildPageLauncher(page));
    await tester.tap(find.text('開啟頁面'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('createNewFoodButton')));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, '食物名稱'), '優格');
    await tester.enterText(find.widgetWithText(TextField, '熱量 kcal'), '100');
    await tester.enterText(find.widgetWithText(TextField, '蛋白質 g'), '8');
    await tester.enterText(find.widgetWithText(TextField, '碳水 g'), '0');
    await tester.enterText(find.widgetWithText(TextField, '脂肪 g'), '0');
    await tester.enterText(find.byKey(const Key('servingsField')), '1.5');
    await tester.tap(find.text('建立並加入這一餐'));
    await tester.pumpAndSettle();

    expect(insertedFoodCount, 1);
    expect(insertedMealCount, 1);
    expect(insertedFood?.name, '優格');
    expect(insertedMealRecord?.foodId, 42);
    expect(insertedMealRecord?.mealType, 'snack');
    expect(insertedMealRecord?.servings, 1.5);
    expect(insertedMealRecord?.foodNameSnapshot, '優格');
  });

  testWidgets('Meal item displays details and confirms deletion', (
    WidgetTester tester,
  ) async {
    var deletedRecordId = 0;
    final item = MealItem(
      recordId: 7,
      foodId: 3,
      date: '2026-07-20',
      mealType: 'breakfast',
      servings: 2,
      foodName: '茶葉蛋',
      calories: 70,
      protein: 6,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MealSection(
            title: '早餐',
            mealType: 'breakfast',
            date: '2026-07-20',
            canEdit: true,
            foodRepository: FakeFoodRepository(),
            mealRepository: FakeMealRepository(),
            items: [item],
            onMealAdded: () async {},
            onDelete: (item) async {
              deletedRecordId = item.recordId!;
            },
          ),
        ),
      ),
    );

    expect(find.text('茶葉蛋'), findsOneWidget);
    expect(find.text('2 份・140 kcal・12 g 蛋白質'), findsOneWidget);
    expect(item.totalCalories, 140);
    expect(item.totalProtein, 12);

    await tester.tap(find.byTooltip('刪除餐點'));
    await tester.pumpAndSettle();

    expect(find.text('刪除餐點紀錄？'), findsOneWidget);
    expect(find.text('確定要刪除「茶葉蛋」嗎？'), findsOneWidget);

    await tester.tap(find.text('刪除'));
    await tester.pumpAndSettle();

    expect(deletedRecordId, 7);
  });

  testWidgets('Home switches dates and keeps daily summaries independent', (
    WidgetTester tester,
  ) async {
    final goalRepository = FakeNutritionGoalRepository([
      const NutritionGoal(
        effectiveDate: '2026-07-01',
        calorieTarget: 1400,
        proteinTarget: 80,
      ),
      const NutritionGoal(
        effectiveDate: '2026-07-20',
        calorieTarget: 1600,
        proteinTarget: 100,
      ),
    ]);
    Future<List<MealItem>> loader(String date, String mealType) async {
      if (date == '2026-07-20' && mealType == 'lunch') {
        return [
          MealItem(
            recordId: 1,
            foodId: 1,
            date: date,
            mealType: mealType,
            servings: 1,
            foodName: '今天午餐',
            calories: 100,
            protein: 10,
          ),
        ];
      }
      if (date == '2026-07-19' && mealType == 'breakfast') {
        return [
          MealItem(
            recordId: 2,
            foodId: 2,
            date: date,
            mealType: mealType,
            servings: 2,
            foodName: '昨日早餐',
            calories: 60,
            protein: 4,
          ),
        ];
      }
      return [];
    }

    await tester.pumpWidget(
      MaterialApp(
        home: HomePage(
          foodRepository: FakeFoodRepository(),
          mealRepository: FakeMealRepository(),
          weightRepository: FakeWeightRepository(),
          nutritionGoalRepository: goalRepository,
          todayOverride: DateTime(2026, 7, 20),
          mealItemsLoader: loader,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('今天'), findsOneWidget);
    expect(find.text('2026年7月20日'), findsOneWidget);
    expect(find.text('1500 kcal'), findsOneWidget);
    expect(find.text('100 / 1600 kcal'), findsOneWidget);
    expect(find.text('90 g'), findsOneWidget);
    expect(find.text('10 / 100 g'), findsOneWidget);
    final nextButton = tester.widget<IconButton>(
      find.byKey(const Key('nextDayButton')),
    );
    expect(nextButton.onPressed, isNull);

    await tester.tap(find.byKey(const Key('previousDayButton')));
    await tester.pumpAndSettle();

    expect(find.text('2026年7月19日 星期日'), findsOneWidget);
    expect(find.text('1280 kcal'), findsOneWidget);
    expect(find.text('120 / 1400 kcal'), findsOneWidget);
    expect(find.text('72 g'), findsOneWidget);
    expect(find.text('8 / 80 g'), findsOneWidget);
    expect(find.text('此日已封存'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('昨日早餐'), 300);
    expect(find.text('昨日早餐'), findsOneWidget);
    expect(find.text('今天午餐'), findsNothing);
    expect(find.text('新增餐點'), findsNothing);
    expect(find.byTooltip('刪除餐點'), findsNothing);
  });

  testWidgets('Home meal loading ends and repository errors can be retried', (
    WidgetTester tester,
  ) async {
    final pendingMeals = Completer<List<MealItem>>();
    var failLoads = false;
    Future<List<MealItem>> loader(String date, String mealType) {
      if (failLoads) {
        throw const MealRepositoryException(
          MealRepositoryFailureKind.network,
          '無法連線至雲端服務，請確認網路後再試。',
        );
      }
      return pendingMeals.future;
    }

    await tester.pumpWidget(
      MaterialApp(
        home: HomePage(
          foodRepository: FakeFoodRepository(),
          mealRepository: FakeMealRepository(),
          weightRepository: FakeWeightRepository(),
          nutritionGoalRepository: FakeNutritionGoalRepository(),
          localProfileDataEnabled: false,
          todayOverride: DateTime(2026, 7, 24),
          mealItemsLoader: loader,
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const Key('mealLoadingIndicator')), findsOneWidget);
    pendingMeals.complete([]);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('mealLoadingIndicator')), findsNothing);

    failLoads = true;
    await tester.tap(find.byKey(const Key('previousDayButton')));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView).first, const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('mealLoadError')), findsOneWidget);
    expect(find.text('無法連線至雲端服務，請確認網路後再試。'), findsOneWidget);

    failLoads = false;
    await tester.tap(find.byKey(const Key('retryLoadMealsButton')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('mealLoadError')), findsNothing);
  });

  testWidgets('Cloud meal add and delete immediately refresh Home summary', (
    WidgetTester tester,
  ) async {
    final items = <MealItem>[];
    var nextMeal = 1;
    final mealRepository = FakeMealRepository(
      loadMealItems: (date, mealType) async => items
          .where((item) => item.date == date && item.mealType == mealType)
          .toList(),
      createMealRecord: (record) async {
        items.add(
          MealItem(
            cloudRecordId:
                '33333333-3333-4333-8333-${nextMeal.toString().padLeft(12, '0')}',
            foodCloudId: record.foodCloudId,
            date: record.date,
            mealType: record.mealType,
            servings: record.servings,
            foodName: record.foodNameSnapshot,
            calories: record.caloriesSnapshot,
            protein: record.proteinSnapshot,
            carbs: record.carbsSnapshot,
            fat: record.fatSnapshot,
          ),
        );
        nextMeal += 1;
        return nextMeal;
      },
      deleteRecord: (item) async {
        items.removeWhere(
          (existing) => existing.cloudRecordId == item.cloudRecordId,
        );
      },
    );

    await tester.pumpWidget(
      MaterialApp(
        home: HomePage(
          foodRepository: FakeFoodRepository(
            loadFoods: () async => [
              Food(
                cloudId: '22222222-2222-4222-8222-222222222222',
                name: '雲端食品',
                calories: 100,
                protein: 10,
              ),
            ],
          ),
          mealRepository: mealRepository,
          weightRepository: FakeWeightRepository(),
          nutritionGoalRepository: FakeNutritionGoalRepository(),
          localProfileDataEnabled: false,
          todayOverride: DateTime(2026, 7, 24),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('已攝取 0 kcal'), findsOneWidget);

    await tester.ensureVisible(find.text('新增餐點').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('新增餐點').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('雲端食品'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('existingFoodServingsField')),
      '1.5',
    );
    await tester.tap(find.text('加入餐點'));
    await tester.pumpAndSettle();

    await tester.drag(find.byType(ListView).first, const Offset(0, 1000));
    await tester.pumpAndSettle();
    expect(find.text('已攝取 150 kcal'), findsOneWidget);
    expect(find.text('已攝取 15 g'), findsOneWidget);
    await tester.ensureVisible(find.byTooltip('刪除餐點'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('刪除餐點'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('刪除'));
    await tester.pumpAndSettle();

    await tester.drag(find.byType(ListView).first, const Offset(0, 1000));
    await tester.pumpAndSettle();
    expect(items, isEmpty);
    expect(find.text('已攝取 0 kcal'), findsOneWidget);
    expect(find.text('已攝取 0 g'), findsOneWidget);
  });

  testWidgets('Failed cloud meal deletion keeps the item visible', (
    WidgetTester tester,
  ) async {
    final item = MealItem(
      cloudRecordId: '33333333-3333-4333-8333-333333333333',
      foodCloudId: '22222222-2222-4222-8222-222222222222',
      date: '2026-07-24',
      mealType: 'breakfast',
      servings: 1,
      foodName: '保留的餐點',
      calories: 100,
      protein: 10,
    );
    final repository = FakeMealRepository(
      loadMealItems: (date, mealType) async =>
          mealType == 'breakfast' ? [item] : [],
      deleteRecord: (_) async {
        throw const MealRepositoryException(
          MealRepositoryFailureKind.network,
          '無法連線至雲端服務，請確認網路後再試。',
        );
      },
    );

    await tester.pumpWidget(
      MaterialApp(
        home: HomePage(
          foodRepository: FakeFoodRepository(),
          mealRepository: repository,
          weightRepository: FakeWeightRepository(),
          nutritionGoalRepository: FakeNutritionGoalRepository(),
          localProfileDataEnabled: false,
          todayOverride: DateTime(2026, 7, 24),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byTooltip('刪除餐點'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('刪除餐點'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('刪除'));
    await tester.pumpAndSettle();

    expect(find.text('保留的餐點'), findsOneWidget);
    expect(find.text('無法連線至雲端服務，請確認網路後再試。'), findsOneWidget);
  });

  testWidgets('Past dates are locked, can unlock, and relock after switching', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: HomePage(
          foodRepository: FakeFoodRepository(),
          mealRepository: FakeMealRepository(),
          weightRepository: FakeWeightRepository(),
          nutritionGoalRepository: FakeNutritionGoalRepository(),
          todayOverride: DateTime(2026, 7, 20),
          mealItemsLoader: (_, _) async => [],
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('previousDayButton')));
    await tester.pumpAndSettle();

    expect(find.text('此日已封存'), findsOneWidget);
    expect(find.text('新增餐點'), findsNothing);
    expect(find.byKey(const Key('unlockHistoricalButton')), findsOneWidget);

    await tester.tap(find.byKey(const Key('unlockHistoricalButton')));
    await tester.pumpAndSettle();
    expect(find.text('解鎖歷史日期？'), findsOneWidget);
    await tester.tap(find.text('確認解鎖'));
    await tester.pumpAndSettle();

    expect(find.text('此日已解鎖，可修正餐點與體重'), findsOneWidget);
    expect(find.text('新增餐點'), findsWidgets);

    await tester.tap(find.byKey(const Key('nextDayButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('previousDayButton')));
    await tester.pumpAndSettle();

    expect(find.text('此日已封存'), findsOneWidget);
    expect(find.text('新增餐點'), findsNothing);
  });

  testWidgets('Weight input validates blank, invalid, range, and precision', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () => showDialog<double>(
                context: context,
                builder: (_) => const WeightEntryDialog(),
              ),
              child: const Text('開啟體重輸入'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('開啟體重輸入'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('saveWeightButton')));
    await tester.pump();
    expect(find.text('請輸入體重'), findsOneWidget);

    final invalidInputs = {
      'abc': '請輸入有效的數字',
      '0': '體重必須介於 20–500 kg',
      '-1': '體重必須介於 20–500 kg',
      '501': '體重必須介於 20–500 kg',
      '90.55': '體重最多只能有一位小數',
    };
    for (final entry in invalidInputs.entries) {
      await tester.enterText(find.byKey(const Key('weightField')), entry.key);
      await tester.tap(find.byKey(const Key('saveWeightButton')));
      await tester.pump();
      expect(find.byType(WeightEntryDialog), findsOneWidget);
      expect(find.text(entry.value), findsOneWidget);
    }

    await tester.enterText(find.byKey(const Key('weightField')), '90.5');
    await tester.tap(find.byKey(const Key('saveWeightButton')));
    await tester.pumpAndSettle();
    expect(find.byType(WeightEntryDialog), findsNothing);
  });

  testWidgets('Today weight can be added and edited with current value', (
    WidgetTester tester,
  ) async {
    final weightRepository = FakeWeightRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: HomePage(
          foodRepository: FakeFoodRepository(),
          mealRepository: FakeMealRepository(),
          weightRepository: weightRepository,
          nutritionGoalRepository: FakeNutritionGoalRepository(),
          todayOverride: DateTime(2026, 7, 20),
          mealItemsLoader: (_, _) async => [],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('尚未記錄'), findsOneWidget);
    expect(find.text('記錄體重'), findsOneWidget);
    await tester.tap(find.byKey(const Key('editWeightButton')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('weightField')), '90.5');
    await tester.tap(find.byKey(const Key('saveWeightButton')));
    await tester.pumpAndSettle();

    expect(weightRepository.records.single.date, '2026-07-20');
    expect(weightRepository.records.single.weight, 90.5);
    expect(find.text('90.5 kg'), findsOneWidget);
    expect(find.text('修改體重'), findsOneWidget);

    await tester.tap(find.byKey(const Key('editWeightButton')));
    await tester.pumpAndSettle();
    final field = tester.widget<TextField>(
      find.byKey(const Key('weightField')),
    );
    expect(field.controller?.text, '90.5');
  });

  testWidgets('Past weight is read-only until the date is unlocked', (
    WidgetTester tester,
  ) async {
    final weightRepository = FakeWeightRepository([
      const WeightRecord(date: '2026-07-19', weight: 91),
    ]);
    await tester.pumpWidget(
      MaterialApp(
        home: HomePage(
          foodRepository: FakeFoodRepository(),
          mealRepository: FakeMealRepository(),
          weightRepository: weightRepository,
          nutritionGoalRepository: FakeNutritionGoalRepository(),
          todayOverride: DateTime(2026, 7, 20),
          mealItemsLoader: (_, _) async => [],
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('previousDayButton')));
    await tester.pumpAndSettle();

    expect(find.text('91 kg'), findsOneWidget);
    expect(find.byKey(const Key('editWeightButton')), findsNothing);
    expect(find.byKey(const Key('deleteWeightButton')), findsNothing);

    await tester.tap(find.byKey(const Key('unlockHistoricalButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('確認解鎖'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('editWeightButton')), findsOneWidget);
    expect(find.byKey(const Key('deleteWeightButton')), findsOneWidget);
  });

  testWidgets('Weight deletion requires confirmation and supports cancel', (
    WidgetTester tester,
  ) async {
    final weightRepository = FakeWeightRepository([
      const WeightRecord(date: '2026-07-20', weight: 90),
    ]);
    await tester.pumpWidget(
      MaterialApp(
        home: HomePage(
          foodRepository: FakeFoodRepository(),
          mealRepository: FakeMealRepository(),
          weightRepository: weightRepository,
          nutritionGoalRepository: FakeNutritionGoalRepository(),
          todayOverride: DateTime(2026, 7, 20),
          mealItemsLoader: (_, _) async => [],
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('deleteWeightButton')));
    await tester.pumpAndSettle();
    expect(find.text('刪除體重紀錄？'), findsOneWidget);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(weightRepository.deleteCalls, 0);
    expect(find.text('90 kg'), findsOneWidget);

    await tester.tap(find.byKey(const Key('deleteWeightButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('刪除'));
    await tester.pumpAndSettle();
    expect(weightRepository.deleteCalls, 1);
    expect(find.text('尚未記錄'), findsOneWidget);
  });

  testWidgets('Weight history sorts newest first and has an empty state', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: WeightHistoryPage(
          weightRepository: FakeWeightRepository([
            WeightRecord(date: '2026-07-18', weight: 91.2),
            WeightRecord(date: '2026-07-20', weight: 90.5),
            WeightRecord(date: '2026-07-19', weight: 90.8),
          ]),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final newestTop = tester.getTopLeft(find.text('2026-07-20')).dy;
    final middleTop = tester.getTopLeft(find.text('2026-07-19')).dy;
    final oldestTop = tester.getTopLeft(find.text('2026-07-18')).dy;
    expect(newestTop, lessThan(middleTop));
    expect(middleTop, lessThan(oldestTop));

    await tester.pumpWidget(
      MaterialApp(
        home: WeightHistoryPage(
          key: const ValueKey('emptyWeightHistory'),
          weightRepository: FakeWeightRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('尚無體重紀錄'), findsOneWidget);
  });

  testWidgets('Dashboard shows unconfigured goals and exceeded amounts', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: DashboardSummary(totalCalories: 450, totalProtein: 32.5),
        ),
      ),
    );

    expect(find.text('尚未設定目標'), findsNWidgets(2));
    expect(find.text('已攝取 450 kcal'), findsOneWidget);
    expect(find.text('已攝取 32.5 g'), findsOneWidget);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: DashboardSummary(
            totalCalories: 1700,
            totalProtein: 120,
            goal: NutritionGoal(
              effectiveDate: '2026-07-20',
              calorieTarget: 1600,
              proteinTarget: 100,
            ),
          ),
        ),
      ),
    );

    expect(find.text('超出 100 kcal'), findsOneWidget);
    expect(find.text('超出 20 g'), findsOneWidget);
    expect(find.textContaining('-'), findsNothing);
  });

  testWidgets('Goal settings validate input and reload Home after saving', (
    WidgetTester tester,
  ) async {
    final goalRepository = FakeNutritionGoalRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: HomePage(
          foodRepository: FakeFoodRepository(),
          mealRepository: FakeMealRepository(),
          weightRepository: FakeWeightRepository(),
          nutritionGoalRepository: goalRepository,
          todayOverride: DateTime(2026, 7, 20),
          mealItemsLoader: (_, _) async => [],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('尚未設定目標'), findsNWidgets(2));
    await tester.tap(find.byKey(const Key('nutritionGoalSettingsButton')));
    await tester.pumpAndSettle();

    expect(find.text('營養目標設定'), findsOneWidget);
    expect(find.text('目標不會隨體重自動變更'), findsOneWidget);
    expect(find.text('目前顯示建議值；完成儲存前尚未建立目標。'), findsOneWidget);
    expect(find.text('2026-07-20'), findsOneWidget);

    final calorieField = tester.widget<TextFormField>(
      find.byKey(const Key('calorieTargetField')),
    );
    final proteinField = tester.widget<TextFormField>(
      find.byKey(const Key('proteinTargetField')),
    );
    expect(calorieField.controller?.text, '1600');
    expect(proteinField.controller?.text, '100');

    await tester.enterText(find.byKey(const Key('calorieTargetField')), '0');
    await tester.enterText(
      find.byKey(const Key('proteinTargetField')),
      'not-a-number',
    );
    await tester.tap(find.byKey(const Key('saveNutritionGoalButton')));
    await tester.pump();

    expect(find.text('每日熱量目標必須介於 100–10000 kcal'), findsOneWidget);
    expect(find.text('請輸入有效的每日蛋白質目標'), findsOneWidget);
    expect(goalRepository.goals, isEmpty);

    await tester.enterText(find.byKey(const Key('calorieTargetField')), '1800');
    await tester.enterText(
      find.byKey(const Key('proteinTargetField')),
      '120.5',
    );
    await tester.tap(find.byKey(const Key('saveNutritionGoalButton')));
    await tester.pumpAndSettle();

    expect(goalRepository.goals.single.effectiveDate, '2026-07-20');
    expect(goalRepository.goals.single.calorieTarget, 1800);
    expect(goalRepository.goals.single.proteinTarget, 120.5);
    expect(find.text('1800 kcal'), findsOneWidget);
    expect(find.text('0 / 1800 kcal'), findsOneWidget);
    expect(find.text('120.5 g'), findsOneWidget);
    expect(find.text('0 / 120.5 g'), findsOneWidget);
  });

  testWidgets('Goal page does not allow an effective date before today', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: NutritionGoalPage(
          nutritionGoalRepository: FakeNutritionGoalRepository(),
          todayOverride: DateTime(2026, 7, 20),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('effectiveDatePicker')));
    await tester.pumpAndSettle();

    final calendar = tester.widget<CalendarDatePicker>(
      find.byType(CalendarDatePicker),
    );
    expect(calendar.firstDate, DateTime(2026, 7, 20));
    expect(calendar.initialDate, DateTime(2026, 7, 20));
  });

  testWidgets('Weight history backfills a past date and reloads immediately', (
    WidgetTester tester,
  ) async {
    final records = <WeightRecord>[];
    final weightRepository = FakeWeightRepository(records);
    await tester.pumpWidget(
      MaterialApp(
        home: WeightHistoryPage(
          weightRepository: weightRepository,
          todayOverride: DateTime(2026, 7, 21),
          pickBackfillDate: (_) async => DateTime(2026, 7, 18),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('openWeightTrendButton')), findsOneWidget);
    await tester.tap(find.byKey(const Key('backfillWeightButton')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('weightField')), '91.5');
    await tester.tap(find.byKey(const Key('saveWeightButton')));
    await tester.pumpAndSettle();

    expect(records.single.date, '2026-07-18');
    expect(records.single.weight, 91.5);
    expect(find.text('2026-07-18'), findsOneWidget);
    expect(find.text('91.5 kg'), findsOneWidget);
  });

  testWidgets(
    'Existing backfill requires confirmation and updates one record',
    (WidgetTester tester) async {
      final records = <WeightRecord>[
        const WeightRecord(date: '2026-07-18', weight: 91.5),
      ];
      final weightRepository = FakeWeightRepository(records);
      await tester.pumpWidget(
        MaterialApp(
          home: WeightHistoryPage(
            weightRepository: weightRepository,
            todayOverride: DateTime(2026, 7, 21),
            pickBackfillDate: (_) async => DateTime(2026, 7, 18),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('backfillWeightButton')));
      await tester.pumpAndSettle();
      expect(find.text('此日期已有體重紀錄'), findsOneWidget);
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(weightRepository.saveCalls, 0);
      expect(records, hasLength(1));

      await tester.tap(find.byKey(const Key('backfillWeightButton')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('確認更新'));
      await tester.pumpAndSettle();
      final field = tester.widget<TextField>(
        find.byKey(const Key('weightField')),
      );
      expect(field.controller?.text, '91.5');
      await tester.enterText(find.byKey(const Key('weightField')), '90.8');
      await tester.tap(find.byKey(const Key('saveWeightButton')));
      await tester.pumpAndSettle();

      expect(weightRepository.saveCalls, 1);
      expect(records, hasLength(1));
      expect(records.single.weight, 90.8);
      expect(find.text('90.8 kg'), findsOneWidget);
    },
  );

  testWidgets('Weight backfill rejects a future date', (
    WidgetTester tester,
  ) async {
    final weightRepository = FakeWeightRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: WeightHistoryPage(
          weightRepository: weightRepository,
          todayOverride: DateTime(2026, 7, 21),
          pickBackfillDate: (_) async => DateTime(2026, 7, 22),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('backfillWeightButton')));
    await tester.pumpAndSettle();

    expect(find.byType(WeightEntryDialog), findsNothing);
    expect(weightRepository.saveCalls, 0);
  });

  testWidgets('Weight trend handles empty and selected-period empty states', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: WeightTrendPage(
          weightRepository: FakeWeightRepository(),
          todayOverride: DateTime(2026, 7, 21),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('尚無體重紀錄'), findsOneWidget);
    expect(find.byType(LineChart), findsNothing);
    expect(find.text('記錄體重'), findsWidgets);

    await tester.pumpWidget(
      MaterialApp(
        home: WeightTrendPage(
          key: const ValueKey('periodEmpty'),
          weightRepository: FakeWeightRepository([
            const WeightRecord(date: '2026-01-01', weight: 95),
          ]),
          todayOverride: DateTime(2026, 7, 21),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('此期間尚無體重紀錄'), findsOneWidget);
    expect(find.byType(LineChart), findsNothing);
    final defaultPeriod = tester.widget<ChoiceChip>(
      find.byKey(const ValueKey('weightPeriod_thirtyDays')),
    );
    expect(defaultPeriod.selected, isTrue);

    await tester.tap(find.byKey(const ValueKey('weightPeriod_all')));
    await tester.pumpAndSettle();
    expect(find.byType(LineChart), findsOneWidget);
    expect(find.textContaining('資料不足，尚無法計算變化'), findsOneWidget);
  });

  testWidgets('Trend chart is stable with one or equal-weight points', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 300,
            child: WeightTrendChart(
              records: [WeightRecord(date: '2026-07-21', weight: 90.5)],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(LineChart), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 300,
            child: WeightTrendChart(
              records: [
                WeightRecord(date: '2026-07-18', weight: 90.5),
                WeightRecord(date: '2026-07-21', weight: 90.5),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(LineChart), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Recording from trend reloads chart data immediately', (
    WidgetTester tester,
  ) async {
    final records = <WeightRecord>[];
    final weightRepository = FakeWeightRepository(records);
    await tester.pumpWidget(
      MaterialApp(
        home: WeightTrendPage(
          weightRepository: weightRepository,
          todayOverride: DateTime(2026, 7, 21),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('emptyRecordWeightButton')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('weightField')), '90.5');
    await tester.tap(find.byKey(const Key('saveWeightButton')));
    await tester.pumpAndSettle();

    expect(records.single.date, '2026-07-21');
    expect(find.byType(LineChart), findsOneWidget);
    expect(find.text('修改今日體重'), findsOneWidget);
  });
}
