import 'package:flutter_test/flutter_test.dart';
import 'package:nori/data/habit_repository.dart';
import 'package:nori/models/habit.dart';

void main() {
  test('Habit.toJson/fromJson round-trips every seeded habit', () async {
    final habits = await MockHabitRepository().getTodayHabits();
    expect(habits, isNotEmpty);

    for (final habit in habits) {
      final json = habit.toJson();
      final restored = Habit.fromJson(habit.id, json);
      expect(
        restored.toJson(),
        equals(json),
        reason: 'mismatch for ${habit.id}',
      );
    }
  });
}
