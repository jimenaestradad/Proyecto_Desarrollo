import 'package:flutter/material.dart';
import '../models/habit.dart';
import '../models/habit_day_state.dart';
import '../theme/app_colors.dart';
import 'habit_history_store.dart';

/// What a completion/claim/un-claim action just paid out (or clawed back).
/// Screens apply this to [UserRepository.addXp]/[addCoins].
class HabitRewardResult {
  const HabitRewardResult(this.xpDelta, this.coinsDelta);

  static const none = HabitRewardResult(0, 0);

  final int xpDelta;
  final int coinsDelta;
}

abstract class HabitRepository {
  Future<List<Habit>> getTodayHabits();

  /// Binary habits only. Awards the full reward on `true`; on `false`
  /// (un-checking) returns the exact negative of what was last awarded so
  /// XP/coins reverse cleanly instead of being recomputed against
  /// since-changed state.
  Future<HabitRewardResult> setHabitCompleted(String habitId, bool completed);

  /// Quantity/Duration/Cumulative/MultipleCompletion/Limit quick-log. Never
  /// awards anything by itself — per docs/FEATURES.md §3, logging progress
  /// alone doesn't earn XP, only claiming a completed habit does.
  Future<void> logProgress(String habitId, double amount);

  /// The "Complete" / "Mark Day Safe" button for non-binary habits. No-op
  /// (returns [HabitRewardResult.none]) if already claimed today.
  Future<HabitRewardResult> claimHabit(String habitId);

  Future<void> addHabit(Habit habit);

  /// Replaces a habit's definition (name, target, schedule, etc.) in place.
  /// Today's progress/completion state travels with whatever [habit] the
  /// caller passes in — callers editing a habit should carry those fields
  /// forward themselves.
  Future<void> updateHabit(Habit habit);

  /// Reverses a non-binary claim, mirroring [setHabitCompleted]'s `false`
  /// branch, so today's progress can be edited again. No-op if not claimed.
  Future<HabitRewardResult> unclaimHabit(String habitId);

  /// Sets today's logged progress to an absolute value (vs. [logProgress]'s
  /// delta) — powers undo / manual correction / reset-to-0. No-op once
  /// claimed; callers should [unclaimHabit] first.
  Future<void> setProgress(String habitId, double value);

  /// Persists a manual drag-reorder of the day's habit list.
  Future<void> reorderHabits(List<String> orderedIds);

  /// Habits scheduled on [date] (per [Habit.isScheduledOn]), hydrated with
  /// that date's logged progress/claim state. For today this is exactly
  /// [getTodayHabits] (which — unlike this method — does not filter by
  /// schedule, so the two can differ in which habits appear even though
  /// they agree on today's own state).
  ///
  /// Dates older than the tracked history window come back with zero
  /// state; there is no "we don't know" distinct from "nothing was logged".
  Future<List<Habit>> getHabitsForDate(DateTime date);

  /// [setHabitCompleted] for an arbitrary past date. Binary habits only.
  Future<HabitRewardResult> setHabitCompletedForDate(
    String habitId,
    DateTime date,
    bool completed,
  );

  /// [logProgress] for an arbitrary past date.
  Future<void> logProgressForDate(String habitId, DateTime date, double amount);

  /// [claimHabit] for an arbitrary past date.
  Future<HabitRewardResult> claimHabitForDate(String habitId, DateTime date);

  /// [unclaimHabit] for an arbitrary past date.
  Future<HabitRewardResult> unclaimHabitForDate(String habitId, DateTime date);

  /// [setProgress] for an arbitrary past date.
  Future<void> setProgressForDate(String habitId, DateTime date, double value);
}

class MockHabitRepository implements HabitRepository {
  MockHabitRepository() {
    history.seedHistory(_habits);
  }

  /// Past-day state, shared with [MockCalendarRepository] so the calendar's
  /// day colours and this list can't disagree. Today's own state lives on
  /// [_habits] directly, as it always has — this only covers other days.
  final HabitHistoryStore history = HabitHistoryStore();

