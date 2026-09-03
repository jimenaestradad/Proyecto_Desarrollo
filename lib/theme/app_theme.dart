import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_spacing.dart';
import 'app_text_styles.dart';

export 'app_colors.dart';
export 'app_spacing.dart';
export 'app_text_styles.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get light {
    final colorScheme = const ColorScheme.light(
      primary: AppColors.moss,
      onPrimary: AppColors.white,
      primaryContainer: AppColors.mossLight,
      onPrimaryContainer: AppColors.mossDark,
      secondary: AppColors.terracotta,
      onSecondary: AppColors.white,
      secondaryContainer: AppColors.blush,
      onSecondaryContainer: AppColors.terracottaDark,
      tertiary: AppColors.mustardDark,
      onTertiary: AppColors.white,
      tertiaryContainer: AppColors.mustard,
      onTertiaryContainer: AppColors.ink,
      error: AppColors.error,
      onError: AppColors.onError,
      errorContainer: AppColors.errorContainer,
      onErrorContainer: AppColors.onErrorContainer,
      surface: AppColors.linen,
      onSurface: AppColors.ink,
      surfaceContainerLowest: AppColors.white,
      surfaceContainerLow: AppColors.linenAlt,
      surfaceContainer: AppColors.linenAlt,
      surfaceContainerHigh: AppColors.linen,
      surfaceContainerHighest: AppColors.linen,
      onSurfaceVariant: AppColors.inkMuted,
      outline: AppColors.ink,
      outlineVariant: AppColors.ink,
      inverseSurface: AppColors.ink,
      onInverseSurface: AppColors.linen,
      inversePrimary: AppColors.mossLight,
      surfaceTint: Colors.transparent,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.linen,
      fontFamily: AppTextStyles.bodyMd.fontFamily,
      textTheme: TextTheme(
        displayMedium: AppTextStyles.display,
        headlineLarge: AppTextStyles.headlineLg,
        headlineMedium: AppTextStyles.headlineMd,
        bodyLarge: AppTextStyles.bodyLg,
        bodyMedium: AppTextStyles.bodyMd,
        labelLarge: AppTextStyles.labelLg,
        labelSmall: AppTextStyles.labelSm,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.linen,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: AppTextStyles.headlineMd,
        iconTheme: const IconThemeData(color: AppColors.ink),
      ),
      splashFactory: InkRipple.splashFactory,
    );
  }
}

/// Shared padding for screen content.
const kScreenHorizontalPadding = EdgeInsets.symmetric(
  horizontal: AppSpacing.containerPaddingMobile,
);
