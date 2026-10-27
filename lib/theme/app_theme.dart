import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'app_colors.dart';
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
      // The moss/ink pairing every FilledButton in the app already sets
      // explicitly, one way or another — centralized here so a plain
      // FilledButton with no override reads the same way by default.
      filledButtonTheme: const FilledButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStatePropertyAll(AppColors.moss),
          foregroundColor: WidgetStatePropertyAll(AppColors.ink),
        ),
      ),
      // Material falls back to `primary` (moss) for TextButton text, which is
      // only 2.4-2.8:1 on linen/white. DESIGN.md §7 already says text buttons
      // use mossDark (4.1-4.9:1), so make that the default for all of them.
      textButtonTheme: const TextButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStatePropertyAll(AppColors.mossDark),
        ),
      ),
      splashFactory: InkRipple.splashFactory,
    );
  }
}

/// Wires mouse into every [Scrollable]'s drag-to-scroll devices — Flutter's
/// default [ScrollBehavior] only allows touch/stylus/trackpad, so a real
/// mouse instead scrolls via the wheel (invisible, works fine normally).
/// That default falls apart specifically under Chrome DevTools' device
/// toolbar (the documented way to preview the mobile layout on web, per
/// CLAUDE.md): once a device preset like Pixel is active, input arrives as
/// simulated touch but can still surface to Flutter as [PointerDeviceKind.
/// mouse] depending on Chrome/Flutter version, and the wheel stops firing
/// too — leaving no way to scroll at all. Add mouse explicitly so drag-to-
/// scroll works the same regardless of which of those two paths fires.
class AppScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
    ...super.dragDevices,
    PointerDeviceKind.mouse,
  };
}
