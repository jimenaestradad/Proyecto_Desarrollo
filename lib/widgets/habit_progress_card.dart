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
    required this.onUnclaim,
    required this.onToggleBinary,
    required this.onEditHabit,
    required this.onEditProgress,
  });

  final Habit habit;
  final ValueChanged<double> onLogProgress;
  final VoidCallback onClaim;

  /// Reverses today's claim — the claim/complete button turns into this
  /// once the habit is claimed, instead of just going dead.
  final VoidCallback onUnclaim;
  final ValueChanged<bool> onToggleBinary;

  /// Opens the habit definition (name, target, schedule, ...) for editing.
  final VoidCallback onEditHabit;

  /// Sets today's logged progress to an absolute value, un-claiming first if
  /// the habit was already completed today. Powers the tap-to-edit /
  /// undo / reset-to-0 flow on the progress value.
  final Future<void> Function(double) onEditProgress;

  @override
  Widget build(BuildContext context) {
    if (habit.type == HabitType.binary) {
      return HabitTile(habit: habit, onToggle: onToggleBinary, onEdit: onEditHabit);
    }
    if (habit.type == HabitType.limit) {
      return _LimitCard(
        habit: habit,
        onLogProgress: onLogProgress,
        onClaim: onClaim,
        onUnclaim: onUnclaim,
        onEditHabit: onEditHabit,
        onEditProgress: onEditProgress,
      );
    }
    return _ProgressCard(
      habit: habit,
      onLogProgress: onLogProgress,
      onClaim: onClaim,
      onUnclaim: onUnclaim,
      onEditHabit: onEditHabit,
      onEditProgress: onEditProgress,
    );
  }
}

String _mmss(double minutes) => '${minutes.floor().toString().padLeft(2, '0')}:00';

String _formatNum(double value) =>
    value == value.roundToDouble() ? value.round().toString() : value.toString();

String _formatValue(Habit habit) {
  final target = habit.targetValue;
  if (target == null) return '';
  if (habit.type == HabitType.duration) {
    return '${_mmss(habit.currentValue)} / ${_mmss(target)}';
  }
  final unit = habit.unit ?? (habit.type == HabitType.multipleCompletion ? 'times' : '');
  return '${habit.currentValue.round()} / ${target.round()} $unit'.trim();
}

