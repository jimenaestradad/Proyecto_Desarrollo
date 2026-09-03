import 'package:flutter/material.dart';
import 'package:nori/data/app_data.dart';
import 'package:nori/data/habit_repository.dart';
import 'package:nori/models/habit.dart';
import 'package:nori/models/nori_user.dart';
import 'package:nori/screens/habits/add_habit_screen.dart';
import 'package:nori/theme/app_theme.dart';
import 'package:nori/widgets/habit_progress_card.dart';
import 'package:nori/widgets/progress_bar_pill.dart';
import 'package:nori/widgets/tactile_button.dart';
import 'package:nori/widgets/xp_pill.dart';

class HabitsListScreen extends StatefulWidget {
  const HabitsListScreen({super.key});

  @override
  State<HabitsListScreen> createState() => _HabitsListScreenState();
}

class _HabitsListScreenState extends State<HabitsListScreen> {
  NoriUser? _user;
  List<Habit>? _habits;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final user = await AppData.user.getCurrentUser();
    final habits = await AppData.habits.getTodayHabits();
    if (!mounted) return;
    setState(() {
      _user = user;
      _habits = habits;
    });
  }

  Future<void> _reloadHabits() async {
    final habits = await AppData.habits.getTodayHabits();
    if (!mounted) return;
    setState(() => _habits = habits);
  }

  Future<void> _reloadUser() async {
    final user = await AppData.user.getCurrentUser();
    if (!mounted) return;
    setState(() => _user = user);
  }

  Future<void> _applyReward(HabitRewardResult reward) async {
    if (reward.xpDelta == 0 && reward.coinsDelta == 0) return;
    if (reward.xpDelta != 0) await AppData.user.addXp(reward.xpDelta);
    if (reward.coinsDelta != 0) await AppData.user.addCoins(reward.coinsDelta);
    final user = await AppData.user.getCurrentUser();
    await AppData.pet.syncEvolution(user.level);
    await _reloadUser();
  }

  Future<void> _toggleBinary(Habit habit, bool completed) async {
    final reward = await AppData.habits.setHabitCompleted(habit.id, completed);
    await _applyReward(reward);
    await _reloadHabits();
  }

  Future<void> _logProgress(Habit habit, double amount) async {
    await AppData.habits.logProgress(habit.id, amount);
    await _reloadHabits();
  }

  Future<void> _claim(Habit habit) async {
    final reward = await AppData.habits.claimHabit(habit.id);
    await _applyReward(reward);
    await _reloadHabits();
  }

  Future<void> _toggleVacationMode() async {
    final user = _user;
    if (user == null) return;
    await AppData.user.setVacationMode(!user.vacationModeEnabled);
    await _reloadUser();
  }

  Future<void> _openAddHabit() async {
    final added = await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute(builder: (_) => const AddHabitScreen()));
    if (!mounted) return;
    if (added == true) await _reloadHabits();
  }

  @override
  Widget build(BuildContext context) {
    final user = _user;
    final habits = _habits;

    return Scaffold(
      body: SafeArea(
        child: user == null || habits == null
            ? const Center(child: CircularProgressIndicator())
            : LayoutBuilder(
                builder: (context, constraints) {
                  final horizontalPadding = constraints.maxWidth >= 800
                      ? AppSpacing.containerPaddingDesktop
                      : AppSpacing.containerPaddingMobile;
                  final completedCount = habits
                      .where((habit) => habit.isCompletedToday)
                      .length;
                  final completion = habits.isEmpty
                      ? 0.0
                      : completedCount / habits.length;

                  return SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      horizontalPadding,
                      AppSpacing.gutter,
                      horizontalPadding,
                      AppSpacing.stackLg,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1200),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'Nori',
                                    style: AppTextStyles.headlineMd,
                                  ),
                                ),
                                XpPill(xp: user.totalXp),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.stackLg),
                            Text(
                              "Today's Goals",
                              style: AppTextStyles.headlineLgMobile,
                            ),
                            const SizedBox(height: AppSpacing.unit),
                            Text(
                              'Keep up the good work! Your pet is happy.',
                              style: AppTextStyles.bodyMd.copyWith(
                                color: AppColors.inkFaint,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.stackMd),
                            Align(
                              alignment: Alignment.centerRight,
                              child: Text(
                                '$completedCount / ${habits.length} Completed',
                                style: AppTextStyles.labelLg.copyWith(
                                  color: AppColors.terracottaDark,
                                ),
                              ),
                            ),
                            const SizedBox(height: AppSpacing.unit),
                            ProgressBarPill(
                              progress: completion,
                              color: AppColors.terracotta,
                            ),
                            const SizedBox(height: AppSpacing.stackMd),
                            _VacationModeBanner(
                              enabled: user.vacationModeEnabled,
                              onToggle: _toggleVacationMode,
                            ),
                            const SizedBox(height: AppSpacing.stackMd),
                            if (habits.isEmpty)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: AppSpacing.stackMd,
                                ),
                                child: Text(
                                  'No habits scheduled for today.',
                                  textAlign: TextAlign.center,
                                  style: AppTextStyles.bodyMd.copyWith(
                                    color: AppColors.inkFaint,
                                  ),
                                ),
                              )
                            else
                              for (
                                var index = 0;
                                index < habits.length;
                                index++
                              ) ...[
                                HabitProgressCard(
                                  habit: habits[index],
                                  onToggleBinary: (completed) =>
                                      _toggleBinary(habits[index], completed),
                                  onLogProgress: (amount) =>
                                      _logProgress(habits[index], amount),
                                  onClaim: () => _claim(habits[index]),
                                ),
                                if (index != habits.length - 1)
                                  const SizedBox(height: AppSpacing.stackSm),
                              ],
                            const SizedBox(height: AppSpacing.stackMd),
                            TactileButton(
                              label: 'Add New Habit',
                              icon: Icons.add,
                              onPressed: _openAddHabit,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}

