import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// Text styles for the "Flat Storybook" design system: Fredoka for
/// display/headline (the rounded storybook wordmark feel), Karla for
/// body/label text.
class AppTextStyles {
  AppTextStyles._();

  static TextStyle display = GoogleFonts.fredoka(
    fontSize: 40,
    height: 48 / 40,
    fontWeight: FontWeight.w700,
    color: AppColors.ink,
  );

  static TextStyle headlineLg = GoogleFonts.fredoka(
    fontSize: 32,
    height: 40 / 32,
    fontWeight: FontWeight.w700,
    color: AppColors.ink,
  );

  static TextStyle headlineLgMobile = GoogleFonts.fredoka(
    fontSize: 24,
    height: 32 / 24,
    fontWeight: FontWeight.w600,
    color: AppColors.ink,
  );

  static TextStyle headlineMd = GoogleFonts.fredoka(
    fontSize: 24,
    height: 30 / 24,
    fontWeight: FontWeight.w600,
    color: AppColors.ink,
  );

  static TextStyle bodyLg = GoogleFonts.karla(
    fontSize: 18,
    height: 28 / 18,
    fontWeight: FontWeight.w400,
    color: AppColors.ink,
  );

  static TextStyle bodyMd = GoogleFonts.karla(
    fontSize: 16,
    height: 24 / 16,
    fontWeight: FontWeight.w400,
    color: AppColors.ink,
  );

  static TextStyle labelLg = GoogleFonts.karla(
    fontSize: 14,
    height: 20 / 14,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.2,
    color: AppColors.ink,
  );

  static TextStyle labelSm = GoogleFonts.karla(
    fontSize: 11,
    height: 16 / 11,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.3,
    color: AppColors.inkMuted,
  );
}