/// What Complete will actually pay right now. Claiming snaps a
/// progress-tracked habit up to its target and completes outright (see
/// [MockHabitRepository._claimValue]), so the preview is always the full
/// tier — not whatever the current partial value would earn on its own.
({int xp, int coins}) _previewReward(Habit habit) {
  final target = habit.targetValue;
  if (target == null || habit.currentValue >= target) return habit.computeReward();
  return habit.copyWith(currentValue: target).computeReward();
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
    required this.onUnclaim,
    required this.claimBackground,
    required this.claimForeground,
    required this.onEditHabit,
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

  /// Null hides the quick-log button entirely and lets the claim/undo
  /// button take the full row — used once claimed, or once the target's
  /// already met and there's nothing left to quick-log toward.
  final VoidCallback? onLogProgress;
  final String claimLabel;
  final bool claimEnabled;
  final VoidCallback onClaim;

  /// Reverses today's claim. Once [claimed] is true this replaces [onClaim]
  /// entirely — the button turns into "Undo" instead of going dead.
  final VoidCallback onUnclaim;
  final Color claimBackground;
  final Color claimForeground;
  final VoidCallback onEditHabit;

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
              PopupMenuButton<void>(
                tooltip: 'More',
                padding: EdgeInsets.zero,
                icon: const Icon(
                  Icons.more_vert,
                  size: 18,
                  color: AppColors.inkFaint,
                ),
                itemBuilder: (context) => [
                  PopupMenuItem(
                    onTap: onEditHabit,
                    child: const Text('Edit Habit'),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          progress,
          const SizedBox(height: 10),
          Row(
            children: [
              if (onLogProgress != null) ...[
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
              ],
              Expanded(
                child: FilledButton(
                  onPressed: claimed
                      ? onUnclaim
                      : (claimEnabled ? onClaim : null),
                  style: FilledButton.styleFrom(
                    backgroundColor: claimed
                        ? AppColors.linenAlt
                        : (claimEnabled ? claimBackground : AppColors.linenAlt),
                    foregroundColor: claimed
                        ? AppColors.inkMuted
                        : (claimEnabled ? claimForeground : AppColors.inkMuted),
                    side: const BorderSide(
                      color: AppColors.ink,
                      width: AppBorder.thin,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    textStyle: AppTextStyles.labelLg,
                  ),
                  child: Text(claimed ? 'Undo' : claimLabel),
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
    required this.onUnclaim,
    required this.onEditHabit,
    required this.onEditProgress,
  });

  final Habit habit;
  final ValueChanged<double> onLogProgress;
  final VoidCallback onClaim;
  final VoidCallback onUnclaim;
  final VoidCallback onEditHabit;
  final Future<void> Function(double) onEditProgress;

  @override
  Widget build(BuildContext context) {
    final claimed = habit.isCompletedToday;
    // What Complete will actually pay — it snaps a progress-tracked habit
    // up to its target and completes outright (see
    // [MockHabitRepository._claimValue]), so this previews the full-tier
    // reward rather than whatever the current partial value would earn.
    final reward = _previewReward(habit);

    final (String chipLabel, Color chipColor, Color chipTextColor) = switch (true) {
      _ when claimed => ('Claimed', AppColors.mossLight, AppColors.mossDark),
      _ when habit.isTargetMet => ('Target Reached!', AppColors.mossLight, AppColors.mossDark),
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
          _EditableValue(
            habit: habit,
            onEditProgress: onEditProgress,
          ),
        ],
      ),
      progress: ProgressBarPill(
        progress: habit.progressFraction,
        thresholdFraction: habit.minThresholdFraction,
        color: AppColors.moss,
      ),
      quickLogLabel: habit.quickLogLabel,
      // Once the target's met there's nothing left to quick-log toward —
      // hide it so "Complete" is the one obvious next action.
      onLogProgress: (claimed || habit.isTargetMet)
          ? null
          : () => onLogProgress(habit.quickLogStep),
      claimLabel: claimed ? 'Claimed' : 'Complete',
      claimEnabled: !claimed,
      onClaim: onClaim,
      onUnclaim: onUnclaim,
      claimBackground: AppColors.moss,
      claimForeground: AppColors.ink,
      onEditHabit: onEditHabit,
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
    required this.onUnclaim,
    required this.onEditHabit,
    required this.onEditProgress,
  });

  final Habit habit;
  final ValueChanged<double> onLogProgress;
  final VoidCallback onClaim;
  final VoidCallback onUnclaim;
  final VoidCallback onEditHabit;
  final Future<void> Function(double) onEditProgress;

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
      trailing: _EditableValue(habit: habit, onEditProgress: onEditProgress),
      progress: ProgressBarPill(progress: ratio, color: barColor),
      quickLogLabel: habit.quickLogLabel,
      onLogProgress: claimed ? null : () => onLogProgress(habit.quickLogStep),
      claimLabel: claimed
          ? 'Marked Safe'
          : (exceeded ? 'Limit Exceeded' : 'Mark Day Safe'),
      claimEnabled: !claimed && !exceeded,
      onClaim: onClaim,
      onUnclaim: onUnclaim,
      claimBackground: AppColors.moss,
      claimForeground: AppColors.ink,
      onEditHabit: onEditHabit,
    );
  }
}

/// The `750 / 1000 ml`-style value, tappable to open [_EditProgressDialog] —
/// covers undo / manual correction / reset-to-0 for today's logged amount.
class _EditableValue extends StatelessWidget {
  const _EditableValue({required this.habit, required this.onEditProgress});

  final Habit habit;
  final Future<void> Function(double) onEditProgress;

  Future<void> _openDialog(BuildContext context) async {
    final newValue = await showDialog<double>(
      context: context,
      builder: (_) => _EditProgressDialog(habit: habit),
    );
    if (newValue == null) return;
    await onEditProgress(newValue);
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.sm * 0.5),
      onTap: () => _openDialog(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
        // Dashed underline (not an icon) hints it's tappable without
        // looking like the same "edit" action as the habit-level menu.
        child: Text(
          _formatValue(habit),
          style: AppTextStyles.labelSm.copyWith(
            fontWeight: FontWeight.w700,
            color: AppColors.ink,
            decoration: TextDecoration.underline,
            decorationStyle: TextDecorationStyle.dashed,
            decorationColor: AppColors.inkFaint,
          ),
        ),
      ),
    );
  }
}

class _EditProgressDialog extends StatefulWidget {
  const _EditProgressDialog({required this.habit});

  final Habit habit;

  @override
  State<_EditProgressDialog> createState() => _EditProgressDialogState();
}

class _EditProgressDialogState extends State<_EditProgressDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: _formatNum(widget.habit.currentValue),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final habit = widget.habit;
    final unit = habit.type == HabitType.duration ? 'min' : (habit.unit ?? '');

    return AlertDialog(
      backgroundColor: AppColors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        side: const BorderSide(color: AppColors.ink, width: AppBorder.thin),
      ),
      title: const Text('Edit Today\'s Progress'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (habit.isCompletedToday)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.stackSm),
              child: Text(
                'Already claimed today — saving will un-claim it and reverse the XP/coins you earned.',
                style: AppTextStyles.labelSm.copyWith(
                  color: AppColors.terracottaDark,
                ),
              ),
            ),
          TextField(
            controller: _controller,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: AppTextStyles.bodyLg,
            decoration: InputDecoration(
              suffixText: unit.isEmpty ? null : unit,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.sm),
                borderSide: const BorderSide(
                  color: AppColors.ink,
                  width: AppBorder.thin,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.stackSm),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => setState(() => _controller.text = '0'),
              icon: const Icon(Icons.restart_alt, size: 18),
              label: const Text('Reset to 0'),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.moss,
            foregroundColor: AppColors.ink,
          ),
          onPressed: () {
            final value = double.tryParse(_controller.text.trim());
            Navigator.pop(context, value ?? 0.0);
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
