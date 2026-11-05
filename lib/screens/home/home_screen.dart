import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:nori/data/accessory_catalog.dart';
import 'package:nori/data/app_data.dart';
import 'package:nori/data/care_item_catalog.dart';
import 'package:nori/data/habit_repository.dart';
import 'package:nori/models/habit.dart';
import 'package:nori/models/inventory.dart';
import 'package:nori/models/nori_user.dart';
import 'package:nori/models/pet.dart';
import 'package:nori/screens/customization/customization_screen.dart';
import 'package:nori/screens/pet/evolution_screen.dart';
import 'package:nori/screens/pet/level_up_screen.dart';
import 'package:nori/screens/shop/shop_screen.dart';
import 'package:nori/theme/app_theme.dart';
import 'package:nori/utils/remote_errors.dart';
import 'package:nori/utils/formatting.dart';
import 'package:nori/widgets/circular_icon_button.dart';
import 'package:nori/widgets/habit_tile.dart';
import 'package:nori/widgets/load_error_view.dart';
import 'package:nori/widgets/nori_avatar.dart';
import 'package:nori/widgets/nori_card.dart';
import 'package:nori/widgets/nori_icon_badge.dart';
import 'package:nori/widgets/nori_room_stage.dart';
import 'package:nori/widgets/pet_vital_ring.dart';
import 'package:nori/widgets/progress_bar_pill.dart';
import 'package:nori/widgets/streak_chip.dart';
import 'package:nori/widgets/tactile_button.dart';

