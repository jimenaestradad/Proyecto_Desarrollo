import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// A loose ring of star glyphs standing in for confetti — flat icons, no
/// physics/particles, matching the "Icons, never emoji" + flat-illustration
/// rule in CLAUDE.md rather than a sprite-based particle effect.
class ConfettiRing extends StatelessWidget {
  const ConfettiRing({super.key});

  static const _positions = [
    Offset(-0.85, -0.05),
    Offset(-0.55, -0.55),
    Offset(0, -0.75),
    Offset(0.55, -0.55),
    Offset(0.85, -0.05),
    Offset(-0.7, 0.5),
    Offset(0.7, 0.5),
  ];

  static const _colors = [
    AppColors.mustardDark,
    AppColors.terracotta,
    AppColors.moss,
    AppColors.terracottaDark,
    AppColors.mustard,
    AppColors.mossDark,
    AppColors.terracotta,
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = 260.0;
        return SizedBox(
          width: w,
          height: h,
          child: Stack(
            children: [
              for (var i = 0; i < _positions.length; i++)
                Positioned(
                  left: w / 2 + _positions[i].dx * (w / 2) - 12,
                  top: h / 2 + _positions[i].dy * (h / 2) - 12,
                  child: Icon(
                    Icons.star_rounded,
                    size: 20 + (i.isEven ? 4 : 0),
                    color: _colors[i % _colors.length],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
