import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// A tappable videogame-style circular resource meter for a pet vital. No
/// caption under the ring — [label] is kept only for screen-reader text,
/// the icon + ring fill is the whole visual.
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

    return Semantics(
      label: label,
      value: '${value.round()}%',
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
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
              color: Colors.white.withValues(alpha: 0.92),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: icon,
          ),
        ),
      ),
    );
  }
}