/// Live, functional toggle — unlike the app's [FutureFeatureBanner]
/// previews. Its effect is currently limited to persisting the flag on
/// [NoriUser]: there's no real day-rollover/streak-freeze engine yet, since
/// streaks are still just a static int (see docs/OPEN_DECISIONS.md
/// "Technical rules / edge cases" — timezone/day-rollover handling is
/// undecided).
class _VacationModeBanner extends StatelessWidget {
  const _VacationModeBanner({required this.enabled, required this.onToggle});

  final bool enabled;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.stackSm),
      decoration: BoxDecoration(
        color: AppColors.linenAlt,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AppColors.ink, width: AppBorder.thin),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.mustardLight,
              borderRadius: BorderRadius.circular(AppRadius.sm * 0.6),
              border: Border.all(color: AppColors.ink, width: AppBorder.thin),
            ),
            child: const Icon(
              Icons.beach_access,
              color: AppColors.mustardDark,
              size: 18,
            ),
          ),
          const SizedBox(width: AppSpacing.stackSm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('Vacation Mode', style: AppTextStyles.labelLg),
                    const SizedBox(width: AppSpacing.unit),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: enabled ? AppColors.mossLight : AppColors.linen,
                        borderRadius: BorderRadius.circular(AppRadius.full),
                        border: Border.all(
                          color: AppColors.ink,
                          width: AppBorder.thin,
                        ),
                      ),
                      child: Text(
                        enabled ? 'Active' : 'Inactive',
                        style: AppTextStyles.labelSm.copyWith(
                          color: enabled
                              ? AppColors.mossDark
                              : AppColors.inkMuted,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Freezes streaks safely when you take a break.',
                  style: AppTextStyles.labelSm.copyWith(
                    color: AppColors.inkFaint,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.unit),
          OutlinedButton(
            onPressed: onToggle,
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.ink, width: AppBorder.thin),
              foregroundColor: AppColors.ink,
            ),
            child: Text(enabled ? 'Disable' : 'Enable'),
          ),
        ],
      ),
    );
  }
}
