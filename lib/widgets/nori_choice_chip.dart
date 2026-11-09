import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Selectable pill for filters and single/multi-choice rows (feed filters,
/// leaderboard scope, wizard options). Selected = mossLight fill with the
/// heavier ink border, matching how choice tiles show selection elsewhere
/// (docs/product/DESIGN.md §4).
class NoriChoiceChip extends StatelessWidget {
  const NoriChoiceChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? AppColors.mossLight : AppColors.white,
            borderRadius: BorderRadius.circular(AppRadius.full),
            border: Border.all(
              color: AppColors.ink,
              width: selected ? AppBorder.standard : AppBorder.thin,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 16,
                  color: selected ? AppColors.mossDark : AppColors.inkMuted,
                ),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: AppTextStyles.labelLg.copyWith(
                  color: selected ? AppColors.ink : AppColors.inkMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
