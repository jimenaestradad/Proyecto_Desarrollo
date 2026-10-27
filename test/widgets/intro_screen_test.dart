import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nori/data/tips_store.dart';
import 'package:nori/screens/onboarding/intro_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _store = TipsStore('test');

/// Opens [IntroScreen] on top of a plain home page, like NamePetScreen does.
Future<void> _open(WidgetTester tester) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const IntroScreen(store: _store),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('walks three cards, then closes', (tester) async {
    await _open(tester);
    expect(find.text('Build habits that stick'), findsOneWidget);
    expect(find.text('Skip'), findsOneWidget);

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Look after Nori'), findsOneWidget);

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Keep your streak going'), findsOneWidget);
    // Skip is hidden on the last card, and the button changes.
    expect(find.text('Next'), findsNothing);
    expect(find.text('Start tracking'), findsOneWidget);

    await tester.tap(find.text('Start tracking'));
    await tester.pumpAndSettle();
    expect(find.byType(IntroScreen), findsNothing);
  });

  testWidgets('swiping also moves between cards', (tester) async {
    await _open(tester);
    await tester.drag(find.byType(PageView), const Offset(-400, 0));
    await tester.pumpAndSettle();
    expect(find.text('Look after Nori'), findsOneWidget);
  });

  testWidgets('Skip closes it from the first card', (tester) async {
    await _open(tester);
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    expect(find.byType(IntroScreen), findsNothing);
  });

  testWidgets('counts as seen as soon as it opens', (tester) async {
    expect(await _store.hasSeenIntro(), isFalse);
    await _open(tester);
    expect(await _store.hasSeenIntro(), isTrue);
  });
}
