import 'package:campus_lost_found/core/widgets/app_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('AppButton displays its label', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: AppButton(label: 'Test Button', onPressed: null)),
      ),
    );

    expect(find.text('Test Button'), findsOneWidget);
  });
}
