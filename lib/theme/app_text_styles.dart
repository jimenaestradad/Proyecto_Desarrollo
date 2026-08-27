import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// Text styles named after the mockup's Tailwind `fontSize` tokens.
/// Quicksand is used for display/headline text, Nunito Sans for body/label.
class AppTextStyles {
  AppTextStyles._();

  static TextStyle display = GoogleFonts.quicksand(
    fontSize: 40,
    height: 48 / 40,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.8,
    color: AppColors.onSurface,
  );

  static TextStyle headlineLg = GoogleFonts.quicksand(
    fontSize: 32,
    height: 40 / 32,
    fontWeight: FontWeight.w700,
    color: AppColors.onSurface,
  );

  static TextStyle headlineLgMobile = GoogleFonts.quicksand(
    fontSize: 24,
    height: 32 / 24,
    fontWeight: FontWeight.w700,
    color: AppColors.onSurface,
  );

  static TextStyle headlineMd = GoogleFonts.quicksand(
    fontSize: 24,
    height: 32 / 24,
    fontWeight: FontWeight.w600,
    color: AppColors.onSurface,
  );

  static TextStyle bodyLg = GoogleFonts.nunitoSans(
    fontSize: 18,
    height: 28 / 18,
    fontWeight: FontWeight.w400,
    color: AppColors.onSurface,
  );

  static TextStyle bodyMd = GoogleFonts.nunitoSans(
    fontSize: 16,
    height: 24 / 16,
    fontWeight: FontWeight.w400,
    color: AppColors.onSurface,
  );

  static TextStyle labelLg = GoogleFonts.nunitoSans(
    fontSize: 14,
    height: 20 / 14,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.28,
    color: AppColors.onSurface,
  );

  static TextStyle labelSm = GoogleFonts.nunitoSans(
    fontSize: 12,
    height: 16 / 12,
    fontWeight: FontWeight.w600,
    color: AppColors.onSurfaceVariant,
  );
}
