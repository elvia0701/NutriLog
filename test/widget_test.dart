// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:health_app/pages/add_food_page.dart';

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
}
