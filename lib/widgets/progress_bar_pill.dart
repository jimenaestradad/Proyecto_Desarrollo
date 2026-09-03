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
  });

  final double progress;
  final double height;
  final Color color;
  final Color trackColor;
  final bool bordered;

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
      alignment: Alignment.centerLeft,
      clipBehavior: Clip.antiAlias,
      child: FractionallySizedBox(
        widthFactor: progress.clamp(0, 1),
        child: Container(color: color),
      ),
    );
  }
}
