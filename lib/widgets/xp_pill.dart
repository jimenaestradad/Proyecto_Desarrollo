import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../utils/formatting.dart';
import 'syncing_icon.dart';

/// The "★ 1,250 XP" pill shown in most top app bars.
class XpPill extends StatelessWidget {
  const XpPill({
    super.key,
    required this.xp,
    this.compact = false,
    this.syncing = false,
  });

  final int xp;
  final bool compact;

  /// A claim is being confirmed, so [xp] is about to change.
  final bool syncing;

  @override
  Widget build(BuildContext context) {
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
          SyncingIcon(
            icon: Icons.star,
            size: compact ? 14 : 18,
            color: AppColors.ink,
            syncing: syncing,
          ),
          const SizedBox(width: 4),
          // Counts up to a new total instead of jumping, so a claim's XP
          // visibly lands in the pill. Rests at exactly [xp].
          TweenAnimationBuilder<int>(
            tween: IntTween(begin: xp, end: xp),
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeOut,
            builder: (context, value, _) => Text(
              '${formatThousands(value)} XP',
              style: (compact ? AppTextStyles.labelSm : AppTextStyles.labelLg)
                  .copyWith(color: AppColors.ink),
            ),
          ),
        ],
      ),
    );
  }
}
