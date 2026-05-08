import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_dfd/main.dart';

void main() {
  testWidgets('Main shell shows bottom nav labels', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: MainScreen()),
    );

    expect(find.text('СТАТИСТИКА'), findsOneWidget);
    expect(find.text('ЗАМЕТКИ'), findsOneWidget);
  });
}
