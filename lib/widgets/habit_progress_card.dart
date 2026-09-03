import 'package:flutter/material.dart';
import '../models/habit.dart';
import '../theme/app_theme.dart';
import 'habit_tile.dart';
import 'progress_bar_pill.dart';

/// Type-aware habit card for the Habits tab. Binary habits render as the
/// existing [HabitTile]; every other type gets a progress bar + quick-log +
/// claim card, with [HabitType.limit] getting its own inverted-success
/// variant (stay under, not reach).
class HabitProgressCard extends StatelessWidget {
  const HabitProgressCard({
    super.key,
    required this.habit,
    required this.onLogProgress,
    required this.onClaim,
    required this.onToggleBinary,
  });

  final Habit habit;
  final ValueChanged<double> onLogProgress;
  final VoidCallback onClaim;
  final ValueChanged<bool> onToggleBinary;

  @override
  Widget build(BuildContext context) {
    if (habit.type == HabitType.binary) {
      return HabitTile(habit: habit, onToggle: onToggleBinary);
    }
    if (habit.type == HabitType.limit) {
      return _LimitCard(
        habit: habit,
        onLogProgress: onLogProgress,
        onClaim: onClaim,
      );
    }
    return _ProgressCard(
      habit: habit,
      onLogProgress: onLogProgress,
      onClaim: onClaim,
    );
  }
}

String _mmss(double minutes) => '${minutes.floor().toString().padLeft(2, '0')}:00';

String _formatValue(Habit habit) {
  final target = habit.targetValue;
  if (target == null) return '';
  if (habit.type == HabitType.duration) {
    return '${_mmss(habit.currentValue)} / ${_mmss(target)}';
  }
  final unit = habit.unit ?? (habit.type == HabitType.multipleCompletion ? 'times' : '');
  return '${habit.currentValue.round()} / ${target.round()} $unit'.trim();
}

double _quickLogAmount(Habit habit) {
  switch (habit.type) {
    case HabitType.duration:
      return 5;
    case HabitType.multipleCompletion:
      return 1;
    default:
      final target = habit.targetValue ?? 0;
      return (target * 0.25).clamp(1, double.infinity).roundToDouble();
  }
}

String _quickLogLabel(Habit habit) {
  final amount = _quickLogAmount(habit);
  switch (habit.type) {
    case HabitType.duration:
      return '+${amount.round()}m';
    case HabitType.multipleCompletion:
      return '+${amount.round()}';
    default:
      final unit = habit.unit ?? '';
      return '+${amount.round()} $unit'.trim();
  }
}

class _CardShell extends StatelessWidget {
  const _CardShell({
    required this.claimed,
    required this.icon,
    required this.iconBg,
    required this.title,
    required this.chip,
    required this.subtitle,
    required this.trailing,
    required this.progress,
    required this.quickLogLabel,
    required this.onLogProgress,
    required this.claimLabel,
    required this.claimEnabled,
    required this.onClaim,
    required this.claimBackground,
    required this.claimForeground,
  });

  final bool claimed;
  final IconData icon;
  final Color iconBg;
  final String title;
  final Widget chip;
  final String subtitle;
  final Widget trailing;
  final Widget progress;
  final String quickLogLabel;
  final VoidCallback? onLogProgress;
  final String claimLabel;
  final bool claimEnabled;
  final VoidCallback onClaim;
  final Color claimBackground;
  final Color claimForeground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: claimed ? AppColors.white : AppColors.linenAlt,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AppColors.ink, width: AppBorder.thin),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(AppRadius.sm * 0.75),
                  border: Border.all(color: AppColors.ink, width: AppBorder.thin),
                ),
                child: Icon(icon, color: AppColors.ink, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        Text(
                          title,
                          style: AppTextStyles.bodyMd.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        chip,
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: AppTextStyles.labelSm.copyWith(
                        color: AppColors.inkFaint,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              trailing,
            ],
          ),
          const SizedBox(height: 10),
          progress,
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onLogProgress,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(
                      color: AppColors.ink,
                      width: AppBorder.thin,
                    ),
                    foregroundColor: AppColors.ink,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  child: Text(quickLogLabel, style: AppTextStyles.labelLg),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  onPressed: claimEnabled ? onClaim : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: claimEnabled
                        ? claimBackground
                        : AppColors.linenAlt,
                    foregroundColor: claimEnabled
                        ? claimForeground
                        : AppColors.inkMuted,
                    side: const BorderSide(
                      color: AppColors.ink,
                      width: AppBorder.thin,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    textStyle: AppTextStyles.labelLg,
                  ),
                  child: Text(claimLabel),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.color, required this.textColor});

  final String label;
  final Color color;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(AppRadius.full),
        border: Border.all(color: AppColors.ink, width: AppBorder.thin),
      ),
      child: Text(label, style: AppTextStyles.labelSm.copyWith(color: textColor)),
    );
  }
}

