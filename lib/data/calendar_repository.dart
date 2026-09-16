import '../models/calendar_day.dart';
import '../models/habit.dart';
import '../models/habit_stat.dart';
import '../utils/date_labels.dart';
import 'habit_history_store.dart' show dateOnly;
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

      final status = _statusFor(date, today, scheduled);
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
  CalendarDayStatus _statusFor(
    DateTime date,
    DateTime today,
    List<Habit> scheduled,
  ) {
    if (dateOnly(date) == today) return CalendarDayStatus.today;
    if (scheduled.isEmpty || _vacationLog.isFrozen(date)) {
      return CalendarDayStatus.done;
    }
    final claimedCount = scheduled.where((h) => h.isCompletedToday).length;
    if (claimedCount == 0) return CalendarDayStatus.missed;
    if (claimedCount == scheduled.length) return CalendarDayStatus.perfect;
    return CalendarDayStatus.done;
  }

  /// Consecutive days (walking back from today) with at least one claimed
  /// habit, skipping days nothing was scheduled — mirrors the "streaks
  /// aren't broken by off-schedule days" rule in FEATURES.md §5, applied
  /// across all habits together since this is a single aggregate number.
  /// Today itself only counts once every scheduled habit is claimed; until
  /// then it's "still in progress" rather than a break. Days Vacation Mode
  /// was active on are skipped the same way — frozen, not missed.
  Future<int> _currentStreak(DateTime today) async {
    var streak = 0;
    var day = today;
    while (today.difference(day).inDays <= 400) {
      final scheduled = _vacationLog.isFrozen(day)
          ? const <Habit>[]
          : await _habits.getHabitsForDate(day);
      if (scheduled.isNotEmpty) {
        final isToday = dateOnly(day) == today;
        final allClaimed = scheduled.every((h) => h.isCompletedToday);
        final anyClaimed = scheduled.any((h) => h.isCompletedToday);
        if (isToday) {
          if (!allClaimed) {
            day = day.subtract(const Duration(days: 1));
            continue;
          }
        } else if (!anyClaimed) {
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
