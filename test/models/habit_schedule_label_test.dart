import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nori/data/habit_repository.dart';
import 'package:nori/models/habit.dart';
import 'package:nori/theme/app_colors.dart';

Habit _habit(HabitRepeat repeat, {Set<int>? customDays}) => Habit(
  id: 'h',
  name: 'Meditate',
  subtitle: 'Mind',
  icon: Icons.self_improvement,
  color: AppColors.sky,
  xpReward: 10,
  coinReward: 5,
  repeat: repeat,
  customDays: customDays,
  type: HabitType.binary,
);

void main() {
  test('scheduleLabel names the repeat in words', () {
    expect(_habit(HabitRepeat.daily).scheduleLabel, 'Every day');
    expect(_habit(HabitRepeat.weekdays).scheduleLabel, 'Weekdays');
    expect(_habit(HabitRepeat.weekends).scheduleLabel, 'Weekends');
  });

  test('a custom schedule lists its days Monday-first, whatever the order', () {
    final habit = _habit(HabitRepeat.custom, customDays: {5, 1, 3});
    expect(habit.scheduleLabel, 'Mon · Wed · Fri');
  });

  test('a custom schedule with no days reads as every day', () {
    expect(_habit(HabitRepeat.custom).scheduleLabel, 'Every day');
  });

  test('the mock repo lists only habits due today for today', () async {
    final repo = MockHabitRepository();
    final today = DateTime.now();
    final due = await repo.getHabitsForDate(today);
    final active = await repo.getTodayHabits();
    expect(due.every((h) => h.isScheduledOn(today)), isTrue);
    // getTodayHabits stays the wider "every active habit" set.
    expect(active.length >= due.length, isTrue);
  });
}
