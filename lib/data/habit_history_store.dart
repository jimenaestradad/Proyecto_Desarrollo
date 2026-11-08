import 'dart:math';

import '../models/habit.dart';
import '../models/habit_day_state.dart';

/// Strips the time component so a [DateTime] can address a calendar day.
DateTime dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

/// The calendar day [days] after [date] (negative goes back), at midnight.
/// Use this instead of `add(Duration(days: n))` when stepping through days:
/// across a DST change a day is 23 or 25 hours long, so adding 24h either
/// skips a date or lands on the same one twice.
DateTime addDays(DateTime date, int days) =>
    DateTime(date.year, date.month, date.day + days);

/// Stable `yyyy-mm-dd` key for a date.
String dayKey(DateTime date) {
  final d = dateOnly(date);
  final month = d.month.toString().padLeft(2, '0');
  final day = d.day.toString().padLeft(2, '0');
  return '${d.year}-$month-$day';
}

/// In-memory habit state keyed by date and habit id.
/// Shared by mock habit and calendar repositories so history and day colors agree.
class HabitHistoryStore {
  HabitHistoryStore({this.seedDayCount = 90});

  /// How far back seeded demo history reaches. Also bounds streak walks, so
  /// they can't run off the end of the mock data.
  final int seedDayCount;

  final Map<String, Map<String, HabitDayState>> _byDate = {};

  DateTime get earliestDate => addDays(dateOnly(DateTime.now()), -seedDayCount);

  HabitDayState stateFor(String habitId, DateTime date) =>
      _byDate[dayKey(date)]?[habitId] ?? HabitDayState.empty;

  void write(String habitId, DateTime date, HabitDayState state) {
    _byDate.putIfAbsent(dayKey(date), () => {})[habitId] = state;
  }

  /// Seeds deterministic past-day demo history using [_stableHash].
  /// Today's state remains defined by the habits themselves.
  void seedHistory(List<Habit> habits) {
    final today = dateOnly(DateTime.now());
    for (var back = seedDayCount; back >= 1; back--) {
      final date = addDays(today, -back);
      for (final habit in habits) {
        if (!habit.isScheduledOn(date)) continue;
        final state = _seedState(habit, date);
        if (state != null) write(habit.id, date, state);
      }
    }
  }

  HabitDayState? _seedState(Habit habit, DateTime date) {
    final random = Random(_stableHash('${habit.id}#${dayKey(date)}'));
    final roll = random.nextDouble();

    if (habit.type == HabitType.binary) {
      if (roll >= 0.72) return null;
      return _claimed(habit, 0, completed: true);
    }

    final target = habit.targetValue ?? 0;

    if (habit.isInverted) {
      // Limit habits succeed by staying under the ceiling.
      if (roll < 0.7) {
        return _claimed(habit, target * (0.2 + random.nextDouble() * 0.5));
      }
      // Over the ceiling: logged, but nothing to claim.
      return HabitDayState(value: target * (1.05 + random.nextDouble() * 0.4));
    }

    if (roll < 0.62) return _claimed(habit, target);

    final min = habit.minThreshold;
    if (roll < 0.78 && min != null) {
      return _claimed(habit, min + random.nextDouble() * (target - min) * 0.6);
    }
    if (roll < 0.9) {
      final ceiling = min ?? target;
      return HabitDayState(value: random.nextDouble() * ceiling * 0.8);
    }
    return null;
  }

  /// Builds a claimed state, computing the payout through [Habit.computeReward]
  /// so seeded history obeys the same reward rules as a live claim.
  HabitDayState _claimed(Habit habit, double value, {bool completed = false}) {
    final snapshot = habit.copyWith(
      currentValue: value,
      isCompletedToday: completed,
    );
    final reward = snapshot.computeReward();
    return HabitDayState(
      value: value,
      claimed: true,
      awardedXp: reward.xp,
      awardedCoins: reward.coins,
    );
  }
}

/// FNV-1a. Dart's `String.hashCode` is randomised per process, which would
/// reshuffle the seeded demo history on every launch.
int _stableHash(String value) {
  var hash = 0x811c9dc5;
  for (final unit in value.codeUnits) {
    hash ^= unit;
    hash = (hash * 0x01000193) & 0x7fffffff;
  }
  return hash;
}
