import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:nori/models/pet.dart';
import 'package:nori/theme/app_theme.dart';
import 'package:nori/widgets/nori_breathing_sprite.dart';
import 'package:nori/widgets/tactile_button.dart';

/// Full-screen celebration shown the moment [Pet.stage] advances — the
/// "Pantalla/animacion de evolucion" beat FEATURES.md §6 calls for but
/// doesn't spec further. Reuses [NoriBreathingSprite] rather than new art:
/// only one evolution stage exists today (MVP per §6), so there's no
/// second sprite to swap in yet — see docs/OPEN_DECISIONS.md "Pet
/// mechanics". When stage-specific art exists, swap the sprite here for
/// one that depends on [stage].
///
/// Push with [showEvolutionCelebration] rather than a bare
/// `Navigator.push`, so every call site gets the same fade+scale entrance.
class EvolutionScreen extends StatefulWidget {
  const EvolutionScreen({super.key, required this.petName, required this.stage});

  final String petName;
  final PetEvolutionStage stage;

  @override
  State<EvolutionScreen> createState() => _EvolutionScreenState();
}

Future<void> showEvolutionCelebration(
  BuildContext context, {
  required String petName,
  required PetEvolutionStage stage,
}) {
  return Navigator.of(context).push(
    PageRouteBuilder(
      opaque: false,
      barrierColor: AppColors.ink.withValues(alpha: 0.35),
      transitionDuration: const Duration(milliseconds: 350),
      reverseTransitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (context, animation, secondaryAnimation) =>
          EvolutionScreen(petName: petName, stage: stage),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutBack,
          reverseCurve: Curves.easeIn,
        );
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(scale: curved, child: child),
        );
      },
    ),
  );
}

class _EvolutionScreenState extends State<EvolutionScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.gutter),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Material(
              color: AppColors.linen,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(
                    color: AppColors.ink,
                    width: AppBorder.thick,
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  alignment: Alignment.topCenter,
                  children: [
                    Positioned(
                      top: -60,
                      left: -40,
                      child: ImageFiltered(
                        imageFilter: ui.ImageFilter.blur(
                          sigmaX: 40,
                          sigmaY: 40,
                        ),
                        child: Container(
                          width: 200,
                          height: 200,
                          decoration: const BoxDecoration(
                            color: AppColors.mustardLight,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: -70,
                      right: -50,
                      child: ImageFiltered(
                        imageFilter: ui.ImageFilter.blur(
                          sigmaX: 44,
                          sigmaY: 44,
                        ),
                        child: Container(
                          width: 220,
                          height: 220,
                          decoration: const BoxDecoration(
                            color: AppColors.mossLight,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ),
                    const _ConfettiRing(),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.gutter,
                        AppSpacing.stackLg,
                        AppSpacing.gutter,
                        AppSpacing.gutter,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'YOUR NORI EVOLVED!',
                            textAlign: TextAlign.center,
                            style: AppTextStyles.labelLg.copyWith(
                              color: AppColors.terracottaDark,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.stackSm),
                          SizedBox(
                            width: 160,
                            height: 160,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: AppColors.mossLight,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppColors.ink,
                                  width: AppBorder.standard,
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(
                                  AppSpacing.unit,
                                ),
                                child: NoriBreathingSprite(),
                              ),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.stackMd),
                          Text(
                            widget.stage.label,
                            textAlign: TextAlign.center,
                            style: AppTextStyles.headlineLg,
                          ),
                          const SizedBox(height: AppSpacing.stackSm),
                          Text(
                            '${widget.petName} grew thanks to your '
                            'consistency. Keep those habits up!',
                            textAlign: TextAlign.center,
                            style: AppTextStyles.bodyMd.copyWith(
                              color: AppColors.inkFaint,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.stackMd),
                          TactileButton(
                            label: 'Nice!',
                            icon: Icons.celebration,
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A loose ring of star glyphs standing in for confetti — flat icons, no
/// physics/particles, matching the "Icons, never emoji" + flat-illustration
/// rule in CLAUDE.md rather than a sprite-based particle effect.
class _ConfettiRing extends StatelessWidget {
  const _ConfettiRing();

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
