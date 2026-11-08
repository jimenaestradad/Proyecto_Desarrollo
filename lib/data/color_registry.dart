import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Stable Firestore color keys shared by habit and bucket-list pickers.
/// Palette changes then avoid stranding stored items on old hex values.
///
/// `linenAlt` (beige, too close to the page background) is retired: it is not
/// registered, so items saved with that key load as [defaultColor] and are
/// written back with its key the next time they are saved.
class ColorRegistry {
  ColorRegistry._();

  static const Map<String, Color> byKey = {
    'terracotta': AppColors.terracotta,
    'sky': AppColors.sky,
    'mossLight': AppColors.mossLight,
    'blushPink': AppColors.blushPink,
    'mustardLight': AppColors.mustardLight,
    'blush': AppColors.blush,
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
