import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:nori/models/pet.dart';
import 'package:nori/theme/app_theme.dart';
import 'package:nori/widgets/confetti_ring.dart';
import 'package:nori/widgets/nori_breathing_sprite.dart';
import 'package:nori/widgets/tactile_button.dart';

/// Full-screen celebration shown the moment [Pet.stage] advances — the
/// "Pantalla/animacion de evolucion" beat FEATURES.md §6 calls for but
/// doesn't spec further. Reuses [NoriBreathingSprite] behind a warm glow
/// (the same placeholder "grew" treatment as [NoriRoomStage]'s evolved
/// aura) rather than new art — see docs/KNOWN_ISSUES.md: real stage-2
/// character art needs new photography of the physical prop the existing
/// frames were shot from, not something drawable in code. Swap both spots
/// for real per-stage art together once it exists.
///
/// Push with [showEvolutionCelebration] rather than a bare
/// `Navigator.push`, so every call site gets the same fade+scale entrance.
class EvolutionScreen extends StatefulWidget {
  const EvolutionScreen({
    super.key,
    required this.petName,
    required this.stage,
  });

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
                    const ConfettiRing(),
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
                          // The glow behind the circle is the same
                          // "grown" cue as NoriRoomStage's evolved aura —
                          // a placeholder for real stage-2 art, not a
                          // one-off effect (see docs/KNOWN_ISSUES.md).
                          SizedBox(
                            width: 200,
                            height: 200,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                ImageFiltered(
                                  imageFilter: ui.ImageFilter.blur(
                                    sigmaX: 28,
                                    sigmaY: 28,
                                  ),
                                  child: Container(
                                    width: 190,
                                    height: 190,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: AppColors.mustard.withValues(
                                        alpha: 0.6,
                                      ),
                                    ),
                                  ),
                                ),
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
                                      child: const NoriBreathingSprite(),
                                    ),
                                  ),
                                ),
                              ],
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
