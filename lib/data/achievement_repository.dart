import 'package:flutter/material.dart';

import '../models/achievement.dart';
import '../models/pet.dart';
import '../theme/app_colors.dart';
import 'bucket_list_repository.dart';
import 'calendar_repository.dart';
import 'habit_history_store.dart' show dateOnly;
import 'habit_repository.dart';
import 'inventory_repository.dart';
import 'pet_repository.dart';

abstract class AchievementRepository {
  /// Achievements grouped by category, in display order.
  Future<Map<String, List<Achievement>>> getAchievementsByCategory();
}

class _HistoryStats {
  const _HistoryStats({
    required this.totalCompletions,
    required this.maxPerHabitCompletions,
    required this.reachedMinNotFull,
    required this.anyMissedDay,
  });
  final int totalCompletions;
  final int maxPerHabitCompletions;
  final bool reachedMinNotFull;
  final bool anyMissedDay;
}

class MockAchievementRepository implements AchievementRepository {
  MockAchievementRepository(
    this._habits,
    this._calendar,
    this._bucketList,
    this._pet,
    this._inventory,
  );
  final HabitRepository _habits;
  final CalendarRepository _calendar;
  final BucketListRepository _bucketList;
  final PetRepository _pet;
  final InventoryRepository _inventory;

  // Mirrors HabitHistoryStore.seedDayCount — the seeded history window.
  static const _historyWindowDays = 90;

  AchievementStatus _statusFor(int current, int target) {
    if (target <= 0) return AchievementStatus.locked;
    if (current >= target) return AchievementStatus.unlocked;
    if (current > 0) return AchievementStatus.inProgress;
    return AchievementStatus.locked;
  }

  Future<_HistoryStats> _computeHistoryStats() async {
    final today = dateOnly(DateTime.now());
    var totalCompletions = 0;
    final perHabitCompletions = <String, int>{};
    var reachedMinNotFull = false;
    var anyMissedDay = false;
    for (var back = 0; back < _historyWindowDays; back++) {
      final habitsForDay = await _habits.getHabitsForDate(
        today.subtract(Duration(days: back)),
      );
      if (habitsForDay.isEmpty) {
        continue;
      }
      if (!habitsForDay.any((h) => h.isCompletedToday)) anyMissedDay = true;
      for (final habit in habitsForDay) {
        if (habit.isCompletedToday) {
          totalCompletions++;
          perHabitCompletions[habit.id] =
              (perHabitCompletions[habit.id] ?? 0) + 1;
          final target = habit.targetValue;
          final min = habit.minThreshold;
          if (target != null &&
              min != null &&
              habit.currentValue >= min &&
              habit.currentValue < target) {
            reachedMinNotFull = true;
          }
        }
      }
    }
    final maxPerHabit = perHabitCompletions.values.isEmpty
        ? 0
        : perHabitCompletions.values.reduce((a, b) => a > b ? a : b);
    return _HistoryStats(
      totalCompletions: totalCompletions,
      maxPerHabitCompletions: maxPerHabit,
      reachedMinNotFull: reachedMinNotFull,
      anyMissedDay: anyMissedDay,
    );
  }

  Future<int> _perfectDayStreak(DateTime today) async {
    var streak = 0;
    var day = today;
    while (streak < 7 && today.difference(day).inDays <= _historyWindowDays) {
      final scheduled = await _habits.getHabitsForDate(day);
      if (scheduled.isNotEmpty) {
        final isToday = dateOnly(day) == today;
        final allClaimed = scheduled.every((h) => h.isCompletedToday);
        if (isToday) {
          if (!allClaimed) {
            day = day.subtract(const Duration(days: 1));
            continue;
          }
        } else if (!allClaimed) {
          break;
        }
        streak++;
      }
      day = day.subtract(const Duration(days: 1));
    }
    return streak;
  }

