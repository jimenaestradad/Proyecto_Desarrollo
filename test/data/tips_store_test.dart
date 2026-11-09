import 'package:flutter_test/flutter_test.dart';
import 'package:nori/data/tips_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('nothing is seen or dismissed for a fresh account', () async {
    const store = TipsStore('a');
    expect(await store.hasSeenIntro(), isFalse);
    for (final tip in Tip.values) {
      expect(await store.isHintDismissed(tip), isFalse);
    }
  });

  test('marking the intro seen and dismissing a hint persists', () async {
    const store = TipsStore('a');
    await store.markIntroSeen();
    await store.dismissHint(Tip.habitsGestures);

    expect(await store.hasSeenIntro(), isTrue);
    expect(await store.isHintDismissed(Tip.habitsGestures), isTrue);
    // A different hint is unaffected.
    expect(await store.isHintDismissed(Tip.calendarDays), isFalse);
  });

  test('state is per account', () async {
    await const TipsStore('a').markIntroSeen();
    await const TipsStore('a').dismissHint(Tip.calendarDays);

    expect(await const TipsStore('b').hasSeenIntro(), isFalse);
    expect(
      await const TipsStore('b').isHintDismissed(Tip.calendarDays),
      isFalse,
    );
  });

  test(
    'reset forgets everything for that account only, and notifies',
    () async {
      const a = TipsStore('a');
      const b = TipsStore('b');
      await a.markIntroSeen();
      await a.dismissHint(Tip.habitsGestures);
      await b.markIntroSeen();

      final before = TipsStore.resets.value;
      await a.reset();

      expect(await a.hasSeenIntro(), isFalse);
      expect(await a.isHintDismissed(Tip.habitsGestures), isFalse);
      expect(await b.hasSeenIntro(), isTrue);
      expect(TipsStore.resets.value, before + 1);
    },
  );
}
