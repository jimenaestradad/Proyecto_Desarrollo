import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:nori/theme/app_theme.dart';
import 'package:nori/widgets/confetti_ring.dart';
import 'package:nori/widgets/tactile_button.dart';

/// Full-screen celebration shown when the user's level increases —
/// [EvolutionScreen]'s sibling for the other half of the core loop
/// (complete habits → earn XP → level up → pet grows). Same shell
/// (glow + confetti + bordered card), reused rather than duplicated.
/// Push with [showLevelUpCelebration] rather than a bare `Navigator.push`.
class LevelUpScreen extends StatefulWidget {
  const LevelUpScreen({super.key, required this.level, required this.petName});

  final int level;
  final String petName;

  @override
  State<LevelUpScreen> createState() => _LevelUpScreenState();
}

Future<void> showLevelUpCelebration(
  BuildContext context, {
  required int level,
  required String petName,
}) {
  return Navigator.of(context).push(
    PageRouteBuilder(
      opaque: false,
      barrierColor: AppColors.ink.withValues(alpha: 0.35),
      transitionDuration: const Duration(milliseconds: 350),
      reverseTransitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (context, animation, secondaryAnimation) =>
          LevelUpScreen(level: level, petName: petName),
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

class _LevelUpScreenState extends State<LevelUpScreen> {
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
                            'LEVEL UP!',
                            textAlign: TextAlign.center,
                            style: AppTextStyles.labelLg.copyWith(
                              color: AppColors.terracottaDark,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.stackSm),
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
                                    child: Center(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(
                                            Icons.military_tech,
                                            size: 44,
                                            color: AppColors.mustardDark,
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Lv. ${widget.level}',
                                            style: AppTextStyles.headlineMd,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: AppSpacing.stackMd),
                          Text(
                            'You Leveled Up!',
                            textAlign: TextAlign.center,
                            style: AppTextStyles.headlineLg,
                          ),
                          const SizedBox(height: AppSpacing.stackSm),
                          Text(
                            '${widget.petName} is proud of you — keep those '
                            'habits up!',
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
