import 'package:flutter/material.dart';
import '../models/habit.dart';
import '../theme/app_theme.dart';

/// A single habit row: checkbox, icon badge, name/subtitle, XP reward.
/// Used by the Habits List screen and the Home dashboard's daily goal card.
class HabitTile extends StatelessWidget {
  const HabitTile({super.key, required this.habit, required this.onToggle});

  final Habit habit;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    final completed = habit.isCompletedToday;
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.sm),
      onTap: () => onToggle(!completed),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: completed ? AppColors.white : AppColors.linenAlt,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(color: AppColors.ink, width: AppBorder.thin),
        ),
        child: Row(
          children: [
            _Checkbox(checked: completed),
            const SizedBox(width: 12),
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: habit.color,
                borderRadius: BorderRadius.circular(AppRadius.sm * 0.75),
                border: Border.all(color: AppColors.ink, width: AppBorder.thin),
              ),
              child: Icon(habit.icon, color: AppColors.ink, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    habit.name,
                    style: AppTextStyles.bodyMd.copyWith(
                      fontWeight: FontWeight.w700,
                      color: completed ? AppColors.inkFaint : AppColors.ink,
                      decoration: completed ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    habit.subtitle,
                    style: AppTextStyles.labelSm.copyWith(color: AppColors.inkFaint),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '+${habit.xpReward}',
              style: AppTextStyles.labelSm.copyWith(
                color: completed ? AppColors.inkFaint : AppColors.terracottaDark,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Checkbox extends StatelessWidget {
  const _Checkbox({required this.checked});

  final bool checked;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: checked ? AppColors.moss : AppColors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.ink, width: AppBorder.thin),
      ),
      child: checked
          ? const Icon(Icons.check, size: 15, color: AppColors.white)
          : null,
    );
  }
}
