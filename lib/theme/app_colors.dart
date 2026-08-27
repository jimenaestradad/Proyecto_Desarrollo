import 'package:flutter/material.dart';

/// Color tokens copied 1:1 from the Stitch mockup's Tailwind config
/// (see `Frontend` in the repo root). Light theme only — the mockup has no
/// dark palette to port yet.
class AppColors {
  AppColors._();

  static const primary = Color(0xFF6B38D4);
  static const onPrimary = Color(0xFFFFFFFF);
  static const primaryContainer = Color(0xFF8455EF);
  static const onPrimaryContainer = Color(0xFFFFFBFF);
  static const primaryFixed = Color(0xFFE9DDFF);
  static const onPrimaryFixed = Color(0xFF23005C);
  static const primaryFixedDim = Color(0xFFD0BCFF);
  static const onPrimaryFixedVariant = Color(0xFF5516BE);
  static const surfaceTint = Color(0xFF6D3BD7);

  static const secondary = Color(0xFF006C49);
  static const onSecondary = Color(0xFFFFFFFF);
  static const secondaryContainer = Color(0xFF6CF8BB);
  static const onSecondaryContainer = Color(0xFF00714D);
  static const secondaryFixed = Color(0xFF6FFBBE);
  static const onSecondaryFixed = Color(0xFF002113);
  static const secondaryFixedDim = Color(0xFF4EDEA3);
  static const onSecondaryFixedVariant = Color(0xFF005236);

  static const tertiary = Color(0xFF765700);
  static const onTertiary = Color(0xFFFFFFFF);
  static const tertiaryContainer = Color(0xFF956E00);
  static const onTertiaryContainer = Color(0xFFFFFBFF);
  static const tertiaryFixed = Color(0xFFFFDF9F);
  static const onTertiaryFixed = Color(0xFF261A00);
  static const tertiaryFixedDim = Color(0xFFF9BD22);
  static const onTertiaryFixedVariant = Color(0xFF5C4300);

  static const error = Color(0xFFBA1A1A);
  static const onError = Color(0xFFFFFFFF);
  static const errorContainer = Color(0xFFFFDAD6);
  static const onErrorContainer = Color(0xFF93000A);

  static const background = Color(0xFFF8F9FF);
  static const onBackground = Color(0xFF121C2A);
  static const surface = Color(0xFFF8F9FF);
  static const onSurface = Color(0xFF121C2A);
  static const surfaceVariant = Color(0xFFD9E3F6);
  static const onSurfaceVariant = Color(0xFF494454);
  static const outline = Color(0xFF7B7486);
  static const outlineVariant = Color(0xFFCBC3D7);

  static const surfaceDim = Color(0xFFD0DBED);
  static const surfaceBright = Color(0xFFF8F9FF);
  static const surfaceContainerLowest = Color(0xFFFFFFFF);
  static const surfaceContainerLow = Color(0xFFEFF4FF);
  static const surfaceContainer = Color(0xFFE6EEFF);
  static const surfaceContainerHigh = Color(0xFFDEE9FC);
  static const surfaceContainerHighest = Color(0xFFD9E3F6);

  static const inverseSurface = Color(0xFF27313F);
  static const inverseOnSurface = Color(0xFFEAF1FF);
  static const inversePrimary = Color(0xFFD0BCFF);
}
