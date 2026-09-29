import '../models/calendar_day.dart';
import '../models/habit.dart';
import '../models/habit_day_state.dart';
import '../models/habit_stat.dart';
import '../utils/date_labels.dart';
import 'habit_history_store.dart' show dateOnly, dayKey;
import 'habit_repository.dart';
import 'vacation_log.dart';

abstract class CalendarRepository {
  /// Stats and day grid for [year]/[month] (1-indexed). Backs the month
  /// arrows on the calendar screen.
  Future<CalendarMonthStats> getMonth(int year, int month);

  /// Convenience for whatever month "today" falls in.
  Future<CalendarMonthStats> getCurrentMonth();

  /// Per-habit completion rate over the last [days] days (today inclusive) —
  /// a rolling window, not tied to the visible calendar month, so "your
  /// easiest / most-missed habit" stays meaningful on the 1st too. Only
  /// habits scheduled at least once in the window are included.
  Future<List<HabitStat>> getHabitStats({int days = 30});
}

/// Derives the calendar entirely from [HabitRepository.getHabitsForDate], so
/// a day's colour here and that day's habit list (via the same call) can
/// never disagree — there is no separate calendar dataset to drift.
class MockCalendarRepository implements CalendarRepository {
  MockCalendarRepository(this._habits, this._vacationLog);

  final HabitRepository _habits;
  final VacationLog _vacationLog;

  @override
  Future<CalendarMonthStats> getCurrentMonth() {
    final now = DateTime.now();
    return getMonth(now.year, now.month);
  }

  @override
  Future<CalendarMonthStats> getMonth(int year, int month) async {
    final today = dateOnly(DateTime.now());
    final daysInMonth = DateTime(year, month + 1, 0).day;
    // Monday-first grid padding, matching the Mon..Sun header.
    final leadingEmpty = (DateTime(year, month, 1).weekday - DateTime.monday) % 7;

    final statusByDay = <int, CalendarDayStatus>{};
    var perfectDays = 0;
    var missedDays = 0;
    var habitsDone = 0;

    for (var d = 1; d <= daysInMonth; d++) {
      final date = DateTime(year, month, d);
      if (date.isAfter(today)) {
        statusByDay[d] = CalendarDayStatus.future;
        continue;
      }
      final scheduled = await _habits.getHabitsForDate(date);
      habitsDone += scheduled.where((h) => h.isCompletedToday).length;

      final status = await _statusFor(date, today, scheduled);
      statusByDay[d] = status;
      if (status == CalendarDayStatus.perfect) perfectDays++;
      if (status == CalendarDayStatus.missed) missedDays++;
    }

    final days = <CalendarDay>[
      for (var i = 0; i < leadingEmpty; i++)
        const CalendarDay(day: null, status: CalendarDayStatus.empty),
      for (var d = 1; d <= daysInMonth; d++)
        CalendarDay(
          day: d,
          status: statusByDay[d]!,
          date: DateTime(year, month, d),
        ),
    ];

    return CalendarMonthStats(
      year: year,
      month: month,
      monthLabel: monthFull(month),
      currentStreak: await _currentStreak(today),
      perfectDays: perfectDays,
      habitsDone: habitsDone,
      missedDays: missedDays,
      days: days,
    );
  }

  /// Today always renders as [CalendarDayStatus.today] regardless of
  /// progress — it's still in flight. A day with nothing scheduled (every
  /// habit's schedule skips it) reads as [CalendarDayStatus.done] rather
  /// than missed, per FEATURES.md §5: an off-schedule day isn't a broken
  /// commitment. A day Vacation Mode was active on gets the same neutral
  /// treatment — per FEATURES.md §2, paused time shouldn't read as a miss.
  Future<CalendarDayStatus> _statusFor(
    DateTime date,
    DateTime today,
    List<Habit> scheduled,
  ) async {
    if (dateOnly(date) == today) return CalendarDayStatus.today;
    if (scheduled.isEmpty || await _vacationLog.isFrozen(date)) {
      return CalendarDayStatus.done;
    }
    // Reaching a minimum saves the day from "missed"; "perfect" still means
    // every habit was claimed.
    if (!scheduled.any((h) => h.keptStreak)) return CalendarDayStatus.missed;
    if (scheduled.every((h) => h.isCompletedToday)) {
      return CalendarDayStatus.perfect;
    }
    return CalendarDayStatus.done;
  }

