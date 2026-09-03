import 'package:flutter/material.dart';
import '../models/habit.dart';
import '../theme/app_colors.dart';

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
}

class MockHabitRepository implements HabitRepository {
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
}
