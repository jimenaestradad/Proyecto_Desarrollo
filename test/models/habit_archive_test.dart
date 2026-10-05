import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nori/data/habit_history_store.dart';
import 'package:nori/data/habit_repository.dart';
import 'package:nori/models/habit.dart';
import 'package:nori/theme/app_colors.dart';

Habit _habit({List<ArchivedRange> ranges = const []}) => Habit(
  id: 'h',
  name: 'Read',
  subtitle: 'Mind',
  icon: Icons.water_drop,
  color: AppColors.sky,
  xpReward: 10,
  coinReward: 5,
  repeat: HabitRepeat.daily,
  type: HabitType.binary,
  archived: ranges.any((r) => r.end == null),
  archivedRanges: ranges,
);

void main() {
  test('an open archived range hides the habit from its start day on', () {
    final habit = _habit(ranges: const [ArchivedRange(start: '2026-09-30')]);
    expect(habit.isActiveOn(DateTime(2026, 9, 29)), isTrue);
    expect(habit.isActiveOn(DateTime(2026, 9, 30)), isFalse);
    expect(habit.isActiveOn(DateTime(2026, 12, 1)), isFalse);
  });

  test('a closed range is end-exclusive — the restore day is active', () {
    final habit = _habit(
      ranges: const [ArchivedRange(start: '2026-09-10', end: '2026-09-20')],
    );
    expect(habit.isActiveOn(DateTime(2026, 9, 9)), isTrue);
    expect(habit.isActiveOn(DateTime(2026, 9, 15)), isFalse);
    expect(habit.isActiveOn(DateTime(2026, 9, 20)), isTrue);
  });

  test('archive then restore round-trips through the range helpers', () {
    final today = dayKey(DateTime.now());
    final archived = archiveRangesAfterArchiving(const []);
    expect(archived.single.start, today);
    expect(archived.single.end, isNull);
    // Same-day restore leaves an empty stretch, which is dropped.
    expect(archiveRangesAfterRestoring(archived), isEmpty);

    final older = archiveRangesAfterRestoring(
      const [ArchivedRange(start: '2020-01-01')],
    );
    expect(older.single.start, '2020-01-01');
    expect(older.single.end, today);
  });

  test('archivedRanges survive toJson/fromJson', () {
    final habit = _habit(
      ranges: const [
        ArchivedRange(start: '2026-09-10', end: '2026-09-20'),
        ArchivedRange(start: '2026-09-30'),
      ],
    );
    final restored = Habit.fromJson(habit.id, habit.toJson());
    expect(restored.toJson(), equals(habit.toJson()));
    expect(restored.archived, isTrue);
  });
}
