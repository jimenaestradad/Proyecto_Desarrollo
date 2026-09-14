final _thousandsSeparator = RegExp(r'\B(?=(\d{3})+(?!\d))');

/// Inserts thousands-separator commas into an integer, e.g. `1250` → `1,250`.
String formatThousands(int value) =>
    value.toString().replaceAllMapped(_thousandsSeparator, (match) => ',');

/// Renders a [double] without a trailing `.0` when it has no fractional part,
/// e.g. `3.0` → `'3'`, `2.5` → `'2.5'`.
String formatTrimmedNumber(double value) =>
    value == value.roundToDouble() ? value.round().toString() : value.toString();
