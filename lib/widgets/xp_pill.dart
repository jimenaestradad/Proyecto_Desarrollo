import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../utils/formatting.dart';

/// The "★ 1,250 XP" pill shown in most top app bars.
class XpPill extends StatelessWidget {
  const XpPill({super.key, required this.xp, this.compact = false});

  final int xp;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final formatted = formatThousands(xp);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 14,
        vertical: compact ? 4 : 7,
      ),
      decoration: BoxDecoration(
        color: AppColors.mustard,
        borderRadius: BorderRadius.circular(AppRadius.full),
        border: Border.all(color: AppColors.ink, width: AppBorder.thin),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.star, size: compact ? 14 : 18, color: AppColors.ink),
          const SizedBox(width: 4),
          Text(
            '$formatted XP',
            style: (compact ? AppTextStyles.labelSm : AppTextStyles.labelLg)
                .copyWith(color: AppColors.ink),
          ),
        ],
      ),
    );
  }
}
