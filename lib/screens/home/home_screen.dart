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
        shape: const CircleBorder(
          side: BorderSide(color: AppColors.ink, width: AppBorder.standard),
        ),
        backgroundColor: AppColors.terracotta,
        foregroundColor: AppColors.white,
        elevation: 0,
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
                                    iconBg: AppColors.blush,
                                    iconColor: AppColors.terracottaDark,
                                    label: 'Happiness',
                                    value: '${(completion * 100).round()}%',
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.gutter),
                                Expanded(
                                  child: _StatCard(
                                    icon: Icons.local_fire_department,
                                    iconBg: AppColors.mustardLight,
                                    iconColor: AppColors.mustardDark,
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
                                  color: AppColors.mossLight,
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.lg,
                                  ),
                                  border: Border.all(
                                    color: AppColors.ink,
                                    width: AppBorder.standard,
                                  ),
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.pets,
                                      size: isWide ? 128 : 96,
                                      color: AppColors.ink,
                                    ),
                                    const SizedBox(height: AppSpacing.unit),
                                    Text(
                                      'tap to dress up Nori',
                                      style: AppTextStyles.headlineMd.copyWith(
                                        fontSize: 13,
                                        color: AppColors.mossDark,
                                      ),
                                    ),
                                  ],
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
              Text('Nori', style: AppTextStyles.headlineMd),
              const SizedBox(height: 2),
              Row(
                children: [
                  Text(
                    'LEVEL ${user.level}',
                    style: AppTextStyles.labelSm,
                  ),
                  const SizedBox(width: AppSpacing.unit),
                  Flexible(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 104),
                      child: ProgressBarPill(
                        progress: user.levelProgress,
                        height: 8,
                        color: AppColors.moss,
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
    required this.iconBg,
    required this.iconColor,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.gutter),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AppColors.ink, width: AppBorder.standard),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: iconBg,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.ink, width: AppBorder.thin),
            ),
            alignment: Alignment.center,
            child: Icon(icon, color: iconColor, size: 16),
          ),
          const SizedBox(height: AppSpacing.unit),
          Text(label.toUpperCase(), style: AppTextStyles.labelSm),
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
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.ink, width: AppBorder.standard),
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
                        color: AppColors.inkFaint,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.unit),
              Text(
                '$completedCount / ${habits.length}',
                style: AppTextStyles.labelLg.copyWith(
                  color: AppColors.terracottaDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.stackSm),
          ProgressBarPill(progress: completion, color: AppColors.terracotta),
          const SizedBox(height: AppSpacing.stackMd),
          if (habits.isEmpty)
            Text(
              'No habits scheduled for today.',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMd.copyWith(color: AppColors.inkFaint),
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
