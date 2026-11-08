import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Below this (out of 100) a vital reads as low: the ring's center turns
/// red-tinted and gets a dot. Keep in sync with `LOW_VITAL` in
/// functions/src/notifications.ts, the threshold for "Pet Needs You".
const kLowVital = 30;

/// A tappable videogame-style circular resource meter for a pet vital. No
/// caption under the ring — [label] is kept only for screen-reader text,
/// the icon + ring fill is the whole visual, plus a red-tinted center and a
/// dot once the vital drops below [kLowVital].
class PetVitalRing extends StatelessWidget {
  const PetVitalRing({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.onTap,
  });

  final Widget icon;
  final String label;

  /// 0–100.
  final double value;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fraction = (value / 100).clamp(0, 1).toDouble();
    final fillRemainder = Colors.white.withValues(alpha: 0.35);
    final isLow = value < kLowVital;

    final ring = Container(
      width: 54,
      height: 54,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: SweepGradient(
          colors: [color, color, fillRemainder, fillRemainder],
          stops: [0, fraction, fraction, 1],
          transform: GradientRotation(-math.pi / 2),
        ),
        border: Border.all(color: AppColors.ink, width: AppBorder.thin),
        boxShadow: [
          BoxShadow(
            color: AppColors.ink.withValues(alpha: 0.15),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: isLow
              ? AppColors.errorContainer
              : Colors.white.withValues(alpha: 0.92),
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: IconTheme.merge(
          data: IconThemeData(
            color: isLow ? AppColors.onErrorContainer : AppColors.ink,
          ),
          child: icon,
        ),
      ),
    );

    return Semantics(
      label: isLow ? '$label (low)' : label,
      value: '${value.round()}%',
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: !isLow
            ? ring
            : Stack(
                clipBehavior: Clip.none,
                children: [
                  ring,
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: AppColors.error,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.ink,
                          width: AppBorder.thin,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
