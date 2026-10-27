import 'package:flutter_test/flutter_test.dart';
import 'package:nori/data/habit_repository.dart';
import 'package:nori/models/habit_day_state.dart';

import '../support/habits.dart';

// 2026-10-26 is a Monday, 2026-10-24 a Saturday.
final monday = DateTime(2026, 10, 26);
final saturday = DateTime(2026, 10, 24);

void main() {
  group('hydrateDay', () {
    test('applies the matching log and leaves the rest empty', () {
      final logs = {
        '2026-10-26_water': const HabitDayState(
          value: 500,
          claimed: true,
          awardedXp: 20,
          awardedCoins: 10,
        ),
        // Same habit, other day: must not leak into Monday.
        '2026-10-25_read': const HabitDayState(value: 9, claimed: true),
      };
      final result = hydrateDay(monday, [
        testHabit('water'),
        testHabit('read'),
      ], logs);

      expect(result.map((h) => h.id), ['water', 'read']);
      expect(result[0].currentValue, 500);
      expect(result[0].isCompletedToday, isTrue);
      expect(result[0].lastAwardedXp, 20);
      expect(result[0].lastAwardedCoins, 10);
      expect(result[1].currentValue, 0);
      expect(result[1].isCompletedToday, isFalse);
    });

    test('ignores the time of day on the date', () {
      final logs = {'2026-10-26_water': const HabitDayState(value: 3)};
      final result = hydrateDay(DateTime(2026, 10, 26, 23, 59), [
        testHabit('water'),
      ], logs);
      expect(result.single.currentValue, 3);
    });
  });

  group('hydrateScheduled', () {
    test('keeps only habits scheduled that day', () {
      final habits = [
        testHabit('daily'),
        testHabit('weekdays', repeat: 'weekdays'),
        testHabit('weekends', repeat: 'weekends'),
      ];
      expect(hydrateScheduled(monday, habits, {}).map((h) => h.id), [
        'daily',
        'weekdays',
      ]);
      expect(hydrateScheduled(saturday, habits, {}).map((h) => h.id), [
        'daily',
        'weekends',
      ]);
    });

    test('hides days before the habit existed', () {
      final habits = [testHabit('new', createdAt: DateTime(2026, 10, 25))];
      expect(hydrateScheduled(saturday, habits, {}), isEmpty);
      expect(hydrateScheduled(monday, habits, {}), hasLength(1));
    });

    test('an archived habit stays on the days before it was archived', () {
      final habits = [
        testHabit(
          'old',
          archivedRanges: [
            {'start': '2026-10-25'},
          ],
        ),
      ];
      expect(hydrateScheduled(saturday, habits, {}), hasLength(1));
      expect(hydrateScheduled(monday, habits, {}), isEmpty);
    });
  });

  group('clampProgress', () {
    test('never goes negative', () {
      expect(
        clampProgress(testHabit('a', type: 'quantity', target: 10), -3),
        0,
      );
    });

    test('is capped at the target', () {
      final quantity = testHabit('a', type: 'quantity', target: 10);
      expect(clampProgress(quantity, 4), 4);
      expect(clampProgress(quantity, 15), 10);
    });

    test('a limit habit may overshoot, up to twice its target', () {
      final limit = testHabit('a', type: 'limit', target: 10);
      expect(clampProgress(limit, 15), 15);
      expect(clampProgress(limit, 25), 20);
    });

    test('no target means no upper limit', () {
      final noTarget = testHabit('a', type: 'multipleCompletion');
      expect(clampProgress(noTarget, 1000), 1000);
      expect(clampProgress(noTarget, -1), 0);
    });
  });
}
