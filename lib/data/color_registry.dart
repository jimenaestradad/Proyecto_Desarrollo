import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Maps the colors a habit can have to stable string keys for Firestore
/// storage. `AddHabitScreen`'s color picker offers every key here (added
/// 2026-10-05), so a new key must go in both places.
class ColorRegistry {
  ColorRegistry._();

  static const Map<String, Color> byKey = {
    'terracotta': AppColors.terracotta,
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
