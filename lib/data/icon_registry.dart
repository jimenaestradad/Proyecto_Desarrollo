import 'package:flutter/material.dart';

/// Maps the fixed set of habit icons a user can actually pick (see
/// `AddHabitScreen._icons`) to stable string keys for Firestore storage.
/// Never store `IconData.codePoint` directly — `--tree-shake-icons` blanks
/// codePoints for icons it can't statically prove are referenced, which
/// corrupts them in release APKs only. See docs/BACKEND.md "Conventions".
class IconRegistry {
  IconRegistry._();

  static const Map<String, IconData> byKey = {
    'water_drop': Icons.water_drop,
    'book': Icons.book,
    'fitness_center': Icons.fitness_center,
    'self_improvement': Icons.self_improvement,
    'savings': Icons.savings,
    'bedtime': Icons.bedtime,
    // Not reachable from the picker above, but used by
    // MockHabitRepository's seed habits, which the seed script (see
    // docs/BACKEND.md "Data sprint") writes into real Firestore documents —
    // so they need real keys too, not just the user-facing picker set.
    'menu_book': Icons.menu_book,
    'code': Icons.code,
    'restaurant': Icons.restaurant,
    'smartphone': Icons.smartphone,
  };

  static IconData iconFor(String key) =>
      byKey[key] ?? (throw ArgumentError('Unknown icon key: $key'));

  static String keyFor(IconData icon) => byKey.entries
      .firstWhere(
        (entry) => entry.value == icon,
        orElse: () => throw ArgumentError('No registry key for icon $icon'),
      )
      .key;
}