/// Home: Nori's room. The room is a true full-bleed background (edge to
/// edge, not a padded/rounded card) with the HUD and the habit panel
/// floating over it — habits get a single-line summary plus one actionable
/// item, not the full list (that lives on the Habits tab, reached via
/// [onOpenHabits] or by dragging the panel's handle up).
class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.active,
    required this.onOpenHabits,
  });

  /// Whether this is the currently-shown tab in [NoriShell]'s [IndexedStack].
  /// [IndexedStack] keeps every tab's state alive even while offstage, so
  /// without this a habit claimed/logged on another tab (e.g. the Habits
  /// tab) would leave this screen showing stale habits/XP until some
  /// unrelated action here happened to reload it. Reload on the
  /// false→true transition instead — see [_HomeScreenState.didUpdateWidget].
  final bool active;

  /// Switches the shell to the Habits tab.
  final VoidCallback onOpenHabits;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with RemoteLoadState<HomeScreen> {
  NoriUser? _user;
  List<Habit>? _habits;
  Pet? _pet;
  Inventory? _inventory;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void didUpdateWidget(covariant HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.active && widget.active) _loadData();
  }

  Future<void> _loadData() async {
    // Captured before the reload so a stage change picked up here — e.g. a
    // claim made on another tab while Home was last loaded — still gets its
    // celebration on switching back, not just one earned via a Home action.
    final previousStage = _pet?.stage;
    final previousLevel = _user?.level;
    await guardedLoad(hasData: _user != null, () async {
      // Started together, not one after another: each is its own Firestore
      // round trip, and awaiting them in turn made Home take ~4s to appear.
      // The pet still waits for the user, since syncEvolution needs the level.
      final userFuture = AppData.user.getCurrentUser();
      final petFuture = userFuture.then((user) async {
        await AppData.pet.syncEvolution(user.level);
        return AppData.pet.getPet();
      });
      final (user, habits, pet, inventory) = await (
        userFuture,
        AppData.habits.getHabitsForDate(DateTime.now()),
        petFuture,
        AppData.inventory.getInventory(),
      ).wait;
      if (!mounted) return;
      setState(() {
        _user = user;
        _habits = habits;
        _pet = pet;
        _inventory = inventory;
      });
    });
    await _celebrateChanges(previousStage, previousLevel);
  }

  Future<void> _reloadHabits() async {
    final habits = await AppData.habits.getHabitsForDate(DateTime.now());
    if (!mounted) return;
    setState(() => _habits = habits);
  }

  Future<void> _reloadInventory() async {
    final inventory = await AppData.inventory.getInventory();
    if (!mounted) return;
    setState(() => _inventory = inventory);
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

  /// Fires the evolution/level-up celebration when [_pet]/[_user] moved past
  /// the captured values. Kept outside every guarded load/action on purpose:
  /// it awaits a dialog the user may leave open, which would otherwise trip
  /// [remoteTimeout].
  ///
  /// previousStage == null only on the very first load (no prior pet to
  /// compare against) — skip the celebration then so it only ever fires
  /// for a real, in-session evolution, not on app open. Same reasoning
  /// applies to previousLevel.
  Future<void> _celebrateChanges(
    PetEvolutionStage? previousStage,
    int? previousLevel,
  ) async {
    final pet = _pet;
    final user = _user;
    if (!mounted || pet == null || user == null) return;
    if (previousStage != null && pet.stage.index > previousStage.index) {
      await showEvolutionCelebration(
        context,
        petName: pet.name,
        stage: pet.stage,
      );
    } else if (previousLevel != null && user.level > previousLevel) {
      await showLevelUpCelebration(
        context,
        level: user.level,
        petName: pet.name,
      );
    }
  }

  /// Runs one claim-style call — the claimHabit/unclaimHabit Cloud Function
  /// already wrote XP, coins, level and pet stage server-side, so a nonzero
  /// reward reloads user + pet and [_celebrateChanges]' before/after diff
  /// (not [reward] directly) decides whether to celebrate, since it also
  /// has to catch a change made on another tab.
  Future<void> _runClaim(Future<HabitRewardResult> Function() claim) async {
    final previousStage = _pet?.stage;
    final previousLevel = _user?.level;
    final ok = await guardedAction(() async {
      final reward = await claim();
      if (reward.xpDelta != 0 || reward.coinsDelta != 0) {
        await _reloadUserAndPet();
        // A paying claim can also grant (and auto-equip) the one-time
        // first-completion accessory, which the pet stage shows.
        await _reloadInventory();
      }
      await _reloadHabits();
    });
    if (ok) await _celebrateChanges(previousStage, previousLevel);
  }

  Future<void> _quickLog(Habit habit, double amount) async {
    await guardedAction(() async {
      await AppData.habits.logProgress(habit.id, amount);
      await _reloadHabits();
    });
  }

  /// The compact Today's Goal row uses [HabitTile], whose checkbox means
  /// "toggle" for binary habits and "claim / un-claim" for every other
  /// type — partial progress itself is logged via the tile's separate
  /// quick-log button ([_quickLog]), not this checkbox.
  Future<void> _onHabitTileToggle(Habit habit, bool completed) async {
    if (habit.type == HabitType.binary) {
      await _runClaim(
        () => AppData.habits.setHabitCompleted(habit.id, completed),
      );
      return;
    }
    if (completed) {
      await _runClaim(() => AppData.habits.claimHabit(habit.id));
    } else {
      await _runClaim(() => AppData.habits.unclaimHabit(habit.id));
    }
  }

  Future<void> _useCareItem(CareItem item) async {
    await guardedAction(() async {
      final ok = await AppData.pet.useCareItem(item);
      if (!mounted) return;
      if (!ok) {
        _showSnack('Out of stock — buy more in the Shop.');
        return;
      }
      final inventory = await AppData.inventory.getInventory();
      final pet = await AppData.pet.getPet();
      if (!mounted) return;
      setState(() {
        _inventory = inventory;
        _pet = pet;
      });
    });
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  // Both pushed as a route on top of Home, not a tab switch, so the
  // active/didUpdateWidget reload (for switching *between* tabs) never
  // fires for these — reload explicitly once the pushed screen is popped.
  Future<void> _openCustomization() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const CustomizationScreen()));
    await guardedAction(_reloadInventory);
  }

  Future<void> _openShop() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const ShopScreen()));
    // Purchases spend coins as well as changing inventory.
    await guardedAction(() async {
      await _reloadUserAndPet();
      await _reloadInventory();
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = _user;
    final habits = _habits;
    final pet = _pet;
    final inventory = _inventory;

    if (user == null || habits == null || pet == null || inventory == null) {
      final error = loadError;
      return Scaffold(
        body: error != null
            ? LoadErrorView(error: error, onRetry: _loadData)
            : const Center(child: CircularProgressIndicator()),
      );
    }

    final completedCount = habits
        .where((habit) => habit.isCompletedToday)
        .length;
    final completion = habits.isEmpty ? 0.0 : completedCount / habits.length;
    final equippedAccessory = inventory.equippedAccessoryId == null
        ? null
        : accessoryById(inventory.equippedAccessoryId!);

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
                    child: NoriRoomStage(
                      onTapNori: _openCustomization,
                      stage: pet.stage,
                      equippedAccessory: equippedAccessory,
                    ),
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
                        onUseCareItem: _useCareItem,
                        onShop: _openShop,
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
                      onQuickLog: _quickLog,
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
/// a coins chip, and a small Shop shortcut so buying more care items or
/// accessories doesn't require a detour through Profile.
class _RoomHud extends StatefulWidget {
  const _RoomHud({
    required this.user,
    required this.pet,
    required this.inventory,
    required this.onUseCareItem,
    required this.onShop,
  });

  final NoriUser user;
  final Pet pet;
  final Inventory inventory;
  final ValueChanged<CareItem> onUseCareItem;
  final VoidCallback onShop;

  @override
  State<_RoomHud> createState() => _RoomHudState();
}

class _RoomHudState extends State<_RoomHud> {
  bool _showEvolution = false;

  void _showCare({
    required IconData icon,
    required Color iconBg,
    required String vitalLabel,
    required double vitalValue,
    required Color vitalColor,
    required CareCategory category,
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
        items: careItemsForCategory(category),
        inventory: widget.inventory,
        onUseItem: (item) {
          Navigator.of(sheetContext).pop();
          widget.onUseCareItem(item);
        },
        onShop: () {
          Navigator.of(sheetContext).pop();
          widget.onShop();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    final pet = widget.pet;

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
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: AppColors.white.withValues(alpha: 0.88),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  border: Border.all(
                    color: AppColors.ink,
                    width: AppBorder.standard,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      pet.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.headlineMd.copyWith(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    InkWell(
                      onTap: () =>
                          setState(() => _showEvolution = !_showEvolution),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'LEVEL ${user.level}',
                            style: AppTextStyles.labelSm,
                          ),
                          const SizedBox(width: AppSpacing.unit),
                          Flexible(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 44),
                              child: ProgressBarPill(
                                progress: user.levelProgress,
                                height: 6,
                                color: AppColors.moss,
                                trackColor: AppColors.linen,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(
                            Icons.star,
                            size: 11,
                            color: AppColors.mustardDark,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            formatThousands(user.totalXp),
                            style: AppTextStyles.labelSm.copyWith(
                              color: AppColors.ink,
                            ),
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
            const SizedBox(width: AppSpacing.unit),
            CircularIconButton(
              icon: Icons.shopping_bag,
              tooltip: 'Shop',
              onPressed: widget.onShop,
            ),
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
                category: CareCategory.love,
              ),
            ),
            const SizedBox(width: 14),
            PetVitalRing(
              icon: const Icon(
                Icons.restaurant,
                size: 16,
                color: AppColors.ink,
              ),
              label: 'Fed',
              value: pet.hunger,
              color: AppColors.terracotta,
              onTap: () => _showCare(
                icon: Icons.restaurant,
                iconBg: AppColors.sky,
                vitalLabel: 'Hunger',
                vitalValue: pet.hunger,
                vitalColor: AppColors.terracotta,
                category: CareCategory.hunger,
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
                category: CareCategory.hygiene,
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
    return NoriCard(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      color: AppColors.mustard,
      radius: 14,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.monetization_on, size: 14, color: AppColors.ink),
          const SizedBox(width: 4),
          Text(
            '$coins',
            style: AppTextStyles.labelSm.copyWith(
              color: AppColors.ink,
              fontSize: 11,
            ),
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

/// Bottom sheet opened by tapping a vital ring: shows that stat and lets the
/// user pick which owned item to use on it — different items restore
/// different amounts (see care_item_catalog.dart), so this is a choice
/// rather than a single auto-applied action.
class _CareActionSheet extends StatelessWidget {
  const _CareActionSheet({
    required this.icon,
    required this.iconBg,
    required this.vitalLabel,
    required this.vitalValue,
    required this.vitalColor,
    required this.items,
    required this.inventory,
    required this.onUseItem,
    required this.onShop,
  });

  final IconData icon;
  final Color iconBg;
  final String vitalLabel;
  final double vitalValue;
  final Color vitalColor;

  /// Every catalog item for this vital's category — filtered to what's
  /// actually owned ([Inventory.countOf] > 0) before rendering.
  final List<CareItem> items;
  final Inventory inventory;
  final ValueChanged<CareItem> onUseItem;
  final VoidCallback onShop;

  @override
  Widget build(BuildContext context) {
    final owned = items
        .where((item) => inventory.countOf(item.id) > 0)
        .toList();
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.gutter),
        child: NoriCard(
          padding: const EdgeInsets.all(AppSpacing.gutter),
          radius: AppRadius.lg,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  NoriIconBadge(
                    icon: icon,
                    background: iconBg,
                    size: 44,
                    circle: true,
                    iconSize: 24,
                  ),
                  const SizedBox(width: AppSpacing.stackSm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          vitalLabel,
                          style: AppTextStyles.headlineMd.copyWith(
                            fontSize: 18,
                          ),
                        ),
                        Text(
                          '${vitalValue.round()}%',
                          style: AppTextStyles.labelSm.copyWith(
                            color: AppColors.inkMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.stackSm),
              ProgressBarPill(progress: vitalValue / 100, color: vitalColor),
              const SizedBox(height: AppSpacing.stackMd),
              if (owned.isEmpty) ...[
                Text(
                  'Out of stock — visit the Shop to buy more.',
                  style: AppTextStyles.bodyMd.copyWith(
                    color: AppColors.inkMuted,
                  ),
                ),
                const SizedBox(height: AppSpacing.stackMd),
                TactileButton(
                  label: 'Go to Shop',
                  icon: Icons.shopping_bag,
                  onPressed: onShop,
                ),
              ] else
                for (final item in owned) ...[
                  _CareItemChoiceRow(
                    item: item,
                    usesLeft: inventory.countOf(item.id),
                    onTap: () => onUseItem(item),
                  ),
                  if (item != owned.last)
                    const SizedBox(height: AppSpacing.stackSm),
                ],
            ],
          ),
        ),
      ),
    );
  }
}

/// One tappable row in [_CareActionSheet] — the item's art, name, how much
/// it restores, and how many uses are left.
class _CareItemChoiceRow extends StatelessWidget {
  const _CareItemChoiceRow({
    required this.item,
    required this.usesLeft,
    required this.onTap,
  });

  final CareItem item;
  final int usesLeft;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.stackSm),
          decoration: BoxDecoration(
            color: item.color,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AppColors.ink, width: AppBorder.thin),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                padding: item.image != null
                    ? const EdgeInsets.all(4)
                    : EdgeInsets.zero,
                decoration: BoxDecoration(
                  color: AppColors.white,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.ink,
                    width: AppBorder.thin,
                  ),
                ),
                child: item.image != null
                    ? Image.asset(item.image!, fit: BoxFit.contain)
                    : Icon(item.icon, size: 20, color: AppColors.ink),
              ),
              const SizedBox(width: AppSpacing.stackSm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.name, style: AppTextStyles.labelLg),
                    Text(
                      'x$usesLeft left',
                      style: AppTextStyles.labelSm.copyWith(
                        color: AppColors.inkMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '+${item.restoreAmount.round()}',
                style: AppTextStyles.labelLg.copyWith(
                  color: AppColors.mossDark,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right, color: AppColors.inkMuted),
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
    required this.onQuickLog,
    required this.onOpenHabits,
  });

  final List<Habit> habits;
  final int completedCount;
  final double completion;
  final int streak;
  final Future<void> Function(Habit habit, bool completed) onToggle;
  final Future<void> Function(Habit habit, double amount) onQuickLog;
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

  // Whether the expanded list's ConstrainedBox actually clips content —
  // it rarely lands on a whole tile boundary, so without this the last
  // visible tile gets sliced mid-row with no indication it's scrollable.
  bool _listOverflows = false;

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
              top: const BorderSide(
                color: AppColors.ink,
                width: AppBorder.standard,
              ),
              left: const BorderSide(
                color: AppColors.ink,
                width: AppBorder.standard,
              ),
              right: const BorderSide(
                color: AppColors.ink,
                width: AppBorder.standard,
              ),
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
                          style: AppTextStyles.headlineMd.copyWith(
                            fontSize: 19,
                          ),
                        ),
                        if (widget.streak > 0) ...[
                          const SizedBox(width: AppSpacing.unit),
                          StreakChip(streak: widget.streak),
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
                            child: Icon(
                              Icons.chevron_right,
                              color: AppColors.inkFaint,
                            ),
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
                        'No habits scheduled for today. Add or review your '
                        'habits in the Habits tab.',
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
                        child: ShaderMask(
                          shaderCallback: (rect) => LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: const [
                              Colors.black,
                              Colors.black,
                              Colors.transparent,
                            ],
                            stops: const [0.0, 0.88, 1.0],
                          ).createShader(rect),
                          blendMode: _listOverflows
                              ? BlendMode.dstIn
                              : BlendMode.dst,
                          child:
                              NotificationListener<ScrollMetricsNotification>(
                                onNotification: (notification) {
                                  final overflows =
                                      notification.metrics.maxScrollExtent > 0;
                                  if (overflows != _listOverflows) {
                                    WidgetsBinding.instance
                                        .addPostFrameCallback((_) {
                                          if (mounted) {
                                            setState(
                                              () => _listOverflows = overflows,
                                            );
                                          }
                                        });
                                  }
                                  return false;
                                },
                                child: SingleChildScrollView(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      for (
                                        var i = 0;
                                        i < habits.length;
                                        i++
                                      ) ...[
                                        HabitTile(
                                          habit: habits[i],
                                          onToggle: (completed) => widget
                                              .onToggle(habits[i], completed),
                                          onQuickLog: (amount) => widget
                                              .onQuickLog(habits[i], amount),
                                          onEdit: widget.onOpenHabits,
                                        ),
                                        const SizedBox(
                                          height: AppSpacing.stackSm,
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
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
                        onQuickLog: (amount) =>
                            widget.onQuickLog(nextHabit!, amount),
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
