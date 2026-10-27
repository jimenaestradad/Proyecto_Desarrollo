import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:nori/theme/app_theme.dart';
import 'package:nori/widgets/confetti_ring.dart';
import 'package:nori/widgets/tactile_button.dart';

/// Pushes a full-screen celebration over the current screen with the shared
/// fade + scale entrance, so every celebration (level up, evolution) enters
/// the same way. [builder] builds the screen, normally a [CelebrationScreen].
Future<void> showCelebrationRoute(BuildContext context, WidgetBuilder builder) {
  return Navigator.of(context).push(
    PageRouteBuilder(
      opaque: false,
      barrierColor: AppColors.ink.withValues(alpha: 0.35),
      transitionDuration: const Duration(milliseconds: 350),
      reverseTransitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (context, animation, secondaryAnimation) => builder(context),
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

/// The shell both celebration screens share: a transparent route over the
/// dimmed app, a bordered card with two soft glows and a [ConfettiRing],
/// a kicker line, a glowing circle holding [badge], a headline, a message
/// and a dismiss button. [LevelUpScreen] and [EvolutionScreen] only choose
/// the words and what goes in the circle.
class CelebrationScreen extends StatelessWidget {
  const CelebrationScreen({
    super.key,
    required this.kicker,
    required this.badge,
    required this.title,
    required this.message,
  });

  /// Small all-caps line above the circle, e.g. "LEVEL UP!".
  final String kicker;

  /// What sits inside the circle, sized to its 160px diameter.
  final Widget badge;

  final String title;
  final String message;

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
                    const _Glow(
                      top: -60,
                      left: -40,
                      size: 200,
                      sigma: 40,
                      color: AppColors.mustardLight,
                    ),
                    const _Glow(
                      bottom: -70,
                      right: -50,
                      size: 220,
                      sigma: 44,
                      color: AppColors.mossLight,
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
                            kicker,
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
                                    child: badge,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: AppSpacing.stackMd),
                          Text(
                            title,
                            textAlign: TextAlign.center,
                            style: AppTextStyles.headlineLg,
                          ),
                          const SizedBox(height: AppSpacing.stackSm),
                          Text(
                            message,
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

/// A blurred colour blob peeking in from a corner of the card.
class _Glow extends StatelessWidget {
  const _Glow({
    this.top,
    this.bottom,
    this.left,
    this.right,
    required this.size,
    required this.sigma,
    required this.color,
  });

  final double? top;
  final double? bottom;
  final double? left;
  final double? right;
  final double size;
  final double sigma;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: top,
      bottom: bottom,
      left: left,
      right: right,
      child: ImageFiltered(
        imageFilter: ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
      ),
    );
  }
}
