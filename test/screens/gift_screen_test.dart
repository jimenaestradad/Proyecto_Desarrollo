import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nori/screens/pet/gift_screen.dart';

void main() {
  testWidgets('the first-habit gift names the accessory and the pet', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showGiftCelebration(
              context,
              accessoryId: 'sunglasses',
              petName: 'Mochi',
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('A gift for Mochi!'), findsOneWidget);
    expect(find.textContaining('Sunglasses'), findsOneWidget);
  });

  testWidgets('an accessory missing from the catalog shows nothing', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showGiftCelebration(
              context,
              accessoryId: 'gone',
              petName: 'Mochi',
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(GiftScreen), findsNothing);
  });

  for (final (label, expected) in [('Try it on', true), ('Not now', false)]) {
    testWidgets('"$label" completes the pop-up with $expected', (tester) async {
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      bool? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () async => result = await showGiftCelebration(
                context,
                accessoryId: 'sunglasses',
                petName: 'Mochi',
              ),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.text(label));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(result, expected);
    });
  }
}
