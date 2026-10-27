import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Maps the colors a habit or bucket-list item can have to stable string
/// keys for Firestore storage (docs/BACKEND.md, "Colors: store the palette
/// key, not an int" — a palette tweak shouldn't strand old rows on a stale
/// hex value). The one registry for both features, like [IconRegistry].
/// `AddHabitScreen`'s color picker offers every key here, and the bucket
/// list's offers a subset, so a new key only needs adding here.
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

  static const Color defaultColor = AppColors.mossLight;
  static const String defaultKey = 'mossLight';

  /// Falls back instead of throwing, for the same reason as
  /// [IconRegistry.iconFor].
  static Color colorFor(String? key) => byKey[key] ?? defaultColor;

  /// Null only if [color] isn't registered.
  static String? tryKeyFor(Color color) {
    for (final entry in byKey.entries) {
      if (entry.value == color) return entry.key;
    }
    return null;
  }

  static String keyFor(Color color) =>
      tryKeyFor(color) ??
      (throw ArgumentError('No registry key for color $color'));
}
