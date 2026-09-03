import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Rounded, filled progress track shared by daily progress, streak
/// calendar stats and achievement cards.
class ProgressBarPill extends StatelessWidget {
  const ProgressBarPill({
    super.key,
    required this.progress,
    this.height = 12,
    this.color = AppColors.moss,
    this.trackColor = AppColors.linen,
    this.bordered = true,
    this.thresholdFraction,
  });

  final double progress;
  final double height;
  final Color color;
  final Color trackColor;
  final bool bordered;

  /// Optional minimum-threshold tick mark (0–1), drawn as a thin ink line
  /// inside the track — used by quantity/duration/cumulative habit cards.
  final double? thresholdFraction;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: trackColor,
        borderRadius: BorderRadius.circular(height),
        border: bordered
            ? Border.all(color: AppColors.ink, width: AppBorder.thin)
            : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: progress.clamp(0, 1),
              child: Container(height: height, color: color),
            ),
          ),
          if (thresholdFraction != null)
            Align(
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: thresholdFraction!.clamp(0, 1),
                alignment: Alignment.centerRight,
                child: Container(
                  width: AppBorder.standard,
                  height: height,
                  color: AppColors.ink.withValues(alpha: 0.5),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
