enum CalendarDayStatus { empty, perfect, done, missed, today, future }

class CalendarDay {
  const CalendarDay({required this.day, required this.status, this.date});

  final int? day;
  final CalendarDayStatus status;

  /// Null for [CalendarDayStatus.empty] grid-padding cells. Present on every
  /// real day so a tap can look up that day's habits.
  final DateTime? date;
}

class CalendarMonthStats {
  const CalendarMonthStats({
    required this.year,
    required this.month,
    required this.monthLabel,
    required this.currentStreak,
    required this.perfectDays,
    required this.habitsDone,
    required this.missedDays,
    required this.days,
  });

  final int year;
  final int month;
  final String monthLabel;
  final int currentStreak;
  final int perfectDays;
  final int habitsDone;
  final int missedDays;
  final List<CalendarDay> days;
}