  bool _isToday(DateTime date) =>
      dateOnly(date) == dateOnly(DateTime.now());

  final List<Habit> _habits = [
    const Habit(
      id: 'drink-water',
      name: 'Drink Water',
      subtitle: 'Target: 1,000 ml',
      icon: Icons.water_drop,
      color: AppColors.sky,
      xpReward: 10,
      coinReward: 5,
      repeat: HabitRepeat.daily,
      type: HabitType.quantity,
      difficulty: HabitDifficulty.easy,
      targetValue: 1000,
      unit: 'ml',
      minThreshold: 500,
      currentValue: 750,
    ),
    const Habit(
      id: 'gym-session',
      name: 'Gym Session',
      subtitle: 'Upper Body · 45 mins',
      icon: Icons.fitness_center,
      color: AppColors.mossLight,
      xpReward: 30,
      coinReward: 15,
      repeat: HabitRepeat.custom,
      customDays: {1, 3, 5},
      type: HabitType.duration,
      difficulty: HabitDifficulty.hard,
      targetValue: 45,
      unit: 'mins',
      adaptiveMultiplier: 1.2,
    ),
    const Habit(
      id: 'read',
      name: 'Read 10 mins',
      subtitle: 'Atomic Habits',
      icon: Icons.menu_book,
      color: AppColors.blushPink,
      xpReward: 15,
      coinReward: 5,
      repeat: HabitRepeat.daily,
      type: HabitType.binary,
      difficulty: HabitDifficulty.easy,
    ),
    const Habit(
      id: 'study-react',
      name: 'Study React',
      subtitle: 'Hooks & Context',
      icon: Icons.code,
      color: AppColors.mustardLight,
      xpReward: 20,
      coinReward: 10,
      repeat: HabitRepeat.weekdays,
      type: HabitType.cumulative,
      difficulty: HabitDifficulty.medium,
      targetValue: 60,
      unit: 'mins',
      minThreshold: 30,
      currentValue: 45,
    ),
    const Habit(
      id: 'healthy-meals',
      name: 'Healthy Meals',
      subtitle: '3 healthy meals today',
      icon: Icons.restaurant,
      color: AppColors.blush,
      xpReward: 10,
      coinReward: 5,
      repeat: HabitRepeat.daily,
      type: HabitType.multipleCompletion,
      difficulty: HabitDifficulty.easy,
      targetValue: 3,
      unit: 'meals',
      currentValue: 1,
    ),
    const Habit(
      id: 'social-media',
      name: 'Social Media',
      subtitle: 'Keep under 2h today',
      icon: Icons.smartphone,
      color: AppColors.linenAlt,
      xpReward: 20,
      coinReward: 10,
      repeat: HabitRepeat.daily,
      type: HabitType.limit,
      difficulty: HabitDifficulty.medium,
      targetValue: 120,
      unit: 'min',
      currentValue: 45,
    ),
  ];

  @override
  Future<List<Habit>> getTodayHabits() async => List.unmodifiable(_habits);

  @override
  Future<HabitRewardResult> setHabitCompleted(
    String habitId,
    bool completed,
  ) async {
    final index = _habits.indexWhere((h) => h.id == habitId);
    if (index == -1) return HabitRewardResult.none;
    final habit = _habits[index];

    if (completed) {
      final reward = habit.computeReward();
      _habits[index] = habit.copyWith(
        isCompletedToday: true,
        lastAwardedXp: reward.xp,
        lastAwardedCoins: reward.coins,
      );
      return HabitRewardResult(reward.xp, reward.coins);
    }

    final reversedXp = -habit.lastAwardedXp;
    final reversedCoins = -habit.lastAwardedCoins;
    _habits[index] = habit.copyWith(
      isCompletedToday: false,
      lastAwardedXp: 0,
      lastAwardedCoins: 0,
    );
    return HabitRewardResult(reversedXp, reversedCoins);
  }

