import '../models/calendar_day.dart';
import '../models/habit.dart';
import '../models/habit_day_state.dart';
import '../models/habit_stat.dart';
import '../utils/date_labels.dart';
import 'habit_history_store.dart' show addDays, dateOnly;
import 'habit_repository.dart';
import 'vacation_log.dart';

abstract class CalendarRepository {
  /// Stats and day grid for [year]/[month] (1-indexed). Backs the month
  /// arrows on the calendar screen.
  Future<CalendarMonthStats> getMonth(int year, int month);

  /// Convenience for whatever month "today" falls in.
  Future<CalendarMonthStats> getCurrentMonth();

  /// Just [CalendarMonthStats.currentStreak], without building a month
  /// grid — for callers that only need the number (the user profile,
  /// achievements).
  Future<int> getCurrentStreak();

  /// Per-habit completion rate over the last [days] days (today inclusive) —
  /// a rolling window, not tied to the visible calendar month, so "your
  /// easiest / most-missed habit" stays meaningful on the 1st too. Only
  /// habits scheduled at least once in the window are included.
  Future<List<HabitStat>> getHabitStats({int days = 30});
}

/// How far back a streak walk looks, in days before today. A streak longer
/// than this stops counting (400 days is more than a year).
const kStreakMaxLookback = 400;

/// Today always renders as [CalendarDayStatus.today] regardless of progress —
/// it's still in flight. A day with nothing scheduled (every habit's schedule
/// skips it) reads as [CalendarDayStatus.done] rather than missed, per
/// FEATURES.md §5: an off-schedule day isn't a broken commitment. A
/// [frozen] day (Vacation Mode was active) gets the same neutral treatment —
/// per FEATURES.md §2, paused time shouldn't read as a miss. [scheduled] is
/// the day's hydrated habits. Shared by both calendar repositories, so the
/// mock and the real one can't colour a day differently.
CalendarDayStatus calendarDayStatus({
  required DateTime date,
  required DateTime today,
  required List<Habit> scheduled,
  required bool frozen,
}) {
  if (dateOnly(date) == today) return CalendarDayStatus.today;
  if (scheduled.isEmpty || frozen) return CalendarDayStatus.done;
  // Reaching a minimum saves the day from "missed"; "perfect" still means
  // every habit was claimed.
  if (!scheduled.any((h) => h.keptStreak)) return CalendarDayStatus.missed;
  if (scheduled.every((h) => h.isCompletedToday)) {
    return CalendarDayStatus.perfect;
  }
  return CalendarDayStatus.done;
}

/// What one day does to a streak being walked back from today.
enum StreakStep { skip, count, stop }

/// A streak is consecutive days (walking back from today) with at least one
/// habit that [Habit.keptStreak] (claimed, or logged up to its minimum),
/// skipping days nothing was scheduled — the "streaks aren't broken by
/// off-schedule days" rule in FEATURES.md §5, applied across all habits
/// together since this is a single aggregate number. Today itself only
/// counts once every scheduled habit is kept; until then it's "still in
/// progress" rather than a break. Pass an empty [scheduled] for a day
/// Vacation Mode was active on: frozen, not missed.
StreakStep streakStep(List<Habit> scheduled, {required bool isToday}) {
  if (scheduled.isEmpty) return StreakStep.skip;
  if (isToday) {
    return scheduled.every((h) => h.keptStreak)
        ? StreakStep.count
        : StreakStep.skip;
  }
  return scheduled.any((h) => h.keptStreak)
      ? StreakStep.count
      : StreakStep.stop;
}

/// The month grid and totals for [year]/[month]. [habitsFor] returns a past
/// or present day's scheduled, hydrated habits (how it gets them is the
/// caller's business: the mock asks per day, Firestore reads a prefetched
/// month); days after [today] are never asked for. [vacationLog] marks
/// frozen days and [currentStreak] is passed in because each repository
/// walks it its own way.
Future<CalendarMonthStats> buildMonthStats({
  required int year,
  required int month,
  required DateTime today,
  required Future<List<Habit>> Function(DateTime day) habitsFor,
  required VacationLog vacationLog,
  required int currentStreak,
}) async {
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
    final scheduled = await habitsFor(date);
    habitsDone += scheduled.where((h) => h.isCompletedToday).length;

    final status = calendarDayStatus(
      date: date,
      today: today,
      scheduled: scheduled,
      frozen: await vacationLog.isFrozen(date),
    );
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
    currentStreak: currentStreak,
    perfectDays: perfectDays,
    habitsDone: habitsDone,
    missedDays: missedDays,
    days: days,
  );
}