  /// Consecutive days (walking back from today) with at least one habit that
  /// [Habit.keptStreak] (claimed, or logged up to its minimum), skipping days nothing was scheduled — mirrors the "streaks
  /// aren't broken by off-schedule days" rule in FEATURES.md §5, applied
  /// across all habits together since this is a single aggregate number.
  /// Today itself only counts once every scheduled habit is kept; until
  /// then it's "still in progress" rather than a break. Days Vacation Mode
  /// was active on are skipped the same way — frozen, not missed.
  Future<int> _currentStreak(DateTime today) async {
    var streak = 0;
    var day = today;
    while (today.difference(day).inDays <= 400) {
      final scheduled = await _vacationLog.isFrozen(day)
          ? const <Habit>[]
          : await _habits.getHabitsForDate(day);
      if (scheduled.isNotEmpty) {
        final isToday = dateOnly(day) == today;
        final allKept = scheduled.every((h) => h.keptStreak);
        final anyKept = scheduled.any((h) => h.keptStreak);
        if (isToday) {
          if (!allKept) {
            day = day.subtract(const Duration(days: 1));
            continue;
          }
        } else if (!anyKept) {
          break;
        }
        streak++;
      }
      day = day.subtract(const Duration(days: 1));
    }
    return streak;
  }

  @override
  Future<List<HabitStat>> getHabitStats({int days = 30}) async {
    final today = dateOnly(DateTime.now());
    final scheduled = <String, int>{};
    final completed = <String, int>{};
    final meta = <String, Habit>{};

    for (var back = 0; back < days; back++) {
      final date = today.subtract(Duration(days: back));
      final habits = await _habits.getHabitsForDate(date);
      for (final habit in habits) {
        scheduled[habit.id] = (scheduled[habit.id] ?? 0) + 1;
        meta[habit.id] = habit;
        if (habit.isCompletedToday) {
          completed[habit.id] = (completed[habit.id] ?? 0) + 1;
        }
      }
    }

    return [
      for (final id in scheduled.keys)
        HabitStat(
          habitId: id,
          name: meta[id]!.name,
          icon: meta[id]!.icon,
          color: meta[id]!.color,
          scheduledDays: scheduled[id]!,
          completedDays: completed[id] ?? 0,
        ),
    ];
  }
}

/// Real Firestore-backed [CalendarRepository]. Deliberately *not* a
/// line-for-line port of [MockCalendarRepository] — that class calls
/// [HabitRepository.getHabitsForDate] once per day (cheap when it's an
/// in-memory map lookup, ruinous as up to ~400 separate network round-trips
/// against Firestore for a streak walk). This fetches each visible date
/// range with one call to [FirestoreHabitRepository.logsInRange] and derives
/// every day's status/streak/stat in memory instead — see docs/BACKEND.md
/// "Why habitLogs is a flat collection" for why that single range query is
/// possible at all.
class FirestoreCalendarRepository implements CalendarRepository {
  FirestoreCalendarRepository(this._habits, this._vacationLog);

  /// The concrete type, not [HabitRepository] — [logsInRange] is a
  /// Firestore-specific batch-fetch optimization, deliberately not part of
  /// the cross-backend interface (see its doc comment in
  /// `habit_repository.dart`).
  final FirestoreHabitRepository _habits;
  final VacationLog _vacationLog;

  @override
  Future<CalendarMonthStats> getCurrentMonth() {
    final now = DateTime.now();
    return getMonth(now.year, now.month);
  }

  @override
  Future<CalendarMonthStats> getMonth(int year, int month) async {
    final today = dateOnly(DateTime.now());
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final leadingEmpty = (DateTime(year, month, 1).weekday - DateTime.monday) % 7;

    // Two queries total for the whole month — not one per day.
    final definitions = await _habits.getTodayHabits();
    final logs = await _habits.logsInRange(
      DateTime(year, month, 1),
      DateTime(year, month, daysInMonth),
    );

    final statusByDay = <int, CalendarDayStatus>{};
    var perfectDays = 0;
    var missedDays = 0;
    var habitsDone = 0;

    for (var d = 1; d <= daysInMonth; d++) {
      final date = DateTime(year, month, d);
      if (date.isAfter(today)) {
        statusByDay[d] = CalendarDayStatus.future;
        continue;
      }
      final scheduled = _scheduledFor(date, today, definitions, logs);
      habitsDone += scheduled.where((h) => h.isCompletedToday).length;

      final status = await _statusFor(date, today, scheduled);
      statusByDay[d] = status;
      if (status == CalendarDayStatus.perfect) perfectDays++;
      if (status == CalendarDayStatus.missed) missedDays++;
    }

    final days = <CalendarDay>[
      for (var i = 0; i < leadingEmpty; i++)
        const CalendarDay(day: null, status: CalendarDayStatus.empty),
      for (var d = 1; d <= daysInMonth; d++)
        CalendarDay(
          day: d,
          status: statusByDay[d]!,
          date: DateTime(year, month, d),
        ),
    ];

    return CalendarMonthStats(
      year: year,
      month: month,
      monthLabel: monthFull(month),
      currentStreak: await _currentStreak(today, definitions),
      perfectDays: perfectDays,
      habitsDone: habitsDone,
      missedDays: missedDays,
      days: days,
    );
  }

