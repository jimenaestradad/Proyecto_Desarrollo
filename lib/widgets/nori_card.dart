import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// The ink-bordered card shell reused across nearly every screen: a padded
/// box with a solid background, a rounded [Border.all], and a child. Screens
/// previously reimplemented this exact `Container`+`BoxDecoration` shape
/// locally with their own color/radius/border-width/padding — this just
/// consolidates the shape; every call site still passes its own values, so
/// nothing about how a given card actually looks changes.
///
/// Not a fit for a card that also needs `Material`/`InkWell` ink-splash
/// feedback, an `AnimatedContainer` transition, or that already composes a
/// richer local shell (see `_CardShell` in habit_progress_card.dart's
/// content, or `_ItemCardShell`'s inner tile in shop_screen.dart) — those
/// stay bespoke.
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
