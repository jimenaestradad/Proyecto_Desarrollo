import 'package:flutter/material.dart';

/// Color tokens for Nori's "Flat Storybook" design system — ported from the
/// Claude Design canvas variant 2a (warm linen paper, thick ink outlines,
/// flat moss/terracotta/mustard/blush accents). See `docs/` for product
/// scope; this file is purely the visual palette.
class AppColors {
  AppColors._();

  // Ink — borders, headings, primary text.
  static const ink = Color(0xFF3A2E22);
  static const inkMuted = Color(0xFF7A6B4F);
  static const inkFaint = Color(0xFF6E634F);

  // Paper — base surfaces.
  static const linen = Color(0xFFF3ECDD);
  static const linenAlt = Color(0xFFF6F1E4);
  static const white = Color(0xFFFFFFFF);

  // Moss — level progress, checkboxes, pet portrait card.
  static const moss = Color(0xFF8FA06B);
  static const mossLight = Color(0xFFDCE6CC);
  static const mossDark = Color(0xFF5B7A45);

  // Terracotta — FAB, today's-goal progress, happiness accent.
  static const terracotta = Color(0xFFC9986A);
  static const terracottaDark = Color(0xFFB5652F);

  // Blush — avatar bg, happiness icon bg, "read" habit icon bg.
  static const blush = Color(0xFFEED9CF);
  static const blushPink = Color(0xFFF0D9E0);

  // Mustard — XP pill, streak accent.
  static const mustard = Color(0xFFFBE38A);
  static const mustardLight = Color(0xFFF4E3A8);
  static const mustardDark = Color(0xFF9A7C1F);

  // Sky — "water" habit icon bg.
  static const sky = Color(0xFFD9E7EA);

  // Sky blue — hygiene/"clean" vital ring fill. Distinct from [sky] (a pale
  // background tint) — this needs to read clearly as a ring fill.
  static const skyBlue = Color(0xFF7AB8D9);

  // Status — kept from Material defaults, no equivalent in the 2a mockup.
  static const error = Color(0xFFBA1A1A);
  static const onError = Color(0xFFFFFFFF);
  static const errorContainer = Color(0xFFFFDAD6);
  static const onErrorContainer = Color(0xFF93000A);
}
