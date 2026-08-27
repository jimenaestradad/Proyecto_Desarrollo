import 'package:flutter/material.dart';

enum HabitRepeat { daily, weekdays, weekends, custom }

extension HabitRepeatLabel on HabitRepeat {
  String get label => switch (this) {
    HabitRepeat.daily => 'Daily',
    HabitRepeat.weekdays => 'Weekdays',
    HabitRepeat.weekends => 'Weekends',
    HabitRepeat.custom => 'Custom',
  };
}

class Habit {
  const Habit({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.xpReward,
    required this.repeat,
    this.isCompletedToday = false,
  });

  final String id;
  final String name;
  final String subtitle;
  final IconData icon;
  final Color color;
  final int xpReward;
  final HabitRepeat repeat;
  final bool isCompletedToday;

  Habit copyWith({bool? isCompletedToday}) {
    return Habit(
      id: id,
      name: name,
      subtitle: subtitle,
      icon: icon,
      color: color,
      xpReward: xpReward,
      repeat: repeat,
      isCompletedToday: isCompletedToday ?? this.isCompletedToday,
    );
  }
}
