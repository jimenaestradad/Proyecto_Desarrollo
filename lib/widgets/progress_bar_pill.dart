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
        // The Container already pads its child by the border's width
        // (BoxDecoration.padding), so everything below is laid out inside
        // the track. Insetting again here used to eat the whole fill on the
        // short bars (6px XP pill, 8px Today's Goal): 2px of border on each
        // side, twice, left nothing to draw.
        child: LayoutBuilder(
          builder: (context, constraints) {
            final innerWidth = constraints.maxWidth;
            return Stack(
              children: [
                // Clipped on its own RRect, not the outer Container's
                // `clipBehavior`: a Container clips to the *outer* edge of
                // its decoration, not inset by the border's stroke, so a
                // sharp-cornered fill rectangle clipped that way can bleed
                // into the rounded border's corner instead of stopping
                // inside it — most visible on a fully/near-fully filled bar.
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
                    // Not FractionallySizedBox here: it gives its child a
                    // *tight* width of widthFactor × available width, which
                    // overrides this line's own `width: AppBorder.standard`
                    // instead of just capping it — the tick rendered as a
                    // solid block from 0 to thresholdFraction instead of a
                    // thin marker at that position.
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