  @override
  Future<void> logProgress(String habitId, double amount) async {
    final index = _habits.indexWhere((h) => h.id == habitId);
    if (index == -1) return;
    final habit = _habits[index];
    if (habit.isCompletedToday) return;
    final target = habit.targetValue;
    final nextValue = target == null
        ? habit.currentValue + amount
        : (habit.currentValue + amount).clamp(0, habit.isInverted ? target * 2 : target);
    _habits[index] = habit.copyWith(currentValue: nextValue.toDouble());
  }

  @override
  Future<HabitRewardResult> claimHabit(String habitId) async {
    final index = _habits.indexWhere((h) => h.id == habitId);
    if (index == -1) return HabitRewardResult.none;
    final habit = _habits[index];
    if (habit.isCompletedToday) return HabitRewardResult.none;

    final reward = habit.computeReward();
    _habits[index] = habit.copyWith(
      isCompletedToday: true,
      lastAwardedXp: reward.xp,
      lastAwardedCoins: reward.coins,
    );
    return HabitRewardResult(reward.xp, reward.coins);
  }

  @override
  Future<void> addHabit(Habit habit) async {
    _habits.add(habit);
  }

  @override
  Future<void> updateHabit(Habit habit) async {
    final index = _habits.indexWhere((h) => h.id == habit.id);
    if (index == -1) return;
    _habits[index] = habit;
  }

  @override
  Future<HabitRewardResult> unclaimHabit(String habitId) async {
    final index = _habits.indexWhere((h) => h.id == habitId);
    if (index == -1) return HabitRewardResult.none;
    final habit = _habits[index];
    if (!habit.isCompletedToday) return HabitRewardResult.none;

    final reversedXp = -habit.lastAwardedXp;
    final reversedCoins = -habit.lastAwardedCoins;
    _habits[index] = habit.copyWith(
      isCompletedToday: false,
      lastAwardedXp: 0,
      lastAwardedCoins: 0,
    );
    return HabitRewardResult(reversedXp, reversedCoins);
  }

  @override
  Future<void> setProgress(String habitId, double value) async {
    final index = _habits.indexWhere((h) => h.id == habitId);
    if (index == -1) return;
    final habit = _habits[index];
    if (habit.isCompletedToday) return;
    final target = habit.targetValue;
    final clamped = target == null
        ? value.clamp(0.0, double.infinity)
        : value.clamp(0.0, habit.isInverted ? target * 2 : target);
    _habits[index] = habit.copyWith(currentValue: clamped);
  }

  @override
  Future<void> reorderHabits(List<String> orderedIds) async {
    final byId = {for (final h in _habits) h.id: h};
    final reordered = [
      for (final id in orderedIds)
        if (byId[id] != null) byId[id]!,
    ];
    for (final h in _habits) {
      if (!orderedIds.contains(h.id)) reordered.add(h);
    }
    _habits
      ..clear()
      ..addAll(reordered);
  }

  /// Applies a day's logged state onto a habit's definition, the same shape
  /// [getTodayHabits] hands widgets today — so `HabitProgressCard` etc. don't
  /// need to know they're looking at a past day.
  Habit _hydrate(Habit definition, HabitDayState state) => definition.copyWith(
    currentValue: state.value,
    isCompletedToday: state.claimed,
    lastAwardedXp: state.awardedXp,
    lastAwardedCoins: state.awardedCoins,
  );

  @override
  Future<List<Habit>> getHabitsForDate(DateTime date) async {
    if (_isToday(date)) return getTodayHabits();
    final day = dateOnly(date);
    return [
      for (final definition in _habits)
        if (definition.isScheduledOn(day))
          _hydrate(definition, history.stateFor(definition.id, day)),
    ];
  }

