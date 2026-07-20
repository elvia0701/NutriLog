// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:nutrilog/database/database_helper.dart';
import 'package:nutrilog/models/food.dart';
import 'package:nutrilog/pages/add_food_page.dart';
import 'package:nutrilog/models/meal_item.dart';
import 'package:nutrilog/models/meal_record.dart';
import 'package:nutrilog/pages/food_database_page.dart';
import 'package:nutrilog/pages/home_page.dart';
import 'package:nutrilog/widgets/dashboard_summary.dart';
import 'package:nutrilog/widgets/meal_section.dart';

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

void main() {
  testWidgets('Add food page renders its input fields', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: AddFoodPage()));

    expect(find.text('建立新食物'), findsOneWidget);
    expect(find.text('食物名稱'), findsOneWidget);
    expect(find.text('熱量 kcal'), findsOneWidget);
    expect(find.text('蛋白質 g'), findsOneWidget);
    expect(find.text('建立食物'), findsOneWidget);
  });

  testWidgets('Dashboard summary displays daily totals', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: DashboardSummary(totalCalories: 450, totalProtein: 32.5),
        ),
      ),
    );

    expect(find.text('🔥 450 / 1600 kcal'), findsOneWidget);
    expect(find.text('🥩 32.5 / 100 g'), findsOneWidget);
  });

  testWidgets('Meal servings default to one', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: AddFoodPage(mealType: 'breakfast')),
    );

    final servingsField = tester.widget<TextField>(
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
    expect(find.text('2 份 • 140 kcal • 12 g'), findsOneWidget);
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
          todayOverride: DateTime(2026, 7, 20),
          mealItemsLoader: loader,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('今天'), findsOneWidget);
    expect(find.text('2026年7月20日'), findsOneWidget);
    expect(find.text('🔥 100 / 1600 kcal'), findsOneWidget);
    expect(find.text('🥩 10 / 100 g'), findsOneWidget);
    final nextButton = tester.widget<IconButton>(
      find.byKey(const Key('nextDayButton')),
    );
    expect(nextButton.onPressed, isNull);

    await tester.tap(find.byKey(const Key('previousDayButton')));
    await tester.pumpAndSettle();

    expect(find.text('2026年7月19日 星期日'), findsOneWidget);
    expect(find.text('昨日早餐'), findsOneWidget);
    expect(find.text('🔥 120 / 1600 kcal'), findsOneWidget);
    expect(find.text('🥩 8 / 100 g'), findsOneWidget);
    expect(find.text('今天午餐'), findsNothing);
    expect(find.text('此日已封存'), findsOneWidget);
    expect(find.text('新增餐點'), findsNothing);
    expect(find.byTooltip('刪除餐點'), findsNothing);
  });

  testWidgets('Past dates are locked, can unlock, and relock after switching', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: HomePage(
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

    expect(find.text('此日已解鎖，可修正餐點'), findsOneWidget);
    expect(find.text('新增餐點'), findsWidgets);

    await tester.tap(find.byKey(const Key('nextDayButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('previousDayButton')));
    await tester.pumpAndSettle();

    expect(find.text('此日已封存'), findsOneWidget);
    expect(find.text('新增餐點'), findsNothing);
  });
}
