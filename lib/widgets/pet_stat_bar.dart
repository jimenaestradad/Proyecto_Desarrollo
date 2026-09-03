import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// A chunky, color-coded horizontal bar styled like a classic video-game
/// health meter — used for the pet's Hunger/Hygiene/Happiness vitals.
/// Deliberately blocky (not a rounded [ProgressBarPill]) with a level-coded
/// fill, so it reads as a "vitals gauge" rather than a generic progress bar.
class PetStatBar extends StatelessWidget {
  const PetStatBar({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;

  /// 0–100.
  final double value;

  Color get _fillColor {
    if (value >= 60) return AppColors.moss;
    if (value >= 30) return AppColors.mustard;
    return AppColors.terracottaDark;
  }

  @override
  Widget build(BuildContext context) {
    final fraction = (value / 100).clamp(0, 1).toDouble();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: AppColors.white,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.ink, width: AppBorder.thin),
          ),
          alignment: Alignment.center,
          child: Icon(icon, size: 18, color: AppColors.ink),
        ),
        const SizedBox(width: AppSpacing.stackSm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      label.toUpperCase(),
                      style: AppTextStyles.labelSm,
                    ),
                  ),
                  Text(
                    '${value.round()}%',
                    style: AppTextStyles.labelLg.copyWith(color: _fillColor),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              Container(
                height: 14,
                decoration: BoxDecoration(
                  color: AppColors.linen,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: AppColors.ink,
                    width: AppBorder.thin,
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        widthFactor: fraction,
                        child: Container(height: 14, color: _fillColor),
                      ),
                    ),
                    Align(
                      alignment: Alignment.topLeft,
                      child: FractionallySizedBox(
                        widthFactor: fraction,
                        child: Container(
                          height: 3,
                          color: AppColors.white.withValues(alpha: 0.35),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
