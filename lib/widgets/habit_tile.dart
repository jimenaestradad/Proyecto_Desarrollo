import 'package:flutter/material.dart';
import '../models/habit.dart';
import '../theme/app_theme.dart';
import 'nori_icon_badge.dart';

/// A single habit row: checkbox, icon badge, name/subtitle, XP reward.
/// Used by the Habits List screen and the Home dashboard's daily goal card.
class HabitTile extends StatelessWidget {
  const HabitTile({
    super.key,
    required this.habit,
    required this.onToggle,
    required this.onEdit,
    this.onQuickLog,
  });

  final Habit habit;
  final ValueChanged<bool> onToggle;
  final VoidCallback onEdit;

  /// Partial-progress quick-log, e.g. "+250 ml" for a water habit. Only
  /// rendered (as a pill button replacing the XP badge) when non-null and
  /// the habit is non-binary and not yet claimed — see [Habit.quickLogStep]
  /// / [Habit.quickLogLabel].
  final ValueChanged<double>? onQuickLog;

  bool get _showQuickLog {
    if (onQuickLog == null ||
        habit.type == HabitType.binary ||
        habit.isCompletedToday) {
      return false;
    }
    // Limit habits' "target met" means "currently under the cap" — true
    // almost the whole time, not "done logging" — so unlike every other
    // type, hitting it shouldn't hide the quick-log button. It stays
    // available until claimed (mirrors _LimitCard's onLogProgress gate in
    // habit_progress_card.dart).
    if (habit.type == HabitType.limit) return true;
    return !habit.isTargetMet;
  }

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
            NoriIconBadge(
              icon: habit.icon,
              background: habit.color,
              size: 40,
              iconSize: 20,
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
            // No XP badge fallback when there's no quick-log button to show
            // (binary habits, or a non-binary one that's just claimed) —
            // leave the space empty rather than filling it with a number
            // that isn't actionable here.
            if (_showQuickLog)
              _QuickLogChip(
                label: habit.quickLogLabel,
                onTap: () => onQuickLog!(habit.quickLogStep),
              ),
            PopupMenuButton<void>(
              tooltip: 'More',
              padding: EdgeInsets.zero,
              icon: const Icon(
                Icons.more_vert,
                size: 18,
                color: AppColors.inkFaint,
              ),
              itemBuilder: (context) => [
                PopupMenuItem(onTap: onEdit, child: const Text('Edit Habit')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Partial-progress button replacing the XP badge for non-binary habits,
/// e.g. "+250" for a water habit — see [Habit.quickLogStep] for how the
/// amount is chosen and how a user can override it (Add/Edit Habit screen).
/// A dedicated tap target nested inside the tile's own InkWell, so tapping
/// it logs progress instead of toggling claim state.
///
/// A true pill (rounded-rect, not [CircleBorder]) — [CircleBorder] inscribes
/// an ellipse in whatever rect it's given, so a longer label like "+15
/// mins" got clipped into a flattened oval that crowded the text on both
/// sides. This stays a clean circle for short labels (min 40x40) and
/// widens gracefully for longer ones instead.
///
/// Moss green, matching the Complete/claim button's color on the Habits
/// screen — not mustard, which is the streak chip's color right next to
/// this on Home and made the two unreadable as "one's a stat, one's a
/// button" at a glance.
class _QuickLogChip extends StatelessWidget {
  const _QuickLogChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.mossLight,
      borderRadius: BorderRadius.circular(AppRadius.full),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.ink, width: AppBorder.thin),
            borderRadius: BorderRadius.circular(AppRadius.full),
          ),
          child: Text(
            label,
            maxLines: 1,
            style: AppTextStyles.labelSm.copyWith(
              color: AppColors.mossDark,
              fontWeight: FontWeight.w700,
            ),
          ),
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
    return Semantics(
      checked: checked,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          color: checked ? AppColors.moss : AppColors.white,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppColors.ink, width: AppBorder.thin),
        ),
        child: checked
            ? const Icon(Icons.check, size: 15, color: AppColors.ink)
            : null,
      ),
    );
  }
}
