import 'package:flutter/material.dart';

/// Maps the icons a habit or bucket-list item can have to stable string keys
/// for Firestore storage -- see docs/BACKEND.md, "Icons: use a string-key
/// registry, never store codePoint". Reconstructing `IconData(codePoint,
/// fontFamily: 'MaterialIcons')` from a stored int looks fine in debug and
/// renders blank boxes in a release APK, because `--tree-shake-icons` (on by
/// default for release builds) strips any icon not referenced as a
/// compile-time constant. Storing a string key and looking it up through this
/// map keeps every icon a real constant reference.
///
/// The one registry for both features. Add a key here whenever a picker's
/// option list grows (`AddHabitScreen._icons`, bucket_list_screen.dart's
/// `_BucketItemDialogState._icons`); nothing else needs to change. Colors
/// are the same story in color_registry.dart.
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
    // habits, which the seed script (see docs/BACKEND.md "Data sprint")
    // writes into real Firestore documents — so they need real keys too.
    'menu_book': Icons.menu_book,
    'code': Icons.code,
    'restaurant': Icons.restaurant,
    'smartphone': Icons.smartphone,
    // Bucket-list picker (_BucketItemDialogState._icons).
    'flight_takeoff': Icons.flight_takeoff,
    'directions_run': Icons.directions_run,
    'school': Icons.school,
    'emoji_events': Icons.emoji_events,
    'terrain': Icons.terrain,
    'celebration': Icons.celebration,
    'flag': Icons.flag,
  };

  /// Fallback for a missing/unknown key on read (docs/BACKEND.md: "Unknown
  /// key on read → fall back to a default icon, don't crash") and for a
  /// value on write that somehow isn't in the registry (shouldn't happen
  /// given the pickers only offer registered values, but a fallback is
  /// cheaper than a thrown error over a cosmetic field).
  static const IconData defaultIcon = Icons.flag;
  static const String defaultKey = 'flag';

  /// Falls back instead of throwing: this reads stored data, and one item
  /// with a key this build doesn't know (renamed, or written by a newer
  /// build) shouldn't fail the whole list. [keyFor] stays strict — writing an
  /// unregistered icon is a bug to catch; use [tryKeyFor] where a fallback
  /// is wanted instead.
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
