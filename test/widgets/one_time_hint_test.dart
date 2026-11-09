import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nori/data/tips_store.dart';
import 'package:nori/widgets/one_time_hint.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _store = TipsStore('test');
const _message = 'Tap a number to edit it.';

Widget _host() => const MaterialApp(
  home: Scaffold(
    body: OneTimeHint(
      tip: Tip.habitsGestures,
      icon: Icons.touch_app,
      message: _message,
      store: _store,
    ),
  ),
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('shows on first visit, then never again once dismissed', (
    tester,
  ) async {
    await tester.pumpWidget(_host());
    await tester.pumpAndSettle();
    expect(find.text(_message), findsOneWidget);

    await tester.tap(find.byTooltip('Dismiss'));
    await tester.pumpAndSettle();
    expect(find.text(_message), findsNothing);

    // A fresh screen load (new widget tree) stays hidden.
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(_host());
    await tester.pumpAndSettle();
    expect(find.text(_message), findsNothing);
  });

  testWidgets('takes no space while hidden', (tester) async {
    await _store.dismissHint(Tip.habitsGestures);
    await tester.pumpWidget(_host());
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byType(OneTimeHint)), Size.zero);
  });

  testWidgets('comes back when tips are reset while the tab stays mounted', (
    tester,
  ) async {
    await _store.dismissHint(Tip.habitsGestures);
    await tester.pumpWidget(_host());
    await tester.pumpAndSettle();
    expect(find.text(_message), findsNothing);

    await _store.reset();
    await tester.pumpAndSettle();
    expect(find.text(_message), findsOneWidget);
  });
}
