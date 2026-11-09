import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nori/widgets/password_rules.dart';

void main() {
  testWidgets('ticks each rule as the password gains it', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: PasswordRules(controller: controller)),
      ),
    );

    int ticks() => find.byIcon(Icons.check_circle).evaluate().length;

    expect(ticks(), 0);
    controller.text = 'abc';
    await tester.pump();
    expect(ticks(), 1); // a letter
    controller.text = 'abc12';
    await tester.pump();
    expect(ticks(), 2); // letter + number, still short
    controller.text = 'abc12345';
    await tester.pump();
    expect(ticks(), 3);
  });
}
