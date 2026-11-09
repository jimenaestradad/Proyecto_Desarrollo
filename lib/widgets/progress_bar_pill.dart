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
    this.semanticLabel,
  });

  final double progress;
  final double height;
  final Color color;
  final Color trackColor;
  final bool bordered;

  /// Optional minimum-threshold tick mark (0–1), drawn as a thin ink line
  /// inside the track — used by quantity/duration/cumulative habit cards.
  final double? thresholdFraction;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel,
      value: '${(progress.clamp(0, 1) * 100).round()}%',
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: trackColor,
          borderRadius: BorderRadius.circular(height),
          border: bordered
              ? Border.all(color: AppColors.ink, width: AppBorder.thin)
              : null,
        ),
        // Container's BoxDecoration already pads for the border.
        // Another inset would consume the fill on short bars.
        child: LayoutBuilder(
          builder: (context, constraints) {
            final innerWidth = constraints.maxWidth;
            return Stack(
              children: [
                // Clip the fill to its own inner RRect.
                // Container clipping follows the decoration's outer edge and can bleed into corners.
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(height),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        widthFactor: progress.clamp(0, 1),
                        child: Container(height: height, color: color),
                      ),
                    ),
                  ),
                ),
                if (thresholdFraction != null)
                  Positioned(
                    // Position the fixed-width tick directly.
                    // FractionallySizedBox would force its width to a fraction of the track, making a block.
                    left:
                        (thresholdFraction!.clamp(0, 1) * innerWidth -
                                AppBorder.standard / 2)
                            .clamp(
                              0.0,
                              (innerWidth - AppBorder.standard).clamp(
                                0.0,
                                double.infinity,
                              ),
                            ),
                    top: 0,
                    bottom: 0,
                    width: AppBorder.standard,
                    child: ColoredBox(
                      color: AppColors.ink.withValues(alpha: 0.5),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
