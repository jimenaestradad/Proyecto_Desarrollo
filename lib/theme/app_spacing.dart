/// Spacing tokens shared across screens.
class AppSpacing {
  AppSpacing._();

  static const double unit = 8;
  static const double gutter = 16;
  static const double stackSm = 12;
  static const double stackMd = 24;
  static const double stackLg = 48;
  static const double containerPaddingMobile = 20;
  static const double containerPaddingDesktop = 40;
}

class AppRadius {
  AppRadius._();

  static const double sm = 16;
  static const double md = 24;
  static const double lg = 32;
  static const double full = 9999;
}

/// Ink-outline widths for the "Flat Storybook" design system. Every bordered
/// shape uses [AppColors.ink] at one of these weights instead of blurred
/// elevation shadows.
class AppBorder {
  AppBorder._();

  static const double thin = 2;
  static const double standard = 2.5;
  static const double thick = 3;
}
