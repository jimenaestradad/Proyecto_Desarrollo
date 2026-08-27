import 'package:flutter/material.dart';
import 'package:nori/data/app_data.dart';
import 'package:nori/models/habit.dart';
import 'package:nori/models/nori_user.dart';
import 'package:nori/screens/customization/customization_screen.dart';
import 'package:nori/screens/habits/add_habit_screen.dart';
import 'package:nori/theme/app_theme.dart';
import 'package:nori/widgets/habit_tile.dart';
import 'package:nori/widgets/nori_avatar.dart';
import 'package:nori/widgets/progress_bar_pill.dart';
import 'package:nori/widgets/xp_pill.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
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
      floatingActionButton: FloatingActionButton(
        onPressed: _openAddHabit,
        shape: const CircleBorder(),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        child: const Icon(Icons.add),
      ),
      body: SafeArea(
        child: user == null || habits == null
            ? const Center(child: CircularProgressIndicator())
            : LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth >= 800;
                  final horizontalPadding = isWide
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
                      AppSpacing.stackLg * 2,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1200),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _HomeHeader(user: user),
                            const SizedBox(height: AppSpacing.stackMd),
                            Row(
                              children: [
                                Expanded(
                                  child: _StatCard(
                                    icon: Icons.favorite,
                                    iconColor: AppColors.error,
                                    label: 'Happiness',
                                    value: '${(completion * 100).round()}%',
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.gutter),
                                Expanded(
                                  child: _StatCard(
                                    icon: Icons.local_fire_department,
                                    iconColor: AppColors.tertiary,
                                    label: 'Streak',
                                    value: '${user.currentStreak} days',
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.stackMd),
                            InkWell(
                              borderRadius: BorderRadius.circular(AppRadius.lg),
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const CustomizationScreen(),
                                ),
                              ),
                              child: Container(
                                height: isWide ? 360 : 260,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: AppColors.primaryFixed,
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.lg,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.primary.withValues(
                                        alpha: 0.12,
                                      ),
                                      blurRadius: 28,
                                      offset: const Offset(0, 12),
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  Icons.pets,
                                  size: isWide ? 128 : 96,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                            const SizedBox(height: AppSpacing.stackMd),
                            _TodayGoalCard(
                              habits: habits,
                              completedCount: completedCount,
                              completion: completion,
                              onToggle: _toggleHabit,
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

class _HomeHeader extends StatelessWidget {
  const _HomeHeader({required this.user});

  final NoriUser user;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        NoriAvatar(imageUrl: user.avatarUrl, size: 48),
        const SizedBox(width: AppSpacing.stackSm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Nori',
                style: AppTextStyles.headlineMd.copyWith(
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Text('Lvl ${user.level}', style: AppTextStyles.labelSm),
                  const SizedBox(width: AppSpacing.unit),
                  Flexible(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 104),
                      child: ProgressBarPill(
                        progress: user.levelProgress,
                        height: 6,
                        color: AppColors.secondary,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.unit),
        XpPill(xp: user.totalXp),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.gutter),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AppColors.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: AppColors.onSurface.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 28),
          const SizedBox(height: AppSpacing.unit),
          Text(label, style: AppTextStyles.labelSm),
          const SizedBox(height: 2),
          Text(value, style: AppTextStyles.headlineMd),
        ],
      ),
    );
  }
}

class _TodayGoalCard extends StatelessWidget {
  const _TodayGoalCard({
    required this.habits,
    required this.completedCount,
    required this.completion,
    required this.onToggle,
  });

  final List<Habit> habits;
  final int completedCount;
  final double completion;
  final Future<void> Function(Habit habit, bool completed) onToggle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.containerPaddingMobile),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.surfaceContainerHigh),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Today's Goal", style: AppTextStyles.headlineMd),
                    const SizedBox(height: 2),
                    Text(
                      'Keep the streak alive!',
                      style: AppTextStyles.bodyMd.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.unit),
              Text(
                '$completedCount / ${habits.length}',
                style: AppTextStyles.labelLg.copyWith(color: AppColors.primary),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.stackSm),
          ProgressBarPill(progress: completion),
          const SizedBox(height: AppSpacing.stackMd),
          if (habits.isEmpty)
            Text(
              'No habits scheduled for today.',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMd.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            )
          else
            for (var index = 0; index < habits.length; index++) ...[
              HabitTile(
                habit: habits[index],
                onToggle: (completed) {
                  onToggle(habits[index], completed);
                },
              ),
              if (index != habits.length - 1)
                const SizedBox(height: AppSpacing.stackSm),
            ],
        ],
      ),
    );
  }
}
