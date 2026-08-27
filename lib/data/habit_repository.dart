import 'package:flutter/material.dart';
import '../models/habit.dart';
import '../theme/app_colors.dart';

abstract class HabitRepository {
  Future<List<Habit>> getTodayHabits();
  Future<void> setHabitCompleted(String habitId, bool completed);
  Future<void> addHabit(Habit habit);
}

class MockHabitRepository implements HabitRepository {
  final List<Habit> _habits = [
    const Habit(
      id: 'drink-water',
      name: 'Drink Water',
      subtitle: '2 Liters daily',
      icon: Icons.water_drop,
      color: AppColors.primary,
      xpReward: 10,
      repeat: HabitRepeat.daily,
      isCompletedToday: true,
    ),
    const Habit(
      id: 'gym-session',
      name: 'Gym Session',
      subtitle: 'Upper Body - 45 mins',
      icon: Icons.fitness_center,
      color: AppColors.error,
      xpReward: 50,
      repeat: HabitRepeat.custom,
    ),
    const Habit(
      id: 'read',
      name: 'Read 10 mins',
      subtitle: 'Atomic Habits',
      icon: Icons.menu_book,
      color: AppColors.tertiary,
      xpReward: 15,
      repeat: HabitRepeat.daily,
    ),
    const Habit(
      id: 'study-react',
      name: 'Study React',
      subtitle: 'Hooks & Context',
      icon: Icons.code,
      color: AppColors.secondary,
      xpReward: 30,
      repeat: HabitRepeat.weekdays,
    ),
  ];

  @override
  Future<List<Habit>> getTodayHabits() async => List.unmodifiable(_habits);

  @override
  Future<void> setHabitCompleted(String habitId, bool completed) async {
    final index = _habits.indexWhere((h) => h.id == habitId);
    if (index == -1) return;
    _habits[index] = _habits[index].copyWith(isCompletedToday: completed);
  }

  @override
  Future<void> addHabit(Habit habit) async {
    _habits.add(habit);
  }
}
