import 'package:flutter/material.dart';

import '../models/achievement.dart';
import '../models/habit.dart';
import '../models/pet.dart';
import '../theme/app_colors.dart';
import 'bucket_list_repository.dart';
import 'calendar_repository.dart';
import 'habit_history_store.dart' show addDays, dateOnly;
import 'habit_repository.dart';
import 'inventory_repository.dart';
import 'pet_repository.dart';
import 'social_repository.dart';

abstract class AchievementRepository {
  /// Achievements grouped by category, in display order.
  Future<Map<String, List<Achievement>>> getAchievementsByCategory();
}

class _HistoryStats {
  const _HistoryStats({
    required this.totalCompletions,
    required this.reachedMinNotFull,
    required this.anyMissedDay,
  });
  final int totalCompletions;
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
    this._social,
  );
  final HabitRepository _habits;
  final CalendarRepository _calendar;
  final BucketListRepository _bucketList;
  final PetRepository _pet;
  final InventoryRepository _inventory;

  /// Source of the Social achievements' progress (mock data today).
  final SocialRepository _social;

  // Mirrors HabitHistoryStore.seedDayCount — the seeded history window.
  static const _historyWindowDays = 90;

  AchievementStatus _statusFor(int current, int target) {
    if (target <= 0) return AchievementStatus.locked;
    if (current >= target) return AchievementStatus.unlocked;
    if (current > 0) return AchievementStatus.inProgress;
    return AchievementStatus.locked;
  }

  /// [byDay] is the one shared [_historyWindowDays]-back fetch; the
  /// completion/miss stats only look at the last [_historyWindowDays] days
  /// of it, same as before the fetch was shared with [_perfectDayStreak].
  _HistoryStats _computeHistoryStats(
    Map<DateTime, List<Habit>> byDay,
    DateTime today,
  ) {
    final windowStart = addDays(today, 1 - _historyWindowDays);
    var totalCompletions = 0;
    var reachedMinNotFull = false;
    var anyMissedDay = false;
    for (final entry in byDay.entries) {
      if (entry.key.isBefore(windowStart)) continue;
      final habitsForDay = entry.value;
      if (habitsForDay.isEmpty) {
        continue;
      }
      if (!habitsForDay.any((h) => h.keptStreak)) anyMissedDay = true;
      for (final habit in habitsForDay) {
        // Checked on unclaimed days too: a claim snaps to the full target,
        // so a between-min-and-target value only survives unclaimed.
        if (habit.isMinMet && !habit.isTargetMet) reachedMinNotFull = true;
        if (habit.isCompletedToday) {
          totalCompletions++;
        }
      }
    }
    return _HistoryStats(
      totalCompletions: totalCompletions,
      reachedMinNotFull: reachedMinNotFull,
      anyMissedDay: anyMissedDay,
    );
  }

  int _perfectDayStreak(Map<DateTime, List<Habit>> byDay, DateTime today) {
    var streak = 0;
    var day = today;
    while (streak < 7 && today.difference(day).inDays <= _historyWindowDays) {
      final scheduled = byDay[dateOnly(day)] ?? const [];
      if (scheduled.isNotEmpty) {
        final isToday = dateOnly(day) == today;
        final allClaimed = scheduled.every((h) => h.isCompletedToday);
        if (isToday) {
          if (!allClaimed) {
            day = addDays(day, -1);
            continue;
          }
        } else if (!allClaimed) {
          break;
        }
        streak++;
      }
      day = addDays(day, -1);
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
    Color color, {
    String? imageAsset,
  }) => Achievement(
    id: id,
    category: category,
    title: title,
    subtitle: subtitle,
    icon: icon,
    color: color,
    progressCurrent: 0,
    progressTarget: 0,
    status: AchievementStatus.comingSoon,
    imageAsset: imageAsset,
  );

  @override
  Future<Map<String, List<Achievement>>> getAchievementsByCategory() async {
    final today = dateOnly(DateTime.now());
    // Independent reads, so fired together: one after another these were
    // ~10 sequential Firestore round trips, which made the screen (and the
    // notification sync that calls this) slow to open.
    final (
      todayHabits,
      streak,
      byDay,
      bucketList,
      pet,
      inventory,
      social,
    ) = await (
      _habits.getTodayHabits(),
      _calendar.getCurrentStreak(),
      _habits.getHabitsForRange(addDays(today, -_historyWindowDays), today),
      _bucketList.getItems(),
      _pet.getPet(),
      _inventory.getInventory(),
      _social.getSocialActivity(),
    ).wait;
    final history = _computeHistoryStats(byDay, today);
    final perfectStreak = _perfectDayStreak(byDay, today);
    final goalGetterDone = bucketList
        .where((item) => item.id != 'dev-level-up')
        .any((item) => item.isCompleted);
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
          imageAsset: 'assets/images/achievements/consistency_i.png',
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
          imageAsset: 'assets/images/achievements/consistency_ii.png',
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
          imageAsset: 'assets/images/achievements/consistency_iii.png',
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
          imageAsset: 'assets/images/achievements/rising_again.png',
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
          imageAsset: 'assets/images/achievements/getting_started.png',
        ),
        _a(
          'dedicated-i',
          'Milestones',
          'Dedicated I',
          '25 total completions',
          Icons.military_tech,
          AppColors.moss,
          history.totalCompletions.clamp(0, 25),
          25,
          imageAsset: 'assets/images/achievements/dedicated_i.png',
        ),
        _a(
          'dedicated-ii',
          'Milestones',
          'Dedicated II',
          '50 total completions',
          Icons.military_tech,
          AppColors.mustardDark,
          history.totalCompletions.clamp(0, 50),
          50,
          imageAsset: 'assets/images/achievements/dedicated_ii.png',
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
          imageAsset: 'assets/images/achievements/goal_getter.png',
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
          imageAsset: 'assets/images/achievements/not_all_or_nothing.png',
        ),
        _soon(
          'balanced-life',
          'Habits',
          'Balanced Life',
          'Complete habits from 3 different categories in a week',
          Icons.balance,
          AppColors.mustardDark,
          imageAsset: 'assets/images/achievements/balanced_life.png',
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
          imageAsset: 'assets/images/achievements/pets_best_friend.png',
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
          imageAsset: 'assets/images/achievements/first_evolution.png',
        ),
        _soon(
          'growing-family',
          'Pet Care',
          'Growing Family',
          'Adopt a second pet',
          Icons.pets,
          AppColors.inkFaint,
          imageAsset: 'assets/images/achievements/growing_family.png',
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
          imageAsset: 'assets/images/achievements/dapper_debut.png',
        ),
      ],
      'Social': [
        _a(
          'better-together',
          'Social',
          'Better Together',
          'Add your first friend',
          Icons.person_add,
          AppColors.mossDark,
          social.friendCount,
          1,
          imageAsset: 'assets/images/achievements/better_together.png',
        ),
        _a(
          'helping-hand',
          'Social',
          'Helping Hand',
          "React to 5 friends' posts",
          Icons.thumb_up,
          AppColors.moss,
          social.reactionsGiven,
          5,
          imageAsset: 'assets/images/achievements/helping_hand.png',
        ),
        _a(
          'proof-pal',
          'Social',
          'Proof Pal',
          'Share 5 proof posts',
          Icons.verified,
          AppColors.skyBlue,
          social.proofPosts,
          5,
          imageAsset: 'assets/images/achievements/proof_pal.png',
        ),
        _a(
          'circle-starter',
          'Social',
          'Circle Starter',
          'Create your first circle',
          Icons.groups,
          AppColors.mustardDark,
          social.circlesCreated,
          1,
          imageAsset: 'assets/images/achievements/circle_starter.png',
        ),
        _a(
          'accountability-duo',
          'Social',
          'Accountability Duo',
          'Complete a shared challenge with a friend',
          Icons.group,
          AppColors.terracotta,
          social.challengesCompleted,
          1,
          imageAsset: 'assets/images/achievements/accountability_duo.png',
        ),
      ],
    };
  }
}
