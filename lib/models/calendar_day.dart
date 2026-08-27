enum CalendarDayStatus { empty, perfect, done, missed, today, future }

class CalendarDay {
  const CalendarDay({required this.day, required this.status});

  final int? day;
  final CalendarDayStatus status;
}

class CalendarMonthStats {
  const CalendarMonthStats({
    required this.monthLabel,
    required this.currentStreak,
    required this.perfectDays,
    required this.habitsDone,
    required this.missedDays,
    required this.days,
  });

  final String monthLabel;
  final int currentStreak;
  final int perfectDays;
  final int habitsDone;
  final int missedDays;
  final List<CalendarDay> days;
}
