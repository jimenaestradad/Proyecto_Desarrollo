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
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white,
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
              Icon(icon, color: AppColors.inkMuted),
              const SizedBox(width: AppSpacing.stackSm),
              Expanded(child: Text(label, style: AppTextStyles.labelLg)),
              if (trailing != null) ...[
                trailing!,
                const SizedBox(width: AppSpacing.unit),
              ],
              const Icon(Icons.chevron_right, color: AppColors.inkMuted),
            ],
          ),
        ),
      ),
    );
  }
}
