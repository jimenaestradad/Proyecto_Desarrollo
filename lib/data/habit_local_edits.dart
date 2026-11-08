import '../models/habit.dart';
import 'habit_history_store.dart' show dayKey;
import 'habit_repository.dart' show clampProgress;

/// What the screen shows the instant a habit action is tapped, before the
/// server confirms it. Each mirrors what the repository will end up
/// storing, and the screen re-syncs from the server afterwards.
extension HabitLocalEdits on Habit {
  /// Whether reaching the target completes the habit by itself. Limit
  /// habits are a ceiling to stay under, so only the user ends their day.
  bool get completesAtTarget =>
      hasProgressTracking && !isInverted && targetValue != null;

  /// Whether [value] would reach the target of a [completesAtTarget] habit.
  bool reachesTarget(double value) =>
      completesAtTarget && clampProgress(this, value) >= targetValue!;

  Habit withProgress(double value) =>
      copyWith(currentValue: clampProgress(this, value));

  Habit withLogged(double amount) => withProgress(currentValue + amount);

  /// Complete: progress habits snap up to the target, like the server's
  /// claimValue. A day pays once, so a re-claim keeps what it paid.
  Habit claimedLocally() {
    final target = targetValue;
    final snapped = completesAtTarget && currentValue < target!
        ? copyWith(currentValue: target)
        : this;
    final claimed = snapped.copyWith(isCompletedToday: true);
    if (rewardPaid) return claimed;
    final reward = claimed.computeReward();
    return claimed.copyWith(
      lastAwardedXp: reward.xp,
      lastAwardedCoins: reward.coins,
    );
  }

  /// Undo: the payout stays, as on the server. [restoreValue] is the
  /// progress the habit had before Complete snapped it to the target.
  Habit unclaimedLocally({double? restoreValue}) => copyWith(
    isCompletedToday: false,
    currentValue: restoreValue ?? currentValue,
  );
}

/// The progress a habit had before Complete (or reaching the target) took it
/// to the target, so Undo can put it back: 1/3, Complete, Undo is 1/3 again.
/// Kept in memory only, so after an app restart Undo leaves the target value.
class PreClaimValues {
  PreClaimValues._();

  static final _values = <String, double>{};

  static String _key(String habitId, DateTime day) => '$habitId|${dayKey(day)}';

  static void remember(String habitId, DateTime day, double value) =>
      _values[_key(habitId, day)] = value;

  /// The remembered value, removed so a stale one can't resurface later.
  static double? take(String habitId, DateTime day) =>
      _values.remove(_key(habitId, day));

  static void forget(String habitId, DateTime day) =>
      _values.remove(_key(habitId, day));
}
