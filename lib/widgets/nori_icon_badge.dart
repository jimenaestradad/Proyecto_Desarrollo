import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Colored, ink-bordered icon badge used for habit/achievement/notification
/// icons. Fixed-size only — screens that size a badge from a parent's layout
/// constraints (e.g. a grid cell) build their own decoration instead.
class NoriIconBadge extends StatelessWidget {
  const NoriIconBadge({
    super.key,
    required this.icon,
    required this.background,
    required this.size,
    this.circle = false,
    required this.iconSize,
    this.iconColor = AppColors.ink,
  });

  final IconData icon;
  final Color background;
  final double size;

  /// `true` for a circular badge; `false` for the rounded-square variant
  /// (`AppRadius.sm * 0.75`) used by habit tiles/cards.
  final bool circle;
  final double iconSize;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: background,
        shape: circle ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: circle ? null : BorderRadius.circular(AppRadius.sm * 0.75),
        border: Border.all(color: AppColors.ink, width: AppBorder.thin),
      ),
      child: Icon(icon, color: iconColor, size: iconSize),
    );
  }
}
