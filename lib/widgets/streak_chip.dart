import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Small "12d" flame badge for the current streak — paired with the XP pill
/// in screen headers (Home, Habits, Calendar).
class StreakChip extends StatelessWidget {
  const StreakChip({super.key, required this.streak});

  final int streak;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.mustardLight,
        borderRadius: BorderRadius.circular(AppRadius.full),
        border: Border.all(color: AppColors.ink, width: AppBorder.thin),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.local_fire_department,
            size: 14,
            color: AppColors.mustardDark,
          ),
          const SizedBox(width: 2),
          Text(
            '${streak}d',
            style: AppTextStyles.labelSm.copyWith(color: AppColors.mustardDark),
          ),
        ],
      ),
    );
  }
}
