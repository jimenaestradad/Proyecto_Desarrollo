import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:nori/data/app_data.dart';
import 'package:nori/data/habit_repository.dart';
import 'package:nori/models/habit.dart';
import 'package:nori/models/inventory.dart';
import 'package:nori/models/nori_user.dart';
import 'package:nori/models/pet.dart';
import 'package:nori/screens/customization/customization_screen.dart';
import 'package:nori/screens/pet/evolution_screen.dart';
import 'package:nori/theme/app_theme.dart';
import 'package:nori/widgets/habit_tile.dart';
import 'package:nori/widgets/nori_avatar.dart';
import 'package:nori/widgets/nori_room_stage.dart';
import 'package:nori/widgets/pet_vital_ring.dart';
import 'package:nori/widgets/progress_bar_pill.dart';
import 'package:nori/widgets/tactile_button.dart';

/// Home: Nori's room. The room is a true full-bleed background (edge to
/// edge, not a padded/rounded card) with the HUD and the habit panel
/// floating over it — habits get a single-line summary plus one actionable
/// item, not the full list (that lives on the Habits tab, reached via
/// [onOpenHabits] or by dragging the panel's handle up).
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.onOpenHabits});

  /// Switches the shell to the Habits tab.
  final VoidCallback onOpenHabits;

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
    final previousStage = _pet?.stage;
    final user = await AppData.user.getCurrentUser();
    await AppData.pet.syncEvolution(user.level);
    final pet = await AppData.pet.getPet();
    if (!mounted) return;
    setState(() {
      _user = user;
      _pet = pet;
    });
    // previousStage == null only on the very first load (no prior pet to
    // compare against) — skip the celebration then so it only ever fires
    // for a real, in-session evolution, not on app open.
    if (previousStage != null && previousStage != pet.stage) {
      await showEvolutionCelebration(
        context,
        petName: pet.name,
        stage: pet.stage,
      );
    }
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

  /// The compact Today's Goal row uses [HabitTile], whose checkbox only
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

  void _openCustomization() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const CustomizationScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final user = _user;
    final habits = _habits;
    final pet = _pet;
    final inventory = _inventory;

    if (user == null || habits == null || pet == null || inventory == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final completedCount = habits.where((habit) => habit.isCompletedToday).length;
    final completion = habits.isEmpty ? 0.0 : completedCount / habits.length;

    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 800;
          final horizontalPadding = isWide
              ? AppSpacing.containerPaddingDesktop
              : AppSpacing.containerPaddingMobile;

          // Align+SizedBox, not Center+ConstrainedBox: Center hands its
          // child loose constraints, so the Stack below would size itself
          // to its one non-positioned child (the HUD) instead of filling
          // the screen — collapsing the whole layout to HUD-height and
          // leaving the room background and the bottom-pinned habit panel
          // with nothing to actually fill or pin against.
          return Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: constraints.maxWidth.clamp(0.0, 560.0),
              height: constraints.maxHeight,
              child: Stack(
                children: [
                  // Full-bleed: fills the whole body edge to edge, not a
                  // padded/rounded card — the HUD and habit panel float
                  // over it instead of sitting in a separate section.
                  Positioned.fill(
                    child: NoriRoomStage(onTapNori: _openCustomization),
                  ),
                  SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        horizontalPadding,
                        AppSpacing.stackSm,
                        horizontalPadding,
                        0,
                      ),
                      child: _RoomHud(
                        user: user,
                        pet: pet,
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
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: _HabitPanel(
                      habits: habits,
                      completedCount: completedCount,
                      completion: completion,
                      streak: user.currentStreak,
                      onToggle: _onHabitTileToggle,
                      onOpenHabits: widget.onOpenHabits,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Floats over the top of the room: avatar, a card with name/level (tap the
/// level bar to reveal the evolution + XP readout), the three vital rings,
/// and a coins chip.
class _RoomHud extends StatefulWidget {
  const _RoomHud({
    required this.user,
    required this.pet,
    required this.inventory,
    required this.onFeed,
    required this.onGroom,
    required this.onPlay,
  });

  final NoriUser user;
  final Pet pet;
  final Inventory inventory;
  final VoidCallback onFeed;
  final VoidCallback onGroom;
  final VoidCallback onPlay;

  @override
  State<_RoomHud> createState() => _RoomHudState();
}

class _RoomHudState extends State<_RoomHud> {
  bool _showEvolution = false;

  static String _formattedXp(int xp) => xp.toString().replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (match) => ',',
  );

  void _showCare({
    required IconData icon,
    required Color iconBg,
    required String vitalLabel,
    required double vitalValue,
    required Color vitalColor,
    required String actionLabel,
    required int usesLeft,
    required VoidCallback onConfirm,
  }) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _CareActionSheet(
        icon: icon,
        iconBg: iconBg,
        vitalLabel: vitalLabel,
        vitalValue: vitalValue,
        vitalColor: vitalColor,
        actionLabel: actionLabel,
        usesLeft: usesLeft,
        onConfirm: () {
          Navigator.of(sheetContext).pop();
          onConfirm();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    final pet = widget.pet;
    final inventory = widget.inventory;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            NoriAvatar(imageUrl: user.avatarUrl, size: 46),
            const SizedBox(width: AppSpacing.stackSm),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.white.withValues(alpha: 0.88),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  border: Border.all(color: AppColors.ink, width: AppBorder.standard),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Nori',
                      style: AppTextStyles.headlineMd.copyWith(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    InkWell(
                      onTap: () => setState(() => _showEvolution = !_showEvolution),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('LEVEL ${user.level}', style: AppTextStyles.labelSm),
                          const SizedBox(width: AppSpacing.unit),
                          SizedBox(
                            width: 44,
                            child: ProgressBarPill(
                              progress: user.levelProgress,
                              height: 6,
                              color: AppColors.moss,
                              trackColor: AppColors.linen,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(Icons.star, size: 11, color: AppColors.mustardDark),
                          const SizedBox(width: 2),
                          Text(
                            _formattedXp(user.totalXp),
                            style: AppTextStyles.labelSm.copyWith(color: AppColors.ink),
                          ),
                          const SizedBox(width: 3),
                          Icon(
                            _showEvolution
                                ? Icons.expand_less
                                : Icons.expand_more,
                            size: 14,
                            color: AppColors.inkFaint,
                          ),
                        ],
                      ),
                    ),
                    // Expands the card itself (not a separate chip below
                    // it) to show the evolution stage — XP now lives
                    // inline next to the level bar above, always visible.
                    AnimatedSize(
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOut,
                      alignment: Alignment.topLeft,
                      child: _showEvolution
                          ? Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: _EvolutionDetails(
                                pet: pet,
                                userLevel: user.level,
                              ),
                            )
                          : const SizedBox(width: double.infinity),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.unit),
            _CoinPill(coins: user.coins),
          ],
        ),
        const SizedBox(height: AppSpacing.gutter),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            PetVitalRing(
              icon: const Icon(Icons.favorite, size: 16, color: AppColors.ink),
              label: 'Happy',
              value: pet.happiness,
              color: AppColors.moss,
              onTap: () => _showCare(
                icon: Icons.favorite,
                iconBg: AppColors.mossLight,
                vitalLabel: 'Happiness',
                vitalValue: pet.happiness,
                vitalColor: AppColors.moss,
                actionLabel: 'Play',
                usesLeft: inventory.toys,
                onConfirm: widget.onPlay,
              ),
            ),
            const SizedBox(width: 14),
            PetVitalRing(
              icon: const Icon(Icons.restaurant, size: 16, color: AppColors.ink),
              label: 'Fed',
              value: pet.hunger,
              color: AppColors.terracotta,
              onTap: () => _showCare(
                icon: Icons.restaurant,
                iconBg: AppColors.sky,
                vitalLabel: 'Hunger',
                vitalValue: pet.hunger,
                vitalColor: AppColors.terracotta,
                actionLabel: 'Feed',
                usesLeft: inventory.snacks,
                onConfirm: widget.onFeed,
              ),
            ),
            const SizedBox(width: 14),
            PetVitalRing(
              icon: const Icon(Icons.wash, size: 16, color: AppColors.ink),
              label: 'Clean',
              value: pet.hygiene,
              color: AppColors.skyBlue,
              onTap: () => _showCare(
                icon: Icons.soap,
                iconBg: AppColors.mossLight,
                vitalLabel: 'Hygiene',
                vitalValue: pet.hygiene,
                vitalColor: AppColors.skyBlue,
                actionLabel: 'Groom',
                usesLeft: inventory.soap,
                onConfirm: widget.onGroom,
              ),
            ),
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.mustard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.ink, width: AppBorder.standard),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.monetization_on, size: 14, color: AppColors.ink),
          const SizedBox(width: 4),
          Text(
            '$coins',
            style: AppTextStyles.labelSm.copyWith(color: AppColors.ink, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

/// Revealed by tapping the level row: just the evolution stage/distance —
/// XP moved out to sit inline next to the level bar instead. Expands the
/// name/level card itself (no border/background of its own) rather than
/// spawning a separate chip underneath it.
class _EvolutionDetails extends StatelessWidget {
  const _EvolutionDetails({required this.pet, required this.userLevel});

  final Pet pet;
  final int userLevel;

  @override
  Widget build(BuildContext context) {
    final evolved = pet.stage != PetEvolutionStage.baby;
    final levelsLeft = pet.levelsUntilNextEvolution(userLevel);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.auto_awesome, size: 13, color: AppColors.mossDark),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            evolved
                ? '${pet.stage.label} · Evolved!'
                : '${pet.stage.label} · $levelsLeft ${levelsLeft == 1 ? 'level' : 'levels'} to Evo 1',
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.labelSm.copyWith(color: AppColors.mossDark),
          ),
        ),
      ],
    );
  }
}

