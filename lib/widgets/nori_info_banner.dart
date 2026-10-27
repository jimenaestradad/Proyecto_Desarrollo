import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Sky-tinted, ink-bordered note with an icon and a short message: Add
/// Habit's "Adaptive XP" and "Minimum Threshold" explanations, and the
/// one-time hint cards (`OneTimeHint`). Pass [onDismiss] to add a close
/// button; without it the banner is purely informational.
class NoriInfoBanner extends StatelessWidget {
  const NoriInfoBanner({
    super.key,
    required this.message,
    required this.icon,
    this.onDismiss,
  });

  final String message;
  final IconData icon;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: AppSpacing.gutter,
        right: onDismiss == null ? AppSpacing.gutter : AppSpacing.unit / 2,
        top: onDismiss == null ? AppSpacing.stackSm : AppSpacing.unit / 2,
        bottom: onDismiss == null ? AppSpacing.stackSm : AppSpacing.unit / 2,
      ),
      decoration: BoxDecoration(
        color: AppColors.sky,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AppColors.ink, width: AppBorder.thin),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.ink, size: 20),
          const SizedBox(width: AppSpacing.stackSm),
          Expanded(
            child: Text(
              message,
              style: AppTextStyles.labelLg.copyWith(color: AppColors.ink),
            ),
          ),
          if (onDismiss != null)
            IconButton(
              tooltip: 'Dismiss',
              onPressed: onDismiss,
              icon: const Icon(Icons.close, size: 20, color: AppColors.ink),
            ),
        ],
      ),
    );
  }
}
