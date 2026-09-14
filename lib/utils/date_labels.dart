const _weekdayNames = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

const _weekdayAbbrNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

/// Ambiguous between Tue/Thu and Sat/Sun by design — matches how this has
/// always been displayed in the Add Habit day picker.
const _weekdayInitials = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

const _monthNames = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

const _monthAbbrNames = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// [weekday] is 1-indexed, matching [DateTime.weekday] (Monday = 1).
String weekdayFull(int weekday) => _weekdayNames[weekday - 1];

/// First 3 letters, e.g. `'Mon'`.
String weekdayAbbr(int weekday) => _weekdayAbbrNames[weekday - 1];

/// First letter only, e.g. `'M'`.
String weekdayInitial(int weekday) => _weekdayInitials[weekday - 1];

/// [month] is 1-indexed, matching [DateTime.month] (January = 1).
String monthFull(int month) => _monthNames[month - 1];

/// First 3 letters, e.g. `'Jan'`.
String monthAbbr(int month) => _monthAbbrNames[month - 1];