class _RewardPill extends StatelessWidget {
  const _RewardPill({required this.xp, required this.coins});

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

/// Quantity / Duration / Cumulative / MultipleCompletion — "reach a target",
/// with an optional partial-credit minimum threshold.
class _ProgressCard extends StatelessWidget {
  const _ProgressCard({
    required this.habit,
    required this.onLogProgress,
    required this.onClaim,
  });

  final Habit habit;
  final ValueChanged<double> onLogProgress;
  final VoidCallback onClaim;

  @override
  Widget build(BuildContext context) {
    final claimed = habit.isCompletedToday;
    final reward = habit.computeReward();

    final (String chipLabel, Color chipColor, Color chipTextColor) = switch (true) {
      _ when claimed => ('Claimed', AppColors.mossLight, AppColors.mossDark),
      _ when habit.isTargetMet => ('Target Reached!', AppColors.mossLight, AppColors.mossDark),
      _ when habit.isMinMet => ('Min. Reached (75% XP)', AppColors.mustardLight, AppColors.mustardDark),
      _ => ('In Progress', AppColors.linen, AppColors.inkFaint),
    };

    return _CardShell(
      claimed: claimed,
      icon: habit.icon,
      iconBg: habit.color,
      title: habit.name,
      chip: _Chip(label: chipLabel, color: chipColor, textColor: chipTextColor),
      subtitle: '${habit.type.label} · ${habit.subtitle}',
      trailing: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _RewardPill(xp: reward.xp, coins: reward.coins),
          const SizedBox(height: 4),
          Text(
            _formatValue(habit),
            style: AppTextStyles.labelSm.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
            ),
          ),
        ],
      ),
      progress: ProgressBarPill(
        progress: habit.progressFraction,
        thresholdFraction: habit.minThresholdFraction,
        color: AppColors.moss,
      ),
      quickLogLabel: _quickLogLabel(habit),
      onLogProgress: claimed ? null : () => onLogProgress(_quickLogAmount(habit)),
      claimLabel: claimed ? 'Claimed' : 'Complete',
      claimEnabled: !claimed,
      onClaim: onClaim,
      claimBackground: AppColors.moss,
      claimForeground: AppColors.white,
    );
  }
}

/// Limit/Negative — "stay under a max". Success is inverted: the bar warns
/// as it climbs toward the target instead of celebrating on approach.
class _LimitCard extends StatelessWidget {
  const _LimitCard({
    required this.habit,
    required this.onLogProgress,
    required this.onClaim,
  });

  final Habit habit;
  final ValueChanged<double> onLogProgress;
  final VoidCallback onClaim;

  @override
  Widget build(BuildContext context) {
    final claimed = habit.isCompletedToday;
    final target = habit.targetValue ?? 0;
    final ratio = target == 0 ? 0.0 : habit.currentValue / target;
    final exceeded = habit.currentValue > target;

    final barColor = ratio < 0.7
        ? AppColors.moss
        : (exceeded ? AppColors.terracottaDark : AppColors.mustard);

    final (String chipLabel, Color chipColor, Color chipTextColor) = switch (true) {
      _ when claimed => ('Marked Safe', AppColors.mossLight, AppColors.mossDark),
      _ when exceeded => ('Limit Exceeded', AppColors.blush, AppColors.terracottaDark),
      _ => ('Within Limit', AppColors.mossLight, AppColors.mossDark),
    };

    return _CardShell(
      claimed: claimed,
      icon: habit.icon,
      iconBg: habit.color,
      title: habit.name,
      chip: _Chip(label: chipLabel, color: chipColor, textColor: chipTextColor),
      subtitle: '${habit.type.label} · ${habit.subtitle}',
      trailing: Text(
        _formatValue(habit),
        style: AppTextStyles.labelSm.copyWith(
          fontWeight: FontWeight.w700,
          color: AppColors.ink,
        ),
      ),
      progress: ProgressBarPill(progress: ratio, color: barColor),
      quickLogLabel: _quickLogLabel(habit),
      onLogProgress: claimed ? null : () => onLogProgress(_quickLogAmount(habit)),
      claimLabel: claimed
          ? 'Marked Safe'
          : (exceeded ? 'Limit Exceeded' : 'Mark Day Safe'),
      claimEnabled: !claimed && !exceeded,
      onClaim: onClaim,
      claimBackground: AppColors.moss,
      claimForeground: AppColors.white,
    );
  }
}
