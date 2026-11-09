import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'tactile_button.dart';

/// Friendly empty state (docs/product/DESIGN.md §9): one Material icon in a tinted
/// ink-bordered circle, a heading, muted body copy, and an optional CTA.
class NoriEmptyState extends StatelessWidget {
  const NoriEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.tint = AppColors.mossLight,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.stackMd),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: tint,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.ink,
                    width: AppBorder.standard,
                  ),
                ),
                child: Icon(icon, size: 34, color: AppColors.ink),
              ),
              const SizedBox(height: AppSpacing.stackSm),
              Text(
                title,
                style: AppTextStyles.headlineLgMobile,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.unit),
              Text(
                message,
                style: AppTextStyles.bodyMd.copyWith(color: AppColors.inkMuted),
                textAlign: TextAlign.center,
              ),
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: AppSpacing.stackMd),
                TactileButton(
                  label: actionLabel!,
                  onPressed: onAction,
                  expand: false,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
