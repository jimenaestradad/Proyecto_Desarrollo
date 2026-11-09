import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_spacing.dart';
import 'app_text_styles.dart';

export 'app_colors.dart';
export 'app_spacing.dart';
export 'app_text_styles.dart';

class AppTheme {
  AppTheme._();

  /// The red confirm button for permanent deletes (Delete account, Delete
  /// habit, Delete bucket-list goal), so every destructive confirm reads the
  /// same. Pass as `FilledButton(style: AppTheme.destructiveFilledButton)`.
  static ButtonStyle get destructiveFilledButton => FilledButton.styleFrom(
    backgroundColor: AppColors.error,
    foregroundColor: AppColors.onError,
  );

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
      // Ink outline on every state, and an ink thumb when off: the default
      // white thumb on the pale off-track was barely visible on linen.
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.white
              : AppColors.ink,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.moss
              : AppColors.linenAlt,
        ),
        trackOutlineColor: const WidgetStatePropertyAll(AppColors.ink),
        trackOutlineWidth: const WidgetStatePropertyAll(AppBorder.thin),
      ),
      splashFactory: InkRipple.splashFactory,
    );
  }
}

/// Enables mouse drag scrolling alongside Flutter's default input devices.
/// Chrome DevTools device emulation can surface touch as mouse and suppress the wheel.
class AppScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
    ...super.dragDevices,
    PointerDeviceKind.mouse,
  };
}
