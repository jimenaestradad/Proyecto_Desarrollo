import 'package:flutter/material.dart';
import 'package:nori/data/app_data.dart';
import 'package:nori/data/habit_repository.dart';
import 'package:nori/models/habit.dart';
import 'package:nori/models/inventory.dart';
import 'package:nori/models/nori_user.dart';
import 'package:nori/models/pet.dart';
import 'package:nori/screens/customization/customization_screen.dart';
import 'package:nori/screens/habits/add_habit_screen.dart';
import 'package:nori/theme/app_theme.dart';
import 'package:nori/widgets/habit_tile.dart';
import 'package:nori/widgets/nori_avatar.dart';
import 'package:nori/widgets/pet_stat_bar.dart';
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
  Pet? _pet;
  Inventory? _inventory;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final user = await AppData.user.getCurrentUser();
    final habits = await AppData.habits.getTodayHabits();
    await AppData.pet.syncEvolution(user.level);
    final pet = await AppData.pet.getPet();
    final inventory = await AppData.inventory.getInventory();
    if (!mounted) return;
    setState(() {
      _user = user;
      _habits = habits;
      _pet = pet;
      _inventory = inventory;
    });
  }

  Future<void> _reloadHabits() async {
    final habits = await AppData.habits.getTodayHabits();
    if (!mounted) return;
    setState(() => _habits = habits);
  }

  Future<void> _reloadUserAndPet() async {
    final user = await AppData.user.getCurrentUser();
    await AppData.pet.syncEvolution(user.level);
    final pet = await AppData.pet.getPet();
    if (!mounted) return;
    setState(() {
      _user = user;
      _pet = pet;
    });
  }

  Future<void> _applyReward(HabitRewardResult reward) async {
    if (reward.xpDelta == 0 && reward.coinsDelta == 0) return;
    if (reward.xpDelta != 0) await AppData.user.addXp(reward.xpDelta);
    if (reward.coinsDelta != 0) await AppData.user.addCoins(reward.coinsDelta);
    await _reloadUserAndPet();
  }

  Future<void> _toggleHabit(Habit habit, bool completed) async {
    final reward = await AppData.habits.setHabitCompleted(habit.id, completed);
    await _applyReward(reward);
    await _reloadHabits();
  }

  Future<void> _claimHabit(Habit habit) async {
    if (!habit.isMinMet && !habit.isTargetMet) {
      _showSnack('Log some progress on the Habits tab first.');
      return;
    }
    final reward = await AppData.habits.claimHabit(habit.id);
    await _applyReward(reward);
    await _reloadHabits();
  }

  /// The compact Today's Goal list uses [HabitTile], whose checkbox only
  /// really means "toggle" for binary habits. For every other type, a tap
  /// attempts a claim instead — there's no un-claiming from this condensed
  /// view (full per-type editing lives on the Habits tab).
  Future<void> _onHabitTileToggle(Habit habit, bool completed) async {
    if (habit.type == HabitType.binary) {
      await _toggleHabit(habit, completed);
      return;
    }
    if (!completed) return;
    await _claimHabit(habit);
  }

  Future<void> _careAction({
    required Future<bool> Function() consume,
    required Future<void> Function() act,
  }) async {
    final ok = await consume();
    if (!ok) {
      _showSnack('Out of stock — buy more in the Shop.');
      return;
    }
    await act();
    final inventory = await AppData.inventory.getInventory();
    final pet = await AppData.pet.getPet();
    if (!mounted) return;
    setState(() {
      _inventory = inventory;
      _pet = pet;
    });
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
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
    final pet = _pet;
    final inventory = _inventory;

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
        child: user == null || habits == null || pet == null || inventory == null
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
                            _EvolutionBanner(pet: pet, userLevel: user.level),
                            const SizedBox(height: AppSpacing.stackMd),
                            _PetVitalsCard(pet: pet),
                            const SizedBox(height: AppSpacing.stackMd),
                            InkWell(
                              borderRadius: BorderRadius.circular(AppRadius.lg),
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const CustomizationScreen(),
                                ),
                              ),
                              child: Container(
                                height: isWide ? 300 : 220,
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
                            _PetCareRow(
                              inventory: inventory,
                              onFeed: () => _careAction(
                                consume: AppData.inventory.consumeSnack,
                                act: AppData.pet.feed,
                              ),
                              onGroom: () => _careAction(
                                consume: AppData.inventory.consumeSoap,
                                act: AppData.pet.groom,
                              ),
                              onPlay: () => _careAction(
                                consume: AppData.inventory.consumeToy,
                                act: AppData.pet.play,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.stackMd),
                            _TodayGoalCard(
                              habits: habits,
                              completedCount: completedCount,
                              completion: completion,
                              streak: user.currentStreak,
                              onToggle: _onHabitTileToggle,
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
                  Text('LEVEL ${user.level}', style: AppTextStyles.labelSm),
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
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            XpPill(xp: user.totalXp),
            const SizedBox(height: 4),
            _CoinPill(coins: user.coins),
          ],
        ),
      ],
    );
  }
}

class _CoinPill extends StatelessWidget {
  const _CoinPill({required this.coins});

