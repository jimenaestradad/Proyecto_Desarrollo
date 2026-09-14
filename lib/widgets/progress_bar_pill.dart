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
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: progress.clamp(0, 1),
                  child: Container(height: height, color: color),
                ),
              ),
              if (thresholdFraction != null)
                Positioned(
                  // Not FractionallySizedBox here: it gives its child a
                  // *tight* width of widthFactor × available width, which
                  // overrides this line's own `width: AppBorder.standard`
                  // instead of just capping it — the tick rendered as a
                  // solid block from 0 to thresholdFraction instead of a
                  // thin marker at that position.
                  left: (thresholdFraction!.clamp(0, 1) * constraints.maxWidth -
                          AppBorder.standard / 2)
                      .clamp(
                        0.0,
                        (constraints.maxWidth - AppBorder.standard).clamp(
                          0.0,
                          double.infinity,
                        ),
                      ),
                  top: 0,
                  bottom: 0,
                  width: AppBorder.standard,
                  child: ColoredBox(color: AppColors.ink.withValues(alpha: 0.5)),
                ),
            ],
          );
        },
      ),
    );
  }
}
