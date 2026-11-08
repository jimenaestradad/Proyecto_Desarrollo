import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nori/screens/customization/customization_screen.dart';

Future<void> _openWardrobe(WidgetTester tester) async {
  tester.view.physicalSize = const Size(412, 915);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CustomizationScreen()),
          ),
          child: const Text('open wardrobe'),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open wardrobe'));
  await tester.pumpAndSettle();
  expect(find.text('Wardrobe'), findsOneWidget);
}

void main() {
  testWidgets('leaving with an unsaved look asks first', (tester) async {
    await _openWardrobe(tester);

    // The mock account wears sunglasses; the "none" slot drops them in the
    // preview without saving.
    await tester.tap(find.byIcon(Icons.close).first);
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Discard changes?'), findsOneWidget);

    // Keep editing: stays on the Wardrobe.
    await tester.tap(find.text('Keep editing'));
    await tester.pumpAndSettle();
    expect(find.text('Discard changes?'), findsNothing);
    expect(find.text('Wardrobe'), findsOneWidget);

    // Discard: leaves.
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
    expect(find.text('Wardrobe'), findsNothing);
    expect(find.text('open wardrobe'), findsOneWidget);
  });

  testWidgets('leaving with nothing changed does not ask', (tester) async {
    await _openWardrobe(tester);

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();

    expect(find.text('Discard changes?'), findsNothing);
    expect(find.text('Wardrobe'), findsNothing);
  });
}
