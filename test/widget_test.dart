// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:nutrilog/pages/add_food_page.dart';
import 'package:nutrilog/models/meal_item.dart';
import 'package:nutrilog/widgets/dashboard_summary.dart';
import 'package:nutrilog/widgets/meal_section.dart';

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
      await tester.tap(find.text('加入這一餐'));
      await tester.pump();

      expect(find.text('份數必須是大於 0 的數字'), findsOneWidget);
    });
  }

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
}
