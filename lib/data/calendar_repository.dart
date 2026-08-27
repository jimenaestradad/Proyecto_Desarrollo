import '../models/calendar_day.dart';

abstract class CalendarRepository {
  Future<CalendarMonthStats> getCurrentMonth();
}

class MockCalendarRepository implements CalendarRepository {
  @override
  Future<CalendarMonthStats> getCurrentMonth() async {
    const statuses = [
      CalendarDayStatus.empty,
      CalendarDayStatus.empty,
      CalendarDayStatus.perfect,
      CalendarDayStatus.done,
      CalendarDayStatus.done,
      CalendarDayStatus.missed,
      CalendarDayStatus.perfect,
      CalendarDayStatus.done,
      CalendarDayStatus.done,
      CalendarDayStatus.done,
      CalendarDayStatus.perfect,
      CalendarDayStatus.done,
      CalendarDayStatus.done,
      CalendarDayStatus.today,
      CalendarDayStatus.future,
      CalendarDayStatus.future,
      CalendarDayStatus.future,
      CalendarDayStatus.future,
      CalendarDayStatus.future,
      CalendarDayStatus.future,
      CalendarDayStatus.future,
    ];

    final days = <CalendarDay>[];
    var dayNumber = 1;
    for (final status in statuses) {
      if (status == CalendarDayStatus.empty) {
        days.add(const CalendarDay(day: null, status: CalendarDayStatus.empty));
      } else {
        days.add(CalendarDay(day: dayNumber, status: status));
        dayNumber++;
      }
    }

    return CalendarMonthStats(
      monthLabel: 'October',
      currentStreak: 12,
      perfectDays: 8,
      habitsDone: 45,
      missedDays: 3,
      days: days,
    );
  }
}