/// Bottom sheet opened by tapping a vital ring: shows that stat and the one
/// action that cares for it.
class _CareActionSheet extends StatelessWidget {
  const _CareActionSheet({
    required this.icon,
    required this.iconBg,
    required this.vitalLabel,
    required this.vitalValue,
    required this.vitalColor,
    required this.actionLabel,
    required this.usesLeft,
    required this.onConfirm,
  });

  final IconData icon;
  final Color iconBg;
  final String vitalLabel;
  final double vitalValue;
  final Color vitalColor;
  final String actionLabel;
  final int usesLeft;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final available = usesLeft > 0;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.gutter),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.gutter),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AppColors.ink, width: AppBorder.standard),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: iconBg,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.ink, width: AppBorder.thin),
                    ),
                    child: Icon(icon, color: AppColors.ink),
                  ),
                  const SizedBox(width: AppSpacing.stackSm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(vitalLabel, style: AppTextStyles.headlineMd.copyWith(fontSize: 18)),
                        Text(
                          '${vitalValue.round()}%',
                          style: AppTextStyles.labelSm.copyWith(color: AppColors.inkMuted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.stackSm),
              ProgressBarPill(progress: vitalValue / 100, color: vitalColor),
              const SizedBox(height: AppSpacing.stackMd),
              TactileButton(
                label: available ? '$actionLabel (x$usesLeft left)' : 'Out of stock — visit the Shop',
                icon: icon,
                onPressed: available ? onConfirm : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Floats over the bottom of the room as frosted glass — not a section
/// below it. Shows a single-line summary plus the one habit still open;
/// dragging the handle/header up (past a small threshold) expands the panel
/// in place to show every habit due today. Tapping the chevron still jumps
/// to the full Habits tab.
class _HabitPanel extends StatefulWidget {
  const _HabitPanel({
    required this.habits,
    required this.completedCount,
    required this.completion,
    required this.streak,
    required this.onToggle,
    required this.onOpenHabits,
  });

  final List<Habit> habits;
  final int completedCount;
  final double completion;
  final int streak;
  final Future<void> Function(Habit habit, bool completed) onToggle;
  final VoidCallback onOpenHabits;

  @override
  State<_HabitPanel> createState() => _HabitPanelState();
}

class _HabitPanelState extends State<_HabitPanel> {
  // Distance the drag has to travel past its start before it flips the
  // expanded state — not a live 1:1 follow, so a longer list doesn't need
  // proportional-height math mid-gesture, just a toggle at each end.
  static const _dragToggleDistance = 32.0;

  bool _expanded = false;
  double _dragAccum = 0;

  void _onDragUpdate(DragUpdateDetails details) {
    _dragAccum += details.delta.dy;
    if (!_expanded && _dragAccum <= -_dragToggleDistance) {
      setState(() => _expanded = true);
      _dragAccum = 0;
    } else if (_expanded && _dragAccum >= _dragToggleDistance) {
      setState(() => _expanded = false);
      _dragAccum = 0;
    }
  }

  void _onDragEnd(DragEndDetails details) {
    _dragAccum = 0;
  }

  @override
  Widget build(BuildContext context) {
    final habits = widget.habits;
    Habit? nextHabit;
    for (final habit in habits) {
      if (!habit.isCompletedToday) {
        nextHabit = habit;
        break;
      }
    }
    final maxExpandedListHeight = MediaQuery.sizeOf(context).height * 0.4;

    return ClipRRect(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(26),
          topRight: Radius.circular(26),
        ),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            padding: const EdgeInsets.fromLTRB(18, 20, 18, AppSpacing.stackMd),
            decoration: BoxDecoration(
              // Matches the design spec's rgba(255,255,255,.5) exactly —
              // earlier "more transparent" tweaks had pushed this down to
              // 0.18, which let too much of the warm blurred room floor
              // show through and read as a flat tan card instead of
              // frosted glass.
              color: AppColors.white.withValues(alpha: 0.5),
              // Top + sides only, no bottom: the panel sits flush against
              // the bottom nav bar, which has its own top border right
              // there — a bottom border on the panel doubled up with it
              // and read as one extra-thick line. Top+left+right still
              // share matching sides at both rounded top corners (the
              // only rounded ones — bottom stays sharp), which is what
              // avoids the tapering a mismatched single-side border
              // caused before; the border here needs a borderRadius of
              // its own to match the outer ClipRRect, since a
              // BoxDecoration border with none draws as a sharp rectangle
              // that gets clipped clean off at the curve otherwise.
              border: Border(
                top: const BorderSide(color: AppColors.ink, width: AppBorder.standard),
                left: const BorderSide(color: AppColors.ink, width: AppBorder.standard),
                right: const BorderSide(color: AppColors.ink, width: AppBorder.standard),
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(26),
                topRight: Radius.circular(26),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onVerticalDragUpdate: _onDragUpdate,
                  onVerticalDragEnd: _onDragEnd,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Center(
                        child: Container(
                          width: 38,
                          height: 5,
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: AppColors.ink.withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          Text(
                            "Today's Goal",
                            style: AppTextStyles.headlineMd.copyWith(fontSize: 19),
                          ),
                          if (widget.streak > 0) ...[
                            const SizedBox(width: AppSpacing.unit),
                            _StreakChip(streak: widget.streak),
                          ],
                          const Spacer(),
                          Text(
                            '${widget.completedCount} / ${habits.length}',
                            style: AppTextStyles.labelLg.copyWith(
                              color: AppColors.terracottaDark,
                            ),
                          ),
                          InkWell(
                            borderRadius: BorderRadius.circular(AppRadius.full),
                            onTap: widget.onOpenHabits,
                            child: const Padding(
                              padding: EdgeInsets.only(left: 2),
                              child: Icon(Icons.chevron_right, color: AppColors.inkFaint),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ProgressBarPill(
                        progress: widget.completion,
                        height: 8,
                        color: AppColors.terracotta,
                      ),
                      const SizedBox(height: AppSpacing.stackSm),
                    ],
                  ),
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOut,
                  alignment: Alignment.topCenter,
                  child: habits.isEmpty
                      ? Text(
                          'No habits scheduled for today.',
                          textAlign: TextAlign.center,
                          style: AppTextStyles.bodyMd.copyWith(
                            color: AppColors.inkFaint,
                          ),
                        )
                      : _expanded
                      ? ConstrainedBox(
                          constraints: BoxConstraints(
                            maxHeight: maxExpandedListHeight,
                          ),
                          child: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                for (var i = 0; i < habits.length; i++) ...[
                                  HabitTile(
                                    habit: habits[i],
                                    onToggle: (completed) =>
                                        widget.onToggle(habits[i], completed),
                                    onEdit: widget.onOpenHabits,
                                  ),
                                  const SizedBox(height: AppSpacing.stackSm),
                                ],
                              ],
                            ),
                          ),
                        )
                      : nextHabit == null
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.celebration,
                              size: 18,
                              color: AppColors.mossDark,
                            ),
                            const SizedBox(width: AppSpacing.unit),
                            Text(
                              'All done for today!',
                              style: AppTextStyles.bodyMd.copyWith(
                                color: AppColors.mossDark,
                              ),
                            ),
                          ],
                        )
                      : HabitTile(
                          habit: nextHabit,
                          onToggle: (completed) =>
                              widget.onToggle(nextHabit!, completed),
                          onEdit: widget.onOpenHabits,
                        ),
                ),
              ],
            ),
          ),
        ),
      );
  }
}

class _StreakChip extends StatelessWidget {
  const _StreakChip({required this.streak});

  final int streak;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.mustardLight,
        borderRadius: BorderRadius.circular(AppRadius.full),
        border: Border.all(color: AppColors.ink, width: AppBorder.thin),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.local_fire_department, size: 14, color: AppColors.mustardDark),
          const SizedBox(width: 2),
          Text(
            '${streak}d',
            style: AppTextStyles.labelSm.copyWith(color: AppColors.mustardDark),
          ),
        ],
      ),
    );
  }
}
