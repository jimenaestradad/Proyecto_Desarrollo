import 'package:flutter/material.dart';
import 'package:nori/data/app_data.dart';
import 'package:nori/models/habit.dart';
import 'package:nori/models/nori_user.dart';
import 'package:nori/screens/habits/add_habit_screen.dart';
import 'package:nori/theme/app_theme.dart';
import 'package:nori/widgets/habit_tile.dart';
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

  Future<void> _toggleHabit(Habit habit, bool completed) async {
    await AppData.habits.setHabitCompleted(habit.id, completed);
    await _reloadHabits();
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
                                HabitTile(
                                  habit: habits[index],
                                  onToggle: (completed) {
                                    _toggleHabit(habits[index], completed);
                                  },
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
