import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Maps the colors a user-created habit can actually have to stable string
/// keys for Firestore storage — today that's just `AppColors.terracotta`
/// (see `AddHabitScreen`, which has no color picker yet). New keys get added
/// here if/when more colors become choosable, not speculatively ahead of it.
class ColorRegistry {
  ColorRegistry._();

  static const Map<String, Color> byKey = {
    'terracotta': AppColors.terracotta,
    // Not reachable from AddHabitScreen (no color picker exists), but used
    // by MockHabitRepository's seed habits — see the same note in
    // icon_registry.dart.
    'sky': AppColors.sky,
    'mossLight': AppColors.mossLight,
    'blushPink': AppColors.blushPink,
    'mustardLight': AppColors.mustardLight,
    'blush': AppColors.blush,
    'linenAlt': AppColors.linenAlt,
  };

  static Color colorFor(String key) =>
      byKey[key] ?? (throw ArgumentError('Unknown color key: $key'));

  static String keyFor(Color color) => byKey.entries
      .firstWhere(
        (entry) => entry.value == color,
        orElse: () => throw ArgumentError('No registry key for color $color'),
      )
      .key;
}
