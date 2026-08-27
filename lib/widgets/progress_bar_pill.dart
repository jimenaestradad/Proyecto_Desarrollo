import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Rounded, filled progress track shared by daily progress, streak
/// calendar stats and achievement cards.
class ProgressBarPill extends StatelessWidget {
  const ProgressBarPill({
    super.key,
    required this.progress,
    this.height = 12,
    this.color = AppColors.primary,
    this.trackColor = AppColors.surfaceContainerHighest,
  });

  final double progress;
  final double height;
  final Color color;
  final Color trackColor;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: Container(
        height: height,
        color: trackColor,
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: progress.clamp(0, 1),
          child: Container(color: color),
        ),
      ),
    );
  }
}
