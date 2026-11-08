import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Reusable padded, rounded, ink-bordered card with caller-supplied styling.
/// Cards needing ink splashes, animated containers or richer shells remain bespoke.
class NoriCard extends StatelessWidget {
  const NoriCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.containerPaddingMobile),
    this.color = AppColors.white,
    this.radius = AppRadius.sm,
    this.borderWidth = AppBorder.standard,
    this.borderColor = AppColors.ink,
    this.clipBehavior = Clip.none,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;
  final double radius;
  final double borderWidth;
  final Color borderColor;
  final Clip clipBehavior;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      clipBehavior: clipBehavior,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor, width: borderWidth),
      ),
      child: child,
    );
  }
}
