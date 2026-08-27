/// Spacing and radius tokens copied from the mockup's Tailwind config.
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

  static const double sm = 16; // Tailwind `DEFAULT` (1rem)
  static const double md = 32; // Tailwind `lg` (2rem)
  static const double lg = 48; // Tailwind `xl` (3rem)
  static const double full = 9999;
}
