// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fl_chart/fl_chart.dart';

import 'package:nutrilog/database/database_helper.dart';
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
      loadFoods: () async => [],
      insertFood: (food) async {
        insertedFood = food;
        return 1;
      },
      insertMealRecord: (_) async => 1,
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
          loadFoods: () async =>
              updatedFood == null ? [original] : [updatedFood!],
          updateFood: (food) async {
            updatedFood = food;
            return 1;
          },
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
          loadFoods: () async => foods,
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

  testWidgets('Empty food database offers first food creation', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: FoodDatabasePage(
          mealType: 'lunch',
          date: '2026-07-20',
          loadFoods: () async => [],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('食物資料庫目前沒有食物'), findsOneWidget);
    expect(find.text('建立第一個食物'), findsOneWidget);
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
          loadFoods: () async => [
            Food(id: 1, name: 'Apple', calories: 95, protein: 0.5),
            Food(id: 2, name: '香蕉', calories: 90, protein: 1.1),
          ],
          getFoodReferenceCount: (foodId) async => 0,
          removeFood: (foodId) async {
            deletedFoodId = foodId;
            return FoodRemovalResult.deleted;
          },
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
          loadFoods: () async => [
            Food(id: 7, name: '茶葉蛋', calories: 70, protein: 6),
          ],
          getFoodReferenceCount: (foodId) async => 1,
          removeFood: (foodId) async => FoodRemovalResult.archived,
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
          loadFoods: () async => [
            Food(id: 9, name: '優格', calories: 100, protein: 8),
          ],
          getFoodReferenceCount: (foodId) async => 0,
          removeFood: (foodId) async {
            deleteCalls += 1;
            return FoodRemovalResult.deleted;
          },
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
      loadFoods: () async => [
        Food(id: 7, name: '茶葉蛋', calories: 70, protein: 6),
      ],
      insertFood: (food) async {
        insertedFoodCount += 1;
        return 99;
      },
      insertMealRecord: (mealRecord) async {
        insertedMealRecord = mealRecord;
        return 1;
      },
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
      loadFoods: () async => [
        Food(id: 1, name: '香蕉', calories: 90, protein: 1.1),
      ],
      insertFood: (food) async {
        insertedFoodCount += 1;
        insertedFood = food;
        return 42;
      },
      insertMealRecord: (mealRecord) async {
        insertedMealCount += 1;
        insertedMealRecord = mealRecord;
        return 8;
      },
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
            items: [item],
            onMealAdded: () async {},
            onDelete: (item) async {
              deletedRecordId = item.recordId;
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
          weightRepository: FakeWeightRepository(),
          todayOverride: DateTime(2026, 7, 20),
          mealItemsLoader: loader,
          goalLoader: (date) async => date == '2026-07-20'
              ? const NutritionGoal(
                  effectiveDate: '2026-07-20',
                  calorieTarget: 1600,
                  proteinTarget: 100,
                )
              : const NutritionGoal(
                  effectiveDate: '2026-07-01',
                  calorieTarget: 1400,
                  proteinTarget: 80,
                ),
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

  testWidgets('Past dates are locked, can unlock, and relock after switching', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: HomePage(
          weightRepository: FakeWeightRepository(),
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
          weightRepository: weightRepository,
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
          weightRepository: weightRepository,
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
          weightRepository: weightRepository,
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
    NutritionGoal? storedGoal;
    await tester.pumpWidget(
      MaterialApp(
        home: HomePage(
          weightRepository: FakeWeightRepository(),
          todayOverride: DateTime(2026, 7, 20),
          mealItemsLoader: (_, _) async => [],
          goalLoader: (_) async => storedGoal,
          goalSaver: (goal) async => storedGoal = goal,
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
    expect(storedGoal, isNull);

    await tester.enterText(find.byKey(const Key('calorieTargetField')), '1800');
    await tester.enterText(
      find.byKey(const Key('proteinTargetField')),
      '120.5',
    );
    await tester.tap(find.byKey(const Key('saveNutritionGoalButton')));
    await tester.pumpAndSettle();

    expect(storedGoal?.effectiveDate, '2026-07-20');
    expect(storedGoal?.calorieTarget, 1800);
    expect(storedGoal?.proteinTarget, 120.5);
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
        home: NutritionGoalPage(todayOverride: DateTime(2026, 7, 20)),
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
