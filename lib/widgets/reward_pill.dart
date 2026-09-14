import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Small "+20 XP · 10" chip showing a habit/bucket-list item's reward.
class RewardPill extends StatelessWidget {
  const RewardPill({super.key, required this.xp, required this.coins});

  final int xp;
  final int coins;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.mustard,
        borderRadius: BorderRadius.circular(AppRadius.full),
        border: Border.all(color: AppColors.ink, width: AppBorder.thin),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('+$xp XP', style: AppTextStyles.labelSm.copyWith(color: AppColors.ink)),
          const SizedBox(width: 4),
          const Icon(Icons.monetization_on, size: 12, color: AppColors.mustardDark),
          const SizedBox(width: 2),
          Text('$coins', style: AppTextStyles.labelSm.copyWith(color: AppColors.ink)),
        ],
      ),
    );
  }
}
