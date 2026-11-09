import 'package:flutter/material.dart';
import '../models/habit.dart';
import '../theme/app_theme.dart';
import '../utils/formatting.dart';
import 'habit_tile.dart';
import 'nori_card.dart';
import 'nori_icon_badge.dart';
import 'progress_bar_pill.dart';
import 'reward_pill.dart';

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
      return HabitTile(
        habit: habit,
        onToggle: onToggleBinary,
        onEdit: onEditHabit,
        detailed: true,
      );
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

/// The category ("Health"), or the tracking type when the habit has none.
/// The type name used to lead every card ("Quantity · Health"), which is
/// internal vocabulary; the target line already shows how it is measured.
String _subtitle(Habit habit) =>
    habit.subtitle.trim().isNotEmpty ? habit.subtitle : habit.type.label;

/// `1.5` → `'01:30'`. Seconds used to be hardcoded to `:00`, so any
/// fractional-minute entry (the form allows decimals) displayed wrong.
String _mmss(double minutes) {
  final totalSeconds = (minutes * 60).round();
  final mm = (totalSeconds ~/ 60).toString().padLeft(2, '0');
  final ss = (totalSeconds % 60).toString().padLeft(2, '0');
  return '$mm:$ss';
}

String _formatValue(Habit habit) {
  final target = habit.targetValue;
  if (target == null) return '';
  if (habit.type == HabitType.duration) {
    return '${_mmss(habit.currentValue)} / ${_mmss(target)}';
  }
  final unit =
      habit.unit ?? (habit.type == HabitType.multipleCompletion ? 'times' : '');
  // Fractions stay visible: 0.4 / 1 must not read as 0 / 1.
  String whole(double v) => formatTrimmedNumber((v * 100).round() / 100);
  return '${whole(habit.currentValue)} / ${whole(target)} $unit'.trim();
}

