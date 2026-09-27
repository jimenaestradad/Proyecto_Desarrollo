import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// String-key registry for persisting [IconData] and [Color] values to
/// Firestore -- see docs/BACKEND.md, "Icons: use a string-key registry,
/// never store codePoint" and "Colors: store the palette key, not an
/// int." Reconstructing `IconData(codePoint, fontFamily: 'MaterialIcons')`
/// from a stored int looks fine in debug and renders blank boxes in a
/// release APK, because `--tree-shake-icons` (on by default for release
/// builds) strips any icon not referenced as a compile-time constant.
/// Storing a string key and looking it up through this map keeps every
/// icon a real constant reference. Same reasoning for colors: a palette
/// tweak shouldn't strand old rows on a stale hex value.
///
/// Covers every icon/color [BucketListItem] can be created or edited with
/// today -- see bucket_list_screen.dart's `_BucketItemDialogState._icons`
/// / `_colors`, the only place that picker exists. Add a key here
/// whenever that picker's option list grows; nothing else needs to
/// change. (Habit's icon/color registry, if habits ever need one, is
/// Valeria's vertical -- see docs/BACKEND.md, "Division of labor".)

const Map<String, IconData> kIconRegistry = {
  'flight_takeoff': Icons.flight_takeoff,
  'directions_run': Icons.directions_run,
  'school': Icons.school,
  'emoji_events': Icons.emoji_events,
  'terrain': Icons.terrain,
  'celebration': Icons.celebration,
};

/// Fallback for a missing/unknown key on read (docs/BACKEND.md: "Unknown
/// key on read → fall back to a default icon, don't crash") and for a
/// value on write that somehow isn't in the registry at all (shouldn't
/// happen given the picker only offers registered values, but a fallback
/// is cheaper than a thrown error over a cosmetic field).
const IconData kDefaultIcon = Icons.flag;
const String kDefaultIconKey = 'flag';

const Map<String, Color> kColorRegistry = {
  'blushPink': AppColors.blushPink,
  'mossLight': AppColors.mossLight,
  'sky': AppColors.sky,
  'mustardLight': AppColors.mustardLight,
  'terracotta': AppColors.terracotta,
};

const Color kDefaultColor = AppColors.mossLight;
const String kDefaultColorKey = 'mossLight';

/// Null only if [icon] isn't one of the constants above -- callers should
/// fall back to [kDefaultIconKey] when writing rather than writing a null
/// key, so a bad round-trip is still recoverable on the next read.
String? iconKeyFor(IconData icon) {
  for (final entry in kIconRegistry.entries) {
    if (entry.value == icon) return entry.key;
  }
  return null;
}

IconData iconForKey(String? key) => kIconRegistry[key] ?? kDefaultIcon;

String? colorKeyFor(Color color) {
  for (final entry in kColorRegistry.entries) {
    if (entry.value == color) return entry.key;
  }
  return null;
}

Color colorForKey(String? key) => kColorRegistry[key] ?? kDefaultColor;
