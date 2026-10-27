import 'package:flutter_test/flutter_test.dart';
import 'package:nori/data/calendar_repository.dart';
import 'package:nori/data/habit_repository.dart';
import 'package:nori/data/vacation_log.dart';
import 'package:nori/models/calendar_day.dart';
import 'package:nori/models/habit.dart';
import 'package:nori/models/habit_day_state.dart';

import '../support/habits.dart';

final today = DateTime(2026, 10, 15);
final past = DateTime(2026, 10, 10);

Habit open(String id) => testHabit(id);
Habit keptByMinimum(String id) => testHabit(
  id,
  type: 'quantity',
  target: 10,
  minThreshold: 4,
).hydrate(const HabitDayState(value: 5));

void main() {
  group('calendarDayStatus', () {
    CalendarDayStatus status(
      List<Habit> scheduled, {
      DateTime? date,
      bool frozen = false,
    }) => calendarDayStatus(
      date: date ?? past,
      today: today,
      scheduled: scheduled,
      frozen: frozen,
    );

    test('today is always today, whatever the progress', () {
      expect(status([open('a')], date: today), CalendarDayStatus.today);
    });

    test('nothing scheduled, or a vacation day, is neutral not missed', () {
      expect(status([]), CalendarDayStatus.done);
      expect(status([open('a')], frozen: true), CalendarDayStatus.done);
    });

    test('nothing kept is missed; everything claimed is perfect', () {
      expect(status([open('a')]), CalendarDayStatus.missed);
      expect(
        status([claimedHabit('a'), claimedHabit('b')]),
        CalendarDayStatus.perfect,
      );
    });

    test('some kept, or kept by the minimum, is done but not perfect', () {
      expect(status([claimedHabit('a'), open('b')]), CalendarDayStatus.done);
      expect(status([keptByMinimum('a')]), CalendarDayStatus.done);
    });
  });

  group('streakStep', () {
    test('a day with nothing scheduled (or frozen) is skipped', () {
      expect(streakStep([], isToday: false), StreakStep.skip);
      expect(streakStep([], isToday: true), StreakStep.skip);
    });

    test('a past day counts when any habit was kept, stops otherwise', () {
      expect(
        streakStep([claimedHabit('a'), open('b')], isToday: false),
        StreakStep.count,
      );
      expect(streakStep([open('a')], isToday: false), StreakStep.stop);
    });

    test('today counts only once every habit is kept, never breaks', () {
      expect(
        streakStep([claimedHabit('a'), claimedHabit('b')], isToday: true),
        StreakStep.count,
      );
      expect(
        streakStep([claimedHabit('a'), open('b')], isToday: true),
        StreakStep.skip,
      );
      expect(streakStep([open('a')], isToday: true), StreakStep.skip);
    });
  });

  group('buildMonthStats', () {
    // October 2026 starts on a Thursday; "today" is the 15th. Even days are
    // fully claimed, odd days missed.
    Future<List<Habit>> habitsFor(DateTime day) async => [
      day.day.isEven ? claimedHabit('a') : open('a'),
    ];

    test('counts statuses, totals and pads the grid to Monday', () async {
      final stats = await buildMonthStats(
        year: 2026,
        month: 10,
        today: today,
        habitsFor: habitsFor,
        vacationLog: MockVacationLog(),
        currentStreak: 3,
      );

      expect(stats.currentStreak, 3);
      expect(stats.monthLabel, 'October');
      // Thursday start: Mon, Tue, Wed are padding.
      expect(stats.days.length, 3 + 31);
      expect(stats.days.take(3).map((d) => d.status), [
        CalendarDayStatus.empty,
        CalendarDayStatus.empty,
        CalendarDayStatus.empty,
      ]);
      CalendarDayStatus of(int day) =>
          stats.days.firstWhere((d) => d.day == day).status;
      expect(of(15), CalendarDayStatus.today);
      expect(of(16), CalendarDayStatus.future);
      expect(of(31), CalendarDayStatus.future);
      expect(of(14), CalendarDayStatus.perfect);
      expect(of(13), CalendarDayStatus.missed);
      // Days 1-14: seven even (claimed) and seven odd (missed); today's
      // unclaimed habit isn't counted as done.
      expect(stats.perfectDays, 7);
      expect(stats.missedDays, 7);
      expect(stats.habitsDone, 7);
    });

    test('a vacation day is neutral instead of missed', () async {
      final vacation = MockVacationLog();
      await vacation.startFreeze(DateTime(2026, 10, 13));
      await vacation.endFreeze(DateTime(2026, 10, 13));
      final stats = await buildMonthStats(
        year: 2026,
        month: 10,
        today: today,
        habitsFor: habitsFor,
        vacationLog: vacation,
        currentStreak: 0,
      );
      expect(
        stats.days.firstWhere((d) => d.day == 13).status,
        CalendarDayStatus.done,
      );
      expect(stats.missedDays, 6);
    });

    test('never asks for a day after today', () async {
      final asked = <DateTime>[];
      await buildMonthStats(
        year: 2026,
        month: 10,
        today: today,
        habitsFor: (day) async {
          asked.add(day);
          return [];
        },
        vacationLog: MockVacationLog(),
        currentStreak: 0,
      );
      expect(asked.length, 15);
      expect(asked.every((d) => !d.isAfter(today)), isTrue);
    });
  });

  test(
    'buildHabitStats counts scheduled and completed days per habit',
    () async {
      // "a" is scheduled every day and claimed on even days; "b" only on the
      // last two days of the window.
      final stats = await buildHabitStats(
        days: 4,
        today: DateTime(2026, 10, 15),
        habitsFor: (day) async => [
          day.day.isEven ? claimedHabit('a') : open('a'),
          if (day.day >= 14) claimedHabit('b'),
        ],
      );
      final a = stats.firstWhere((s) => s.habitId == 'a');
      final b = stats.firstWhere((s) => s.habitId == 'b');
      expect(a.scheduledDays, 4);
      expect(a.completedDays, 2); // the 12th and 14th
      expect(b.scheduledDays, 2);
      expect(b.completedDays, 2);
      expect(b.completionRate, 1);
    },
  );

  test('the mock calendar agrees with itself on the seeded history', () async {
    final calendar = MockCalendarRepository(
      MockHabitRepository(),
      MockVacationLog(),
    );
    final month = await calendar.getCurrentMonth();
    expect(await calendar.getCurrentStreak(), month.currentStreak);
    expect(month.currentStreak, greaterThanOrEqualTo(0));
    expect(
      month.days.where((d) => d.status == CalendarDayStatus.today),
      hasLength(1),
    );

    final stats = await calendar.getHabitStats(days: 30);
    expect(stats, isNotEmpty);
    for (final stat in stats) {
      expect(stat.completedDays, lessThanOrEqualTo(stat.scheduledDays));
    }
  });
}