  @override
  Future<HabitRewardResult> setHabitCompletedForDate(
    String habitId,
    DateTime date,
    bool completed,
  ) async {
    if (_isToday(date)) return setHabitCompleted(habitId, completed);
    final index = _habits.indexWhere((h) => h.id == habitId);
    if (index == -1) return HabitRewardResult.none;
    final definition = _habits[index];
    final day = dateOnly(date);
    final previous = history.stateFor(habitId, day);

    if (completed) {
      if (previous.claimed) return HabitRewardResult.none;
      final reward = definition.copyWith(isCompletedToday: true).computeReward();
      history.write(
        habitId,
        day,
        previous.copyWith(
          claimed: true,
          awardedXp: reward.xp,
          awardedCoins: reward.coins,
        ),
      );
      return HabitRewardResult(reward.xp, reward.coins);
    }

    if (!previous.claimed) return HabitRewardResult.none;
    final reversedXp = -previous.awardedXp;
    final reversedCoins = -previous.awardedCoins;
    history.write(
      habitId,
      day,
      previous.copyWith(claimed: false, awardedXp: 0, awardedCoins: 0),
    );
    return HabitRewardResult(reversedXp, reversedCoins);
  }

  @override
  Future<void> logProgressForDate(
    String habitId,
    DateTime date,
    double amount,
  ) async {
    if (_isToday(date)) return logProgress(habitId, amount);
    final index = _habits.indexWhere((h) => h.id == habitId);
    if (index == -1) return;
    final definition = _habits[index];
    final day = dateOnly(date);
    final previous = history.stateFor(habitId, day);
    if (previous.claimed) return;
    final target = definition.targetValue;
    final nextValue = target == null
        ? previous.value + amount
        : (previous.value + amount).clamp(
            0,
            definition.isInverted ? target * 2 : target,
          );
    history.write(habitId, day, previous.copyWith(value: nextValue.toDouble()));
  }

  @override
  Future<HabitRewardResult> claimHabitForDate(
    String habitId,
    DateTime date,
  ) async {
    if (_isToday(date)) return claimHabit(habitId);
    final index = _habits.indexWhere((h) => h.id == habitId);
    if (index == -1) return HabitRewardResult.none;
    final definition = _habits[index];
    final day = dateOnly(date);
    final previous = history.stateFor(habitId, day);
    if (previous.claimed) return HabitRewardResult.none;

    final reward = definition
        .copyWith(currentValue: previous.value, isCompletedToday: true)
        .computeReward();
    history.write(
      habitId,
      day,
      previous.copyWith(
        claimed: true,
        awardedXp: reward.xp,
        awardedCoins: reward.coins,
      ),
    );
    return HabitRewardResult(reward.xp, reward.coins);
  }

  @override
  Future<HabitRewardResult> unclaimHabitForDate(
    String habitId,
    DateTime date,
  ) async {
    if (_isToday(date)) return unclaimHabit(habitId);
    final day = dateOnly(date);
    final previous = history.stateFor(habitId, day);
    if (!previous.claimed) return HabitRewardResult.none;
    final reversedXp = -previous.awardedXp;
    final reversedCoins = -previous.awardedCoins;
    history.write(
      habitId,
      day,
      previous.copyWith(claimed: false, awardedXp: 0, awardedCoins: 0),
    );
    return HabitRewardResult(reversedXp, reversedCoins);
  }

  @override
  Future<void> setProgressForDate(
    String habitId,
    DateTime date,
    double value,
  ) async {
    if (_isToday(date)) return setProgress(habitId, value);
    final index = _habits.indexWhere((h) => h.id == habitId);
    if (index == -1) return;
    final definition = _habits[index];
    final day = dateOnly(date);
    final previous = history.stateFor(habitId, day);
    if (previous.claimed) return;
    final target = definition.targetValue;
    final clamped = target == null
        ? value.clamp(0.0, double.infinity)
        : value.clamp(0.0, definition.isInverted ? target * 2 : target);
    history.write(habitId, day, previous.copyWith(value: clamped));
  }
}
