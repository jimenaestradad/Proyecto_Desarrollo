final _thousandsSeparator = RegExp(r'\B(?=(\d{3})+(?!\d))');

/// Inserts thousands-separator commas into an integer, e.g. `1250` → `1,250`.
String formatThousands(int value) =>
    value.toString().replaceAllMapped(_thousandsSeparator, (match) => ',');

/// Renders a [double] without a trailing `.0` when it has no fractional part,
/// e.g. `3.0` → `'3'`, `2.5` → `'2.5'`.
String formatTrimmedNumber(double value) => value == value.roundToDouble()
    ? value.round().toString()
    : value.toString();

/// `1` → `'1st'`, `12` → `'12th'`, `23` → `'23rd'`.
String ordinal(int n) {
  if (n % 100 >= 11 && n % 100 <= 13) return '${n}th';
  return '$n${switch (n % 10) {
    1 => 'st',
    2 => 'nd',
    3 => 'rd',
    _ => 'th',
  }}';
}
