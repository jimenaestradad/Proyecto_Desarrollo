import 'package:flutter/material.dart';

/// One habit's completion rate over a rolling window — see
/// [CalendarRepository.getHabitStats]. A separate concept from
/// [CalendarMonthStats]: that one is scoped to the visible calendar month
/// (so it reads misleadingly thin on the 1st), this is a fixed trailing
/// window so "your easiest / most-missed habit" stays meaningful all month.
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
