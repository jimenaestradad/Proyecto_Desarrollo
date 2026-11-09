import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Full-width pill tab switcher ("Friends | Requests", "Active | Invites |
/// Past"). [badges] maps a segment index to a small count bubble.
class NoriSegmentedControl extends StatelessWidget {
  const NoriSegmentedControl({
    super.key,
    required this.labels,
    required this.selectedIndex,
    required this.onChanged,
    this.badges = const {},
  });

  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onChanged;
  final Map<int, int> badges;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.linenAlt,
        borderRadius: BorderRadius.circular(AppRadius.full),
        border: Border.all(color: AppColors.ink, width: AppBorder.thin),
      ),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: Semantics(
                button: true,
                selected: i == selectedIndex,
                label: labels[i],
                child: GestureDetector(
                  onTap: () => onChanged(i),
                  behavior: HitTestBehavior.opaque,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: i == selectedIndex
                          ? AppColors.white
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(AppRadius.full),
                      border: i == selectedIndex
                          ? Border.all(
                              color: AppColors.ink,
                              width: AppBorder.thin,
                            )
                          : null,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Flexible(
                          child: Text(
                            labels[i],
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.labelLg.copyWith(
                              color: i == selectedIndex
                                  ? AppColors.ink
                                  : AppColors.inkMuted,
                            ),
                          ),
                        ),
                        if ((badges[i] ?? 0) > 0) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.terracotta,
                              borderRadius: BorderRadius.circular(
                                AppRadius.full,
                              ),
                              border: Border.all(
                                color: AppColors.ink,
                                width: AppBorder.thin,
                              ),
                            ),
                            child: Text(
                              '${badges[i]}',
                              style: AppTextStyles.labelSm.copyWith(
                                color: AppColors.ink,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
