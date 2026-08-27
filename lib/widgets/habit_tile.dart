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
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: completed
              ? AppColors.surfaceContainer
              : AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(color: AppColors.surfaceContainerHigh),
        ),
        child: Row(
          children: [
            _Checkbox(checked: completed),
            const SizedBox(width: 16),
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: habit.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Icon(habit.icon, color: habit.color),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    habit.name,
                    style: AppTextStyles.bodyLg.copyWith(
                      color: completed
                          ? AppColors.onSurfaceVariant
                          : AppColors.onSurface,
                      decoration: completed ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(habit.subtitle, style: AppTextStyles.labelSm),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: completed
                    ? AppColors.surfaceContainerHighest
                    : AppColors.primaryFixed.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(AppRadius.sm * 0.5),
              ),
              child: Text(
                '+${habit.xpReward} XP',
                style: AppTextStyles.labelSm.copyWith(
                  color: completed ? AppColors.onSurface : AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
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
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: checked ? AppColors.primary : AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: checked ? AppColors.primary : AppColors.outlineVariant,
          width: 2,
        ),
      ),
      child: checked
          ? const Icon(Icons.check, size: 18, color: AppColors.onPrimary)
          : null,
    );
  }
}