/// What Complete will actually pay right now. Claiming snaps a
/// progress-tracked habit up to its target and completes outright (see
/// [MockHabitRepository._claimValue]), so the preview is always the full
/// tier — not whatever the current partial value would earn on its own.
({int xp, int coins}) _previewReward(Habit habit) {
  // Only a legacy day, un-claimed before 2026-11-08, still holds its payout:
  // show that rather than promising a second one.
  if (habit.rewardPaid) {
    return (xp: habit.lastAwardedXp, coins: habit.lastAwardedCoins);
  }
  final target = habit.targetValue;
  if (target == null || habit.currentValue >= target) {
    return habit.computeReward();
  }
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
    required this.reward,
    required this.value,
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
    required this.onEditProgress,
  });

  final bool claimed;
  final IconData icon;
  final Color iconBg;
  final String title;
  final Widget chip;
  final String subtitle;

  /// Top-right pill showing what Complete pays; null for cards that have none.
  final Widget? reward;

  /// The tappable `750 / 1000 ml` value, shown opposite the status [chip].
  final Widget value;
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

  /// The ⋮ menu's "Edit today's progress": the same dialog the tappable
  /// number opens.
  final VoidCallback onEditProgress;

  @override
  Widget build(BuildContext context) {
    return NoriCard(
      padding: const EdgeInsets.all(14),
      color: claimed ? AppColors.white : AppColors.linenAlt,
      borderWidth: AppBorder.thin,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              NoriIconBadge(
                icon: icon,
                background: iconBg,
                size: 40,
                iconSize: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodyMd.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    // Category sits straight under the title; the status chip
                    // used to wrap into the title line and push it sideways.
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.labelLg.copyWith(
                        color: AppColors.inkMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ?reward,
              PopupMenuButton<void>(
                tooltip: 'More options for $title',
                padding: EdgeInsets.zero,
                icon: const Icon(
                  Icons.more_vert,
                  size: 18,
                  color: AppColors.inkFaint,
                ),
                itemBuilder: (context) => [
                  PopupMenuItem(
                    onTap: onEditHabit,
                    child: const Text('Edit habit'),
                  ),
                  PopupMenuItem(
                    onTap: onEditProgress,
                    child: const Text("Edit today's progress"),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          progress,
          const SizedBox(height: 8),
          Row(children: [chip, const Spacer(), value]),
          const SizedBox(height: 12),
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
                      minimumSize: const Size(0, 48),
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
                    minimumSize: const Size(0, 48),
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
  const _Chip({
    required this.label,
    required this.color,
    required this.textColor,
  });

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
      child: Text(
        label,
        style: AppTextStyles.labelSm.copyWith(color: textColor),
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

    final (
      String chipLabel,
      Color chipColor,
      Color chipTextColor,
    ) = switch (true) {
      _ when claimed => ('Claimed', AppColors.mossLight, AppColors.mossDark),
      _ when habit.isTargetMet => (
        'Target reached!',
        AppColors.mossLight,
        AppColors.mossDark,
      ),
      _ when habit.currentValue <= 0 => (
        'Not started',
        AppColors.linen,
        AppColors.inkFaint,
      ),
      _ => ('In progress', AppColors.linen, AppColors.inkFaint),
    };

    return _CardShell(
      claimed: claimed,
      icon: habit.icon,
      iconBg: habit.color,
      title: habit.name,
      chip: _Chip(label: chipLabel, color: chipColor, textColor: chipTextColor),
      subtitle: _subtitle(habit),
      reward: RewardPill(xp: reward.xp, coins: reward.coins),
      value: _EditableValue(habit: habit, onEditProgress: onEditProgress),
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
      claimBackground: AppColors.mossDark,
      claimForeground: AppColors.white,
      onEditHabit: onEditHabit,
      onEditProgress: () => _editProgress(context, habit, onEditProgress),
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

    final (
      String chipLabel,
      Color chipColor,
      Color chipTextColor,
    ) = switch (true) {
      _ when claimed => (
        'Stayed under',
        AppColors.mossLight,
        AppColors.mossDark,
      ),
      _ when exceeded => (
        'Limit exceeded',
        AppColors.blush,
        AppColors.terracottaDark,
      ),
      _ => ('Within limit', AppColors.mossLight, AppColors.mossDark),
    };

    return _CardShell(
      claimed: claimed,
      icon: habit.icon,
      iconBg: habit.color,
      title: habit.name,
      chip: _Chip(label: chipLabel, color: chipColor, textColor: chipTextColor),
      subtitle: _subtitle(habit),
      reward: null,
      value: _EditableValue(habit: habit, onEditProgress: onEditProgress),
      progress: ProgressBarPill(progress: ratio, color: barColor),
      quickLogLabel: habit.quickLogLabel,
      onLogProgress: claimed ? null : () => onLogProgress(habit.quickLogStep),
      claimLabel: claimed
          ? 'Stayed under'
          : (exceeded ? 'Limit exceeded' : 'I stayed under'),
      claimEnabled: !claimed && !exceeded,
      onClaim: onClaim,
      onUnclaim: onUnclaim,
      claimBackground: AppColors.mossDark,
      claimForeground: AppColors.white,
      onEditHabit: onEditHabit,
      onEditProgress: () => _editProgress(context, habit, onEditProgress),
    );
  }
}

/// The `750 / 1000 ml`-style value, tappable to open [_EditProgressDialog] —
/// covers undo / manual correction / reset-to-0 for today's logged amount.
/// Asks for today's value in [_EditProgressDialog] and hands it to
/// [onEditProgress]. Shared by the tappable number and the ⋮ menu item.
Future<void> _editProgress(
  BuildContext context,
  Habit habit,
  Future<void> Function(double) onEditProgress,
) async {
  final newValue = await showDialog<double>(
    context: context,
    builder: (_) => _EditProgressDialog(habit: habit),
  );
  if (newValue == null) return;
  await onEditProgress(newValue);
}

class _EditableValue extends StatelessWidget {
  const _EditableValue({required this.habit, required this.onEditProgress});

  final Habit habit;
  final Future<void> Function(double) onEditProgress;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.sm * 0.5),
      onTap: () => _editProgress(context, habit, onEditProgress),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
        // Dashed underline (not an icon) hints it's tappable without
        // looking like the same "edit" action as the habit-level menu.
        child: Text(
          _formatValue(habit),
          style: AppTextStyles.labelLg.copyWith(
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
    text: formatTrimmedNumber(widget.habit.currentValue),
  );
  String? _error;

  /// Pops with the typed value, or flags the field — an unparseable entry
  /// used to save as 0, silently resetting (and un-claiming) the day.
  void _save() {
    final value = double.tryParse(_controller.text.trim());
    if (value == null || !value.isFinite || value < 0) {
      setState(() => _error = 'Enter a number, 0 or more.');
      return;
    }
    Navigator.pop(context, value);
  }

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
      title: const Text('Edit today\'s progress'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (habit.isCompletedToday)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.stackSm),
              child: Text(
                'Already claimed — saving will un-claim it. The XP/coins it paid stay yours.',
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
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
            decoration: InputDecoration(
              suffixText: unit.isEmpty ? null : unit,
              errorText: _error,
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
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}