  final int coins;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppRadius.full),
        border: Border.all(color: AppColors.ink, width: AppBorder.thin),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.monetization_on, size: 14, color: AppColors.mustardDark),
          const SizedBox(width: 4),
          Text('$coins', style: AppTextStyles.labelSm.copyWith(color: AppColors.ink)),
        ],
      ),
    );
  }
}

class _EvolutionBanner extends StatelessWidget {
  const _EvolutionBanner({required this.pet, required this.userLevel});

  final Pet pet;
  final int userLevel;

  @override
  Widget build(BuildContext context) {
    final evolved = pet.stage != PetEvolutionStage.baby;
    final levelsLeft = pet.levelsUntilNextEvolution(userLevel);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.gutter,
        vertical: AppSpacing.stackSm,
      ),
      decoration: BoxDecoration(
        color: AppColors.mossLight,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AppColors.ink, width: AppBorder.thin),
      ),
      child: Row(
        children: [
          const Icon(Icons.auto_awesome, color: AppColors.mossDark, size: 20),
          const SizedBox(width: AppSpacing.stackSm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${pet.stage.label} · Evolution 1 at Lvl ${pet.evolutionLevelThreshold}',
                  style: AppTextStyles.labelLg.copyWith(color: AppColors.mossDark),
                ),
                Text(
                  evolved
                      ? 'Nori has evolved!'
                      : '$levelsLeft ${levelsLeft == 1 ? 'level' : 'levels'} until Evolution 1',
                  style: AppTextStyles.labelSm.copyWith(color: AppColors.inkMuted),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.stackSm),
          SizedBox(
            width: 64,
            child: ProgressBarPill(
              progress: pet.progressToNextEvolution(userLevel),
              height: 8,
              color: AppColors.moss,
            ),
          ),
        ],
      ),
    );
  }
}

class _PetVitalsCard extends StatelessWidget {
  const _PetVitalsCard({required this.pet});

  final Pet pet;

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
        children: [
          PetStatBar(icon: Icons.set_meal, label: 'Hunger', value: pet.hunger),
          const SizedBox(height: AppSpacing.stackSm),
          PetStatBar(icon: Icons.water_drop, label: 'Hygiene', value: pet.hygiene),
          const SizedBox(height: AppSpacing.stackSm),
          PetStatBar(icon: Icons.favorite, label: 'Happiness', value: pet.happiness),
        ],
      ),
    );
  }
}

class _PetCareRow extends StatelessWidget {
  const _PetCareRow({
    required this.inventory,
    required this.onFeed,
    required this.onGroom,
    required this.onPlay,
  });

  final Inventory inventory;
  final VoidCallback onFeed;
  final VoidCallback onGroom;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _PetActionButton(
          icon: Icons.restaurant,
          iconBg: AppColors.sky,
          label: 'Feed',
          usesLeft: inventory.snacks,
          onPressed: onFeed,
        ),
        const SizedBox(width: AppSpacing.stackSm),
        _PetActionButton(
          icon: Icons.soap,
          iconBg: AppColors.mossLight,
          label: 'Groom',
          usesLeft: inventory.soap,
          onPressed: onGroom,
        ),
        const SizedBox(width: AppSpacing.stackSm),
        _PetActionButton(
          icon: Icons.sports_baseball,
          iconBg: AppColors.mustardLight,
          label: 'Play',
          usesLeft: inventory.toys,
          onPressed: onPlay,
        ),
      ],
    );
  }
}

class _PetActionButton extends StatelessWidget {
  const _PetActionButton({
    required this.icon,
    required this.iconBg,
    required this.label,
    required this.usesLeft,
    required this.onPressed,
  });

  final IconData icon;
  final Color iconBg;
  final String label;
  final int usesLeft;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final available = usesLeft > 0;
    return Expanded(
      child: Material(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          onTap: available ? onPressed : null,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.stackSm),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(color: AppColors.ink, width: AppBorder.thin),
            ),
            child: Column(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: available ? iconBg : AppColors.linenAlt,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.ink, width: AppBorder.thin),
                  ),
                  child: Icon(
                    icon,
                    size: 18,
                    color: available ? AppColors.ink : AppColors.inkFaint,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  label,
                  style: AppTextStyles.labelLg.copyWith(
                    color: available ? AppColors.ink : AppColors.inkFaint,
                  ),
                ),
                Text(
                  available ? 'x$usesLeft' : 'Buy more',
                  style: AppTextStyles.labelSm.copyWith(
                    color: available ? AppColors.inkMuted : AppColors.terracottaDark,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TodayGoalCard extends StatelessWidget {
  const _TodayGoalCard({
    required this.habits,
    required this.completedCount,
    required this.completion,
    required this.streak,
    required this.onToggle,
  });

  final List<Habit> habits;
  final int completedCount;
  final double completion;
  final int streak;
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
                    Row(
                      children: [
                        Text("Today's Goal", style: AppTextStyles.headlineMd),
                        const SizedBox(width: AppSpacing.unit),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.mustardLight,
                            borderRadius: BorderRadius.circular(AppRadius.full),
                            border: Border.all(
                              color: AppColors.ink,
                              width: AppBorder.thin,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.local_fire_department,
                                size: 14,
                                color: AppColors.mustardDark,
                              ),
                              const SizedBox(width: 2),
                              Text(
                                '${streak}d',
                                style: AppTextStyles.labelSm.copyWith(
                                  color: AppColors.mustardDark,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
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
