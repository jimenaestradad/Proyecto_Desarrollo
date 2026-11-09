import 'package:flutter/material.dart';
import '../models/habit.dart';
import '../theme/app_theme.dart';
import 'nori_icon_badge.dart';
import 'progress_bar_pill.dart';
import 'reward_pill.dart';
import '../data/habit_local_edits.dart';

/// A single habit row: checkbox, icon badge, name/subtitle, XP reward.
/// Used by the Habits List screen and the Home dashboard's daily goal card.
class HabitTile extends StatelessWidget {
  const HabitTile({
    super.key,
    required this.habit,
    required this.onToggle,
    required this.onEdit,
    this.onQuickLog,
    this.detailed = false,
  });

  final Habit habit;
  final ValueChanged<bool> onToggle;
  final VoidCallback onEdit;

  /// Adds the reward chip and a progress bar (empty or full, for a binary
  /// habit) so the tile lines up with the other cards on the Habits tab.
  final bool detailed;

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
    // Limit habits remain loggable until claimed: being under the cap is not done logging.
    // Matches the limit card's progress gate.
    if (habit.type == HabitType.limit) return true;
    return !habit.isTargetMet;
  }

  @override
  Widget build(BuildContext context) {
    final completed = habit.isCompletedToday;
    // Same gate as _LimitCard's claim button: a limit that's already been
    // exceeded can't be marked safe (the claim would pay nothing but still
    // count the day as kept). Un-claiming stays allowed.
    final limitExceeded =
        habit.type == HabitType.limit &&
        habit.targetValue != null &&
        habit.currentValue > habit.targetValue!;
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.sm),
      onTap: completed || !limitExceeded ? () => onToggle(!completed) : null,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: completed ? AppColors.white : AppColors.linenAlt,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(color: AppColors.ink, width: AppBorder.thin),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
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
                          decoration: completed
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        habit.subtitle,
                        style: AppTextStyles.labelLg.copyWith(
                          color: AppColors.inkFaint,
                        ),
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
                if (detailed) ...[
                  Builder(
                    builder: (context) {
                      final reward = habit.claimedLocally();
                      return RewardPill(
                        xp: reward.lastAwardedXp,
                        coins: reward.lastAwardedCoins,
                      );
                    },
                  ),
                ],
                PopupMenuButton<void>(
                  tooltip: 'More options for ${habit.name}',
                  padding: EdgeInsets.zero,
                  icon: const Icon(
                    Icons.more_vert,
                    size: 18,
                    color: AppColors.inkFaint,
                  ),
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      onTap: onEdit,
                      child: const Text('Edit habit'),
                    ),
                  ],
                ),
              ],
            ),
            if (detailed) ...[
              const SizedBox(height: 10),
              ProgressBarPill(
                progress: habit.progressFraction,
                color: AppColors.moss,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Dedicated non-binary progress tap target; amounts follow [Habit.quickLogStep].
/// Uses a rounded pill to fit long labels and moss green to distinguish actions from streaks.
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

class _Checkbox extends StatefulWidget {
  const _Checkbox({required this.checked});

  final bool checked;

  @override
  State<_Checkbox> createState() => _CheckboxState();
}

class _CheckboxState extends State<_Checkbox>
    with SingleTickerProviderStateMixin {
  // A quick pop when the box gets checked, the "that counted" half of the
  // reward cue (the other half is RewardBurst).
  late final AnimationController _pop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 350),
  );

  @override
  void didUpdateWidget(_Checkbox oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.checked &&
        widget.checked &&
        !MediaQuery.disableAnimationsOf(context)) {
      _pop.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _pop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final checked = widget.checked;
    return Semantics(
      checked: checked,
      child: ScaleTransition(
        scale: TweenSequence<double>([
          TweenSequenceItem(
            tween: Tween(
              begin: 1.0,
              end: 1.28,
            ).chain(CurveTween(curve: Curves.easeOut)),
            weight: 45,
          ),
          TweenSequenceItem(
            tween: Tween(
              begin: 1.28,
              end: 1.0,
            ).chain(CurveTween(curve: Curves.easeIn)),
            weight: 55,
          ),
        ]).animate(_pop),
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
      ),
    );
  }
}
