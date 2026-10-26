import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:nori/theme/app_theme.dart';
import 'package:nori/widgets/tactile_button.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned(
            left: -100,
            top: -120,
            child: ImageFiltered(
              imageFilter: ui.ImageFilter.blur(sigmaX: 48, sigmaY: 48),
              child: Container(
                width: 280,
                height: 280,
                decoration: BoxDecoration(
                  color: AppColors.mossLight.withValues(alpha: 0.65),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
          Positioned(
            right: -120,
            bottom: -100,
            child: ImageFiltered(
              imageFilter: ui.ImageFilter.blur(sigmaX: 52, sigmaY: 52),
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  color: AppColors.blush.withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.containerPaddingMobile,
                    vertical: AppSpacing.stackMd,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      // constraints.maxHeight can be 0 (or otherwise
                      // smaller than the vertical padding below) on the
                      // very first layout pass -- clamp so minHeight never
                      // goes negative, which BoxConstraints asserts on.
                      minHeight:
                          (constraints.maxHeight - (AppSpacing.stackMd * 2))
                              .clamp(0.0, double.infinity),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Column(
                          children: [
                            const _MascotPlaceholder(),
                            const SizedBox(height: AppSpacing.stackMd),
                            Text.rich(
                              TextSpan(
                                style: AppTextStyles.display,
                                children: [
                                  const TextSpan(text: 'Meet Your\n'),
                                  TextSpan(
                                    text: 'Nori',
                                    style: AppTextStyles.display.copyWith(
                                      color: AppColors.terracottaDark,
                                    ),
                                  ),
                                ],
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: AppSpacing.stackSm),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 320),
                              child: Text(
                                'Every good habit you build helps your new '
                                'friend grow. Ready to start the journey?',
                                style: AppTextStyles.bodyLg.copyWith(
                                  color: AppColors.inkFaint,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ),
                        Padding(
                          padding: const EdgeInsets.only(
                            top: AppSpacing.stackMd,
                          ),
                          child: FractionallySizedBox(
                            widthFactor: 0.8,
                            child: TactileButton(
                              label: 'Get Started',
                              icon: Icons.arrow_forward,
                              onPressed: () =>
                                  Navigator.pushNamed(context, '/signup'),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _MascotPlaceholder extends StatelessWidget {
  const _MascotPlaceholder();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 280,
      height: 280,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            left: AppSpacing.stackLg,
            right: AppSpacing.stackLg,
            bottom: AppSpacing.gutter,
            child: ImageFiltered(
              imageFilter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
              child: Container(
                height: AppSpacing.stackMd,
                decoration: BoxDecoration(
                  color: AppColors.ink.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
              ),
            ),
          ),
          Positioned(
            left: AppSpacing.stackMd,
            right: AppSpacing.stackMd,
            top: AppSpacing.unit,
            bottom: AppSpacing.stackMd,
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.mossLight,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(
                  color: AppColors.ink,
                  width: AppBorder.standard,
                ),
              ),
              padding: const EdgeInsets.all(AppSpacing.unit),
              child: Image.asset(
                'assets/images/nori_front.png',
                fit: BoxFit.contain,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
