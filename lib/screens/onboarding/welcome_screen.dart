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
                  color: AppColors.primaryFixed.withValues(alpha: 0.65),
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
                  color: AppColors.secondaryContainer.withValues(alpha: 0.3),
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
                      minHeight:
                          constraints.maxHeight - (AppSpacing.stackMd * 2),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const SizedBox(height: AppSpacing.stackMd),
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
                                      color: AppColors.primary,
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
                                  color: AppColors.onSurfaceVariant,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ),
                        Padding(
                          padding: const EdgeInsets.only(
                            top: AppSpacing.stackLg,
                          ),
                          child: TactileButton(
                            label: 'Get Started',
                            icon: Icons.arrow_forward,
                            onPressed: () =>
                                Navigator.pushNamed(context, '/signup'),
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
                  color: AppColors.surfaceDim.withValues(alpha: 0.65),
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
                color: AppColors.primaryFixed,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(
                  color: AppColors.surfaceContainerLowest.withValues(
                    alpha: 0.7,
                  ),
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.onPrimaryFixed.withValues(alpha: 0.12),
                    blurRadius: AppSpacing.stackMd,
                    offset: const Offset(0, AppSpacing.stackSm),
                  ),
                ],
              ),
              child: const Icon(
                Icons.pets,
                size: 104,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
