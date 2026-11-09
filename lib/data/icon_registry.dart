import 'package:flutter/material.dart';

/// Stable Firestore icon keys shared by habit and bucket-list pickers.
/// Constant icon references survive release icon tree shaking; stored codePoints do not.
class IconRegistry {
  IconRegistry._();

  static const Map<String, IconData> byKey = {
    // Habit picker (AddHabitScreen._icons).
    'water_drop': Icons.water_drop,
    'book': Icons.book,
    'fitness_center': Icons.fitness_center,
    'self_improvement': Icons.self_improvement,
    'savings': Icons.savings,
    'bedtime': Icons.bedtime,
    // Not reachable from that picker, but used by MockHabitRepository's seed
    // habits, which the seed script (see docs/technical/BACKEND.md "Data sprint")
    // writes into real Firestore documents — so they need real keys too.
    'menu_book': Icons.menu_book,
    'code': Icons.code,
    'restaurant': Icons.restaurant,
    'smartphone': Icons.smartphone,
    'church': Icons.church,
    // Bucket-list picker (_BucketItemDialogState._icons).
    'flight_takeoff': Icons.flight_takeoff,
    'directions_run': Icons.directions_run,
    'school': Icons.school,
    'emoji_events': Icons.emoji_events,
    'terrain': Icons.terrain,
    'celebration': Icons.celebration,
    'flag': Icons.flag,
  };

  /// Fallback for unknown stored keys or unregistered values on write.
  /// Cosmetic fields should not make the whole item fail.
  static const IconData defaultIcon = Icons.flag;
  static const String defaultKey = 'flag';

  /// Falls back for unknown stored keys so one item cannot fail the list.
  /// [keyFor] remains strict on writes; use [tryKeyFor] for a write fallback.
  static IconData iconFor(String? key) => byKey[key] ?? defaultIcon;

  /// Null only if [icon] isn't registered.
  static String? tryKeyFor(IconData icon) {
    for (final entry in byKey.entries) {
      if (entry.value == icon) return entry.key;
    }
    return null;
  }

  static String keyFor(IconData icon) =>
      tryKeyFor(icon) ??
      (throw ArgumentError('No registry key for icon $icon'));
}
