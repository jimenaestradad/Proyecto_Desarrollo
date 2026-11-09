import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// A tappable, ink-bordered list row: icon, label, optional trailing widget
/// (e.g. a status badge), chevron. Used for simple navigation rows on
/// Profile and Settings (e.g. "Settings", "Nori Plus") — extracted so both
/// screens share one shape instead of each redefining it.
class NoriListRow extends StatelessWidget {
  const NoriListRow({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.trailing,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Widget? trailing;

  /// Red-tinted row for actions that destroy data (Delete Account), so they
  /// don't look like every other settings row.
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final fg = destructive ? AppColors.onErrorContainer : AppColors.inkMuted;
    return Material(
      color: destructive ? AppColors.errorContainer : AppColors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        side: const BorderSide(color: AppColors.ink, width: AppBorder.thin),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.gutter),
          child: Row(
            children: [
              Icon(icon, color: fg),
              const SizedBox(width: AppSpacing.stackSm),
              Expanded(
                child: Text(
                  label,
                  style: destructive
                      ? AppTextStyles.labelLg.copyWith(color: fg)
                      : AppTextStyles.labelLg,
                ),
              ),
              if (trailing != null) ...[
                trailing!,
                const SizedBox(width: AppSpacing.unit),
              ],
              Icon(Icons.chevron_right, color: fg),
            ],
          ),
        ),
      ),
    );
  }
}
