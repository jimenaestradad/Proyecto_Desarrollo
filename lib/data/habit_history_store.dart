import 'dart:math';

import '../models/habit.dart';
import '../models/habit_day_state.dart';

/// Strips the time component so a [DateTime] can address a calendar day.
DateTime dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

/// Stable `yyyy-mm-dd` key for a date.
String dayKey(DateTime date) {
  final d = dateOnly(date);
  final month = d.month.toString().padLeft(2, '0');
  final day = d.day.toString().padLeft(2, '0');
  return '${d.year}-$month-$day';
}

/// Every habit's logged state, keyed by date then habit id.
///
/// Single source of truth for history: [MockHabitRepository] reads and writes
/// it, and [MockCalendarRepository] derives its day colours and month stats
/// from the same data — so a day the calendar paints "Perfect" and that day's
/// habit list can't contradict each other.
///
/// Backed by an in-memory map, which is the whole reason it is separate from
/// the repositories: a real backend replaces this class with queries against
/// a `habit_logs` table keyed by (habit id, date), and the repository code
/// above it barely changes.
class HabitHistoryStore {
  HabitHistoryStore({this.seedDayCount = 90});

  /// How far back seeded demo history reaches. Also bounds streak walks, so
  /// they can't run off the end of the mock data.
  final int seedDayCount;

  final Map<String, Map<String, HabitDayState>> _byDate = {};

  DateTime get earliestDate =>
      dateOnly(DateTime.now()).subtract(Duration(days: seedDayCount));

  HabitDayState stateFor(String habitId, DateTime date) =>
      _byDate[dayKey(date)]?[habitId] ?? HabitDayState.empty;

  void write(String habitId, DateTime date, HabitDayState state) {
    _byDate.putIfAbsent(dayKey(date), () => {})[habitId] = state;
  }

  /// Fills in plausible past days so the calendar and history views have
  /// something to show before a backend exists. Deliberately deterministic
  /// (see [_stableHash]) so the same demo data comes back on every launch
  /// instead of reshuffling under you mid-demo.
  ///
  /// Only past days are generated — today's state comes from the habit
  /// definitions themselves, so the app opens on exactly the state it always
  /// did.
  void seedHistory(List<Habit> habits) {
    final today = dateOnly(DateTime.now());
    for (var back = seedDayCount; back >= 1; back--) {
      final date = today.subtract(Duration(days: back));
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
