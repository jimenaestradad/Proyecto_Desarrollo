import 'package:flutter/material.dart';

/// Habit completion rate over a fixed trailing window; see `getHabitStats`.
/// Unlike calendar-month totals, this stays meaningful at the start of a month.
class HabitStat {
  const HabitStat({
    required this.habitId,
    required this.name,
    required this.icon,
    required this.color,
    required this.scheduledDays,
    required this.completedDays,
  });

  final String habitId;
  final String name;
  final IconData icon;
  final Color color;

  /// Days in the window this habit was actually scheduled on (per
  /// [Habit.isScheduledOn]) — a Mon/Wed/Fri habit isn't penalized for the
  /// other four days.
  final int scheduledDays;
  final int completedDays;

  double get completionRate =>
      scheduledDays == 0 ? 0 : completedDays / scheduledDays;
}
