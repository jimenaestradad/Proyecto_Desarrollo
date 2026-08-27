import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Flags a screen that only exists as a visual preview — the mockup has a
/// design for it, but the underlying product decision (economy, social,
/// payments — see docs/OPEN_DECISIONS.md) hasn't been made, so nothing on
/// the screen is wired to real data or persists anything.
class FutureFeatureBanner extends StatelessWidget {
  const FutureFeatureBanner({
    super.key,
    this.message = "Preview only — this feature isn't built yet.",
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.gutter,
        vertical: AppSpacing.stackSm,
      ),
      decoration: BoxDecoration(
        color: AppColors.tertiaryFixed,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.rocket_launch,
            color: AppColors.onTertiaryFixedVariant,
            size: 20,
          ),
          const SizedBox(width: AppSpacing.stackSm),
          Expanded(
            child: Text(
              message,
              style: AppTextStyles.labelLg.copyWith(
                color: AppColors.onTertiaryFixedVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Small "Soon" chip for entry points (nav rows, cards) that lead to a
/// future-feature screen.
class SoonBadge extends StatelessWidget {
  const SoonBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.tertiaryFixed,
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Text(
        'Soon',
        style: AppTextStyles.labelSm.copyWith(
          color: AppColors.onTertiaryFixedVariant,
        ),
      ),
    );
  }
}