  Achievement _a(
    String id,
    String category,
    String title,
    String subtitle,
    IconData icon,
    Color color,
    num current,
    int target, {
    String? imageAsset,
  }) {
    final progressCurrent = current.toInt();
    return Achievement(
      id: id,
      category: category,
      title: title,
      subtitle: subtitle,
      icon: icon,
      color: color,
      progressCurrent: progressCurrent,
      progressTarget: target,
      status: _statusFor(progressCurrent, target),
      imageAsset: imageAsset,
    );
  }

  Achievement _soon(
    String id,
    String category,
    String title,
    String subtitle,
    IconData icon,
    Color color,
  ) => Achievement(
    id: id,
    category: category,
    title: title,
    subtitle: subtitle,
    icon: icon,
    color: color,
    progressCurrent: 0,
    progressTarget: 0,
    status: AchievementStatus.comingSoon,
  );

  @override
  Future<Map<String, List<Achievement>>> getAchievementsByCategory() async {
    final today = dateOnly(DateTime.now());
    final todayHabits = await _habits.getTodayHabits();
    final monthStats = await _calendar.getCurrentMonth();
    final streak = monthStats.currentStreak;
    final history = await _computeHistoryStats();
    final perfectStreak = await _perfectDayStreak(today);
    final bucketItems = (await _bucketList.getItems()).where(
      (item) => item.id != 'dev-level-up',
    );
    final goalGetterDone = bucketItems.any((item) => item.isCompleted);
    final pet = await _pet.getPet();
    final inventory = await _inventory.getInventory();
    final onTrackCurrent =
        todayHabits.isNotEmpty && todayHabits.every((h) => h.isCompletedToday)
        ? 1
        : 0;
    final consistencyStreak = streak < 0 ? 0 : streak;
    final habitArchitectCurrent = todayHabits.length.clamp(0, 3);
    final risingAgainCurrent = consistencyStreak >= 1 && history.anyMissedDay
        ? 1
        : 0;
    final notAllOrNothingCurrent = history.reachedMinNotFull ? 1 : 0;
    final goalGetterCurrent = goalGetterDone ? 1 : 0;
    final firstEvolutionCurrent = pet.stage != PetEvolutionStage.baby ? 1 : 0;
    final dapperDebutCurrent = inventory.ownedAccessoryIds.isNotEmpty ? 1 : 0;
    return {
      'Consistency': [
        _a(
          'on-track',
          'Consistency',
          'On Track',
          'Complete every habit in one day',
          Icons.check_circle,
          AppColors.moss,
          onTrackCurrent,
          1,
          imageAsset: 'assets/images/achievements/on_track.png',
        ),
        _a(
          'perfect-week',
          'Consistency',
          'Perfect Week',
          'Complete all scheduled habits for 7 days',
          Icons.event_available,
          AppColors.mossDark,
          perfectStreak,
          7,
          imageAsset: 'assets/images/achievements/perfect_week.png',
        ),
        _a(
          'consistency-i',
          'Consistency',
          'Consistency I',
          'Maintain a 3-day streak',
          Icons.local_fire_department,
          AppColors.moss,
          consistencyStreak.clamp(0, 3),
          3,
        ),
        _a(
          'consistency-ii',
          'Consistency',
          'Consistency II',
          'Maintain a 7-day streak',
          Icons.local_fire_department,
          AppColors.mossDark,
          consistencyStreak.clamp(0, 7),
          7,
        ),
        _a(
          'consistency-iii',
          'Consistency',
          'Consistency III',
          'Maintain a 30-day streak',
          Icons.local_fire_department,
          AppColors.inkFaint,
          consistencyStreak.clamp(0, 30),
          30,
        ),
        _a(
          'rising-again',
          'Consistency',
          'Rising Again',
          'Bounce back after a missed day',
          Icons.refresh,
          AppColors.terracotta,
          risingAgainCurrent,
          1,
        ),
      ],
      'Milestones': [
        _a(
          'getting-started',
          'Milestones',
          'Getting Started',
          '10 total habit completions',
          Icons.flag,
          AppColors.moss,
          history.totalCompletions.clamp(0, 10),
          10,
        ),
        _a(
          'dedicated-i',
          'Milestones',
          'Dedicated I',
          '50 total completions',
          Icons.military_tech,
          AppColors.moss,
          history.totalCompletions.clamp(0, 50),
          50,
        ),
        _a(
          'dedicated-ii',
          'Milestones',
          'Dedicated II',
          '100 total completions',
          Icons.military_tech,
          AppColors.mustardDark,
          history.totalCompletions.clamp(0, 100),
          100,
        ),
        _a(
          'dedicated-iii',
          'Milestones',
          'Dedicated III',
          '500 total completions',
          Icons.military_tech,
          AppColors.inkFaint,
          history.totalCompletions.clamp(0, 500),
          500,
        ),
        _a(
          'goal-getter',
          'Milestones',
          'Goal Getter',
          'Complete a bucket list item',
          Icons.flag_circle,
          AppColors.terracotta,
          goalGetterCurrent,
          1,
        ),
      ],
      'Habits': [
        _a(
          'first-step',
          'Habits',
          'First Step',
          'Complete your first habit',
          Icons.check,
          AppColors.moss,
          history.totalCompletions.clamp(0, 1),
          1,
          imageAsset: 'assets/images/achievements/first_step.png',
        ),
        _a(
          'habit-architect',
          'Habits',
          'Habit Architect',
          'Create 3 habits',
          Icons.construction,
          AppColors.mossDark,
          habitArchitectCurrent,
          3,
          imageAsset: 'assets/images/achievements/habit_architect.png',
        ),
        _a(
          'not-all-or-nothing',
          'Habits',
          'Not All-or-Nothing',
          'Hit the minimum when you miss the ideal target',
          Icons.trending_up,
          AppColors.terracotta,
          notAllOrNothingCurrent,
          1,
        ),
        _soon(
          'balanced-life',
          'Habits',
          'Balanced Life',
          'Complete habits from 3 different categories in a week',
          Icons.balance,
          AppColors.mustardDark,
        ),
        _a(
          'steady-progress-i',
          'Habits',
          'Steady Progress I',
          'Complete one habit 10 times',
          Icons.trending_up,
          AppColors.moss,
          history.maxPerHabitCompletions.clamp(0, 10),
          10,
        ),
        _a(
          'steady-progress-ii',
          'Habits',
          'Steady Progress II',
          'Complete one habit 25 times',
          Icons.trending_up,
          AppColors.mossDark,
          history.maxPerHabitCompletions.clamp(0, 25),
          25,
        ),
        _a(
          'steady-progress-iii',
          'Habits',
          'Steady Progress III',
          'Complete one habit 100 times',
          Icons.trending_up,
          AppColors.inkFaint,
          history.maxPerHabitCompletions.clamp(0, 100),
          100,
        ),
      ],
      'Pet Care': [
        _soon(
          'pets-best-friend',
          'Pet Care',
          "Pet's Best Friend",
          'Care for your pet 5 days in a row',
          Icons.favorite,
          AppColors.terracotta,
        ),
        _a(
          'first-evolution',
          'Pet Care',
          'First Evolution',
          'Evolve your pet for the first time',
          Icons.auto_awesome,
          AppColors.inkFaint,
          firstEvolutionCurrent,
          1,
        ),
        _soon(
          'growing-family',
          'Pet Care',
          'Growing Family',
          'Adopt a second pet',
          Icons.pets,
          AppColors.inkFaint,
        ),
        _a(
          'dapper-debut',
          'Pet Care',
          'Shopaholic',
          'Buy your first accessory',
          Icons.checkroom,
          AppColors.terracotta,
          dapperDebutCurrent,
          1,
        ),
      ],
      'Social': [
        _soon(
          'helping-hand',
          'Social',
          'Helping Hand',
          "React to a friend's progress",
          Icons.thumb_up,
          AppColors.moss,
        ),
        _soon(
          'accountability-duo',
          'Social',
          'Accountability Duo',
          'Complete a shared challenge with a friend',
          Icons.group,
          AppColors.inkFaint,
        ),
      ],
    };
  }
}