  /// A day's habits, hydrated with that day's logged state — mirrors
  /// [FirestoreHabitRepository.getHabitsForDate], but reads from an
  /// already-fetched [logs] map instead of querying Firestore again, since
  /// this gets called once per day in a loop ([getMonth], [_currentStreak],
  /// [getHabitStats]). Today is a special case: its state already lives on
  /// [definitions] themselves (see [FirestoreHabitRepository.getTodayHabits]),
  /// not in `habitLogs`, so there's nothing to look up.
  List<Habit> _scheduledFor(
    DateTime date,
    DateTime today,
    List<Habit> definitions,
    Map<String, HabitDayState> logs,
  ) {
    final day = dateOnly(date);
    final scheduled = [
      for (final definition in definitions)
        if (definition.isScheduledOn(day)) definition,
    ];
    if (day == today) return scheduled;
    final key = dayKey(day);
    return [
      for (final definition in scheduled)
        definition.hydrate(logs['${key}_${definition.id}'] ?? HabitDayState.empty),
    ];
  }

  /// Same status rules as [MockCalendarRepository._statusFor] — see that
  /// method's doc comment for the reasoning (today always "today", an
  /// off-schedule or vacation-frozen day reads as [CalendarDayStatus.done]
  /// rather than missed).
  Future<CalendarDayStatus> _statusFor(
    DateTime date,
    DateTime today,
    List<Habit> scheduled,
  ) async {
    if (dateOnly(date) == today) return CalendarDayStatus.today;
    if (scheduled.isEmpty || await _vacationLog.isFrozen(date)) {
      return CalendarDayStatus.done;
    }
    // Reaching a minimum saves the day from "missed"; "perfect" still means
    // every habit was claimed.
    if (!scheduled.any((h) => h.keptStreak)) return CalendarDayStatus.missed;
    if (scheduled.every((h) => h.isCompletedToday)) {
      return CalendarDayStatus.perfect;
    }
    return CalendarDayStatus.done;
  }

  /// Same walk-back logic as [MockCalendarRepository._currentStreak], but
  /// the up-to-400-day walk reads from one pre-fetched [logsInRange] result
  /// instead of issuing a Firestore query per day.
  Future<int> _currentStreak(DateTime today, List<Habit> definitions) async {
    const maxLookback = 400;
    final logs = await _habits.logsInRange(
      today.subtract(const Duration(days: maxLookback)),
      today,
    );

    var streak = 0;
    var day = today;
    while (today.difference(day).inDays <= maxLookback) {
      final scheduled = await _vacationLog.isFrozen(day)
          ? const <Habit>[]
          : _scheduledFor(day, today, definitions, logs);
      if (scheduled.isNotEmpty) {
        final isToday = dateOnly(day) == today;
        final allKept = scheduled.every((h) => h.keptStreak);
        final anyKept = scheduled.any((h) => h.keptStreak);
        if (isToday) {
          if (!allKept) {
            day = day.subtract(const Duration(days: 1));
            continue;
          }
        } else if (!anyKept) {
          break;
        }
        streak++;
      }
      day = day.subtract(const Duration(days: 1));
    }
    return streak;
  }

  @override
  Future<List<HabitStat>> getHabitStats({int days = 30}) async {
    final today = dateOnly(DateTime.now());
    final definitions = await _habits.getTodayHabits();
    final logs = await _habits.logsInRange(
      today.subtract(Duration(days: days - 1)),
      today,
    );

    final scheduled = <String, int>{};
    final completed = <String, int>{};
    final meta = <String, Habit>{};

    for (var back = 0; back < days; back++) {
      final date = today.subtract(Duration(days: back));
      final habitsOnDay = _scheduledFor(date, today, definitions, logs);
      for (final habit in habitsOnDay) {
        scheduled[habit.id] = (scheduled[habit.id] ?? 0) + 1;
        meta[habit.id] = habit;
        if (habit.isCompletedToday) {
          completed[habit.id] = (completed[habit.id] ?? 0) + 1;
        }
      }
    }

    return [
      for (final id in scheduled.keys)
        HabitStat(
          habitId: id,
          name: meta[id]!.name,
          icon: meta[id]!.icon,
          color: meta[id]!.color,
          scheduledDays: scheduled[id]!,
          completedDays: completed[id] ?? 0,
        ),
    ];
  }
}