/// Per-habit completion over the last [days] days ending [today]: each
/// habit's scheduled and completed day counts. [habitsFor] is as in
/// [buildMonthStats]. Only habits scheduled at least once appear.
Future<List<HabitStat>> buildHabitStats({
  required int days,
  required DateTime today,
  required Future<List<Habit>> Function(DateTime day) habitsFor,
}) async {
  final scheduled = <String, int>{};
  final completed = <String, int>{};
  final meta = <String, Habit>{};

  for (var back = 0; back < days; back++) {
    for (final habit in await habitsFor(addDays(today, -back))) {
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
  Future<int> getCurrentStreak() => _currentStreak(dateOnly(DateTime.now()));

  @override
  Future<CalendarMonthStats> getMonth(int year, int month) async {
    final today = dateOnly(DateTime.now());
    return buildMonthStats(
      year: year,
      month: month,
      today: today,
      habitsFor: _habits.getHabitsForDate,
      vacationLog: _vacationLog,
      currentStreak: await _currentStreak(today),
    );
  }

  /// Walks back from [today] asking [HabitRepository.getHabitsForDate] for
  /// each day — see [streakStep] for the rules.
  Future<int> _currentStreak(DateTime today) async {
    var streak = 0;
    for (var back = 0; back <= kStreakMaxLookback; back++) {
      final day = addDays(today, -back);
      final scheduled = await _vacationLog.isFrozen(day)
          ? const <Habit>[]
          : await _habits.getHabitsForDate(day);
      switch (streakStep(scheduled, isToday: day == today)) {
        case StreakStep.skip:
          continue;
        case StreakStep.count:
          streak++;
        case StreakStep.stop:
          return streak;
      }
    }
    return streak;
  }

  @override
  Future<List<HabitStat>> getHabitStats({int days = 30}) => buildHabitStats(
    days: days,
    today: dateOnly(DateTime.now()),
    habitsFor: _habits.getHabitsForDate,
  );
}

/// Real Firestore-backed [CalendarRepository]. Deliberately *not* a
/// line-for-line port of [MockCalendarRepository] — that class calls
/// [HabitRepository.getHabitsForDate] once per day (cheap when it's an
/// in-memory map lookup, ruinous as up to ~400 separate network round-trips
/// against Firestore for a streak walk). This fetches each visible date
/// range with one call to [FirestoreHabitRepository.logsInRange] and derives
/// every day's status/streak/stat in memory instead — see docs/BACKEND.md
/// "Why habitLogs is a flat collection" for why that single range query is
/// possible at all. The rules themselves are the shared functions above.
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
  Future<int> getCurrentStreak() async => _currentStreak(
    dateOnly(DateTime.now()),
    await _habits.fetchAllDefinitions(),
  );

  @override
  Future<CalendarMonthStats> getMonth(int year, int month) async {
    final today = dateOnly(DateTime.now());

    // Two queries total for the whole month — not one per day.
    final definitions = await _habits.fetchAllDefinitions();
    final logs = await _habits.logsInRange(
      DateTime(year, month, 1),
      DateTime(year, month + 1, 0),
    );

    return buildMonthStats(
      year: year,
      month: month,
      today: today,
      habitsFor: (day) async => hydrateScheduled(day, definitions, logs),
      vacationLog: _vacationLog,
      currentStreak: await _currentStreak(today, definitions),
    );
  }

  /// The same walk as [MockCalendarRepository]'s, but reads [logsInRange] in
  /// [_streakChunkDays]-day chunks, fetching the next older chunk only when
  /// the walk actually reaches it. Fetching all 400 days up front cost every
  /// habit's whole year of logs on each call, even for a 3-day streak.
  static const _streakChunkDays = 45;

  Future<int> _currentStreak(DateTime today, List<Habit> definitions) async {
    final oldest = addDays(today, -kStreakMaxLookback);
    final logs = <String, HabitDayState>{};
    // Every day from here through today is already in [logs].
    var fetchedFrom = addDays(today, 1);

    var streak = 0;
    for (var day = today; !day.isBefore(oldest); day = addDays(day, -1)) {
      if (day.isBefore(fetchedFrom)) {
        final end = addDays(fetchedFrom, -1);
        var start = addDays(end, 1 - _streakChunkDays);
        if (start.isBefore(oldest)) start = oldest;
        logs.addAll(await _habits.logsInRange(start, end));
        fetchedFrom = start;
      }
      final scheduled = await _vacationLog.isFrozen(day)
          ? const <Habit>[]
          : hydrateScheduled(day, definitions, logs);
      switch (streakStep(scheduled, isToday: day == today)) {
        case StreakStep.skip:
          continue;
        case StreakStep.count:
          streak++;
        case StreakStep.stop:
          return streak;
      }
    }
    return streak;
  }

  @override
  Future<List<HabitStat>> getHabitStats({int days = 30}) async {
    final today = dateOnly(DateTime.now());
    final definitions = await _habits.fetchAllDefinitions();
    final logs = await _habits.logsInRange(addDays(today, 1 - days), today);
    return buildHabitStats(
      days: days,
      today: today,
      habitsFor: (day) async => hydrateScheduled(day, definitions, logs),
    );
  }
}
