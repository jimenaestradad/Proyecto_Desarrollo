import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:nori/data/accessory_catalog.dart';
import 'package:nori/data/app_data.dart';
import 'package:nori/data/care_item_catalog.dart';
import 'package:nori/data/habit_local_edits.dart';
import 'package:nori/data/habit_repository.dart';
import 'package:nori/data/pet_repository.dart';
import 'package:nori/screens/habits/habit_day_actions.dart'
    show OptimisticHabits;
import 'package:nori/models/habit.dart';
import 'package:nori/models/inventory.dart';
import 'package:nori/models/nori_user.dart';
import 'package:nori/models/pet.dart';
import 'package:nori/screens/customization/customization_screen.dart';
import 'package:nori/screens/pet/evolution_screen.dart';
import 'package:nori/screens/pet/gift_screen.dart';
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
import 'package:nori/widgets/reward_burst.dart';
import 'package:nori/widgets/streak_chip.dart';
import 'package:nori/widgets/syncing_icon.dart';
import 'package:nori/widgets/tactile_button.dart';

/// Nori's full-bleed room with a floating HUD and habit summary/action panel.
/// [onOpenHabits] or dragging the handle opens the full Habits tab.
class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.active,
    required this.onOpenHabits,
  });

  /// Whether this preserved IndexedStack tab is visible.
  /// Reload on activation so changes from other tabs appear immediately.
  final bool active;

  /// Switches the shell to the Habits tab.
  final VoidCallback onOpenHabits;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with RemoteLoadState<HomeScreen>, OptimisticHabits<HomeScreen> {
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
    if (!oldWidget.active && widget.active) {
      // Show the newest XP/coins at once; the reload below still has the last word.
      _user = AppData.user.lastKnownUser ?? _user;
      _loadData();
    }
  }

  /// Which [_loadData] call is the latest; an older one finishing after a
  /// newer one must not overwrite it.
  int _loadSeq = 0;

  Future<void> _loadData() async {
    final seq = ++_loadSeq;
    // A claim, log or care item used while this load is in flight makes its
    // result older than what's on screen; those actions re-read what they
    // changed themselves, so the load then leaves the screen alone.
    final habitEdits = editStamp;
    final careEdits = _careEdits;
    // Captured before the reload so a stage change picked up here — e.g. a
    // claim made on another tab while Home was last loaded — still gets its
    // celebration on switching back, not just one earned via a Home action.
    final previousStage = _pet?.stage;
    final previousLevel = _user?.level;
    await guardedLoad(hasData: _user != null, () async {
      // Started together, not one after another: each is its own Firestore
      // round trip, and awaiting them in turn made Home take ~4s to appear.
      final (user, habits, pet, inventory) = await (
        AppData.user.getCurrentUser(),
        AppData.habits.getHabitsForDate(DateTime.now()),
        AppData.pet.getPet(),
        AppData.inventory.getInventory(),
      ).wait;
      if (!mounted || seq != _loadSeq) return;
      if (editStamp != habitEdits || _careEdits != careEdits) return;
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
    final stamp = editStamp;
    final habits = await AppData.habits.getHabitsForDate(DateTime.now());
    if (!mounted || stamp != editStamp) return;
    setState(() => _habits = habits);
  }

  @override
  Future<void> reloadActionHabits() => _reloadHabits();

  @override
  Object? snapshotHabits() => _habits;

  @override
  void restoreHabitSnapshot(Object snapshot) =>
      _habits = snapshot as List<Habit>;

  @override
  void applyHabitChange(String habitId, Habit Function(Habit) change) {
    final habits = _habits;
    if (habits == null) return;
    setState(() {
      _habits = [for (final h in habits) h.id == habitId ? change(h) : h];
    });
  }

  Future<void> _reloadInventory() async {
    final inventory = await AppData.inventory.getInventory();
    if (!mounted) return;
    setState(() => _inventory = inventory);
  }

  Future<void> _reloadUserAndPet() async {
    final (user, pet) = await (
      AppData.user.getCurrentUser(),
      AppData.pet.getPet(),
    ).wait;
    if (!mounted) return;
    setState(() {
      _user = user;
      _pet = pet;
    });
  }

  /// Celebrates changes to pet stage or user level, skipping the first load.
  /// Runs outside guarded actions because a dialog may outlast [remoteTimeout].
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

  /// Runs a server claim; [change] updates the tile and [then] follows the call.
  /// Nonzero rewards reload user/pet; [_celebrateChanges] compares before/after
  /// so changes made on other tabs can also celebrate.
  Future<void> _runClaim(
    Habit habit,
    Habit Function(Habit) change,
    Future<HabitRewardResult> Function() claim, {
    Future<void> Function()? then,
  }) async {
    final previousStage = _pet?.stage;
    final previousLevel = _user?.level;
    String? giftedAccessoryId;
    RewardBurst.showForClaim(context, before: habit, after: change(habit));
    final ok = await optimisticHabitEdit(habit.id, change, () async {
      final reward = await claim();
      giftedAccessoryId = reward.giftedAccessoryId;
      // Every time, not only when paying: Undo pays nothing but can still
      // change the streak.
      await _reloadUserAndPet();
      if (reward.xpDelta != 0 || reward.coinsDelta != 0) {
        // A paying claim can also grant (and auto-equip) the one-time
        // first-completion accessory, which the pet stage shows.
        await _reloadInventory();
      }
      if (then != null) await then();
    }, paysReward: true);
    if (!ok) return;
    await _celebrateChanges(previousStage, previousLevel);
    final gift = giftedAccessoryId;
    final pet = _pet;
    if (gift != null && pet != null && mounted) {
      final tryItOn = await showGiftCelebration(
        context,
        accessoryId: gift,
        petName: pet.name,
      );
      if (tryItOn && mounted) {
        await Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const CustomizationScreen()));
      }
    }
  }

  /// Quick-logs [amount]; reaching the target completes the habit.
  Future<void> _quickLog(Habit habit, double amount) async {
    final today = DateTime.now();
    if (habit.reachesTarget(habit.currentValue + amount)) {
      PreClaimValues.remember(habit.id, today, habit.currentValue);
      await _runClaim(
        habit,
        (h) => h.withLogged(amount).claimedLocally(),
        () async {
          await AppData.habits.logProgress(habit.id, amount);
          return AppData.habits.claimHabit(habit.id);
        },
      );
      return;
    }
    await optimisticHabitEdit(
      habit.id,
      (h) => h.withLogged(amount),
      () => AppData.habits.logProgress(habit.id, amount),
    );
  }

  /// The compact Today's Goal row uses [HabitTile], whose checkbox means
  /// "toggle" for binary habits and "claim / un-claim" for every other
  /// type — partial progress itself is logged via the tile's separate
  /// quick-log button ([_quickLog]), not this checkbox.
  Future<void> _onHabitTileToggle(Habit habit, bool completed) async {
    final today = DateTime.now();
    if (habit.type == HabitType.binary) {
      await _runClaim(
        habit,
        (h) => completed ? h.claimedLocally() : h.unclaimedLocally(),
        () => AppData.habits.setHabitCompleted(habit.id, completed),
      );
      return;
    }
    if (completed) {
      if (habit.completesAtTarget) {
        PreClaimValues.remember(habit.id, today, habit.currentValue);
      }
      await _runClaim(
        habit,
        (h) => h.claimedLocally(),
        () => AppData.habits.claimHabit(habit.id),
      );
      return;
    }
    final restore = PreClaimValues.take(habit.id, today);
    final restoring = restore != null && restore != habit.currentValue;
    await _runClaim(
      habit,
      (h) => h.unclaimedLocally(restoreValue: restoring ? restore : null),
      () => AppData.habits.unclaimHabit(habit.id),
      then: restoring
          ? () => AppData.habits.setProgress(habit.id, restore)
          : null,
    );
  }

  int _carePending = 0;
  int _careEdits = 0;

  /// Stock and vitals before the first care item now in flight; restored if
  /// the call fails, so the undo doesn't need the network. See [_useCareItem].
  (Inventory, Pet)? _careBaseline;

  /// Feeds, washes or plays at once (stock down, vital up) and confirms with
  /// the server in the background. A refusal or failure re-reads both.
  Future<void> _useCareItem(CareItem item) async {
    final inventory = _inventory;
    final pet = _pet;
    if (inventory == null || pet == null) return;
    if (inventory.countOf(item.id) <= 0) {
      _showSnack('Out of stock — buy more in the shop.');
      return;
    }
    _careEdits++;
    if (_carePending == 0) _careBaseline = (inventory, pet);
    _carePending++;
    setState(() {
      _inventory = inventory.copyWith(
        careItemCounts: {
          ...inventory.careItemCounts,
          item.id: inventory.countOf(item.id) - 1,
        },
      );
      _pet = applyCareRestore(pet, item);
    });
    var used = false;
    final ok = await guardedAction(() async {
      used = await AppData.pet.useCareItem(item);
    });
    _carePending--;
    final baseline = _careBaseline;
    if (_carePending == 0) _careBaseline = null;
    if (!mounted) return;
    if ((!ok || !used) && baseline != null) {
      setState(() {
        _inventory = baseline.$1;
        _pet = baseline.$2;
      });
    }
    if (ok && !used) {
      _showSnack('Out of stock — buy more in the shop.');
    }
    if (!ok || !used || _carePending == 0) {
      await guardedAction(() => _reloadCare(_careEdits));
    }
  }

  /// Re-reads stock and vitals, unless another care item was used meanwhile.
  Future<void> _reloadCare(int stamp) async {
    final (inventory, pet) = await (
      AppData.inventory.getInventory(),
      AppData.pet.getPet(),
    ).wait;
    if (!mounted || stamp != _careEdits) return;
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
            : const _HomeLoading(),
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

          // Align+SizedBox makes the Stack fill the screen.
          // Loose Center constraints would shrink it to the HUD and collapse the room/panel.
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
                        syncing: rewardSyncing,
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

/// First-load placeholder: a spinner with a line saying what is happening.
class _HomeLoading extends StatelessWidget {
  const _HomeLoading();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: AppSpacing.gutter),
          Text(
            'Waking up your Nori…',
            style: AppTextStyles.bodyMd.copyWith(color: AppColors.inkMuted),
          ),
        ],
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
    required this.syncing,
    required this.onUseCareItem,
    required this.onShop,
  });

  /// A claim is being confirmed, so XP and coins are about to change.
  final bool syncing;

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
              // The whole pill toggles the evolution details, not just the
              // little arrow. Material + InkWell (not a decorated Container)
              // so the ripple paints over the white fill.
              child: Material(
                color: AppColors.white.withValues(alpha: 0.88),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  side: const BorderSide(
                    color: AppColors.ink,
                    width: AppBorder.standard,
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => setState(() => _showEvolution = !_showEvolution),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 5,
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
                        Row(
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
                            SyncingIcon(
                              icon: Icons.star,
                              size: 11,
                              color: AppColors.mustardDark,
                              syncing: widget.syncing,
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
              ),
            ),
            const SizedBox(width: AppSpacing.unit),
            _CoinPill(coins: user.coins, syncing: widget.syncing),
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
              icon: const Icon(Icons.favorite, size: 16),
              label: 'Happy',
              value: pet.happiness,
              color: AppColors.moss,
              onTap: () => _showCare(
                icon: Icons.favorite,
                iconBg: AppColors.moss,
                vitalLabel: 'Happiness',
                vitalValue: pet.happiness,
                vitalColor: AppColors.moss,
                category: CareCategory.love,
              ),
            ),
            const SizedBox(width: 14),
            PetVitalRing(
              icon: const Icon(Icons.restaurant, size: 16),
              label: 'Fed',
              value: pet.hunger,
              color: AppColors.terracotta,
              onTap: () => _showCare(
                icon: Icons.restaurant,
                iconBg: AppColors.terracotta,
                vitalLabel: 'Fullness',
                vitalValue: pet.hunger,
                vitalColor: AppColors.terracotta,
                category: CareCategory.hunger,
              ),
            ),
            const SizedBox(width: 14),
            PetVitalRing(
              icon: const Icon(Icons.wash, size: 16),
              label: 'Clean',
              value: pet.hygiene,
              color: AppColors.skyBlue,
              onTap: () => _showCare(
                icon: Icons.soap,
                iconBg: AppColors.skyBlue,
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
  const _CoinPill({required this.coins, required this.syncing});

  final int coins;
  final bool syncing;

  @override
  Widget build(BuildContext context) {
    return NoriCard(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      color: AppColors.mustard,
      radius: 14,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SyncingIcon(
            icon: Icons.monetization_on,
            size: 14,
            color: AppColors.ink,
            syncing: syncing,
          ),
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
                  'Out of stock — visit the shop to buy more.',
                  style: AppTextStyles.bodyMd.copyWith(
                    color: AppColors.inkMuted,
                  ),
                ),
                const SizedBox(height: AppSpacing.stackMd),
                TactileButton(
                  label: 'Go to shop',
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

/// Frosted panel over the room with a summary and one open habit.
/// Dragging the handle/header expands today's list in place;
/// the chevron opens the full Habits tab.
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

  // Tiles scrolled up under the header get a fade there too, instead of a
  // hard cut against the progress bar.
  bool _scrolledDown = false;
  final _listScroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _listScroll.addListener(() {
      final scrolledDown = _listScroll.hasClients && _listScroll.offset > 2;
      if (scrolledDown != _scrolledDown) {
        setState(() => _scrolledDown = scrolledDown);
      }
    });
  }

  @override
  void dispose() {
    _listScroll.dispose();
    super.dispose();
  }

  void _onDragUpdate(DragUpdateDetails details) {
    _dragAccum += details.delta.dy;
    if (!_expanded && _dragAccum <= -_dragToggleDistance) {
      setState(() => _expanded = true);
      _dragAccum = 0;
    } else if (_expanded && _dragAccum >= _dragToggleDistance) {
      setState(() {
        _expanded = false;
        _scrolledDown = false;
      });
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
            // Use the design spec's rgba(255,255,255,.5) for the frosted-glass surface.
            color: AppColors.white.withValues(alpha: 0.5),
            // Omit the bottom border where the navigation bar already supplies one.
            // Match the top/side borders and borderRadius to the outer ClipRRect's corners.
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
                          "Today's goal",
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
                            colors: [
                              _scrolledDown ? Colors.transparent : Colors.black,
                              Colors.black,
                              Colors.black,
                              Colors.transparent,
                            ],
                            stops: const [0.0, 0.12, 0.88, 1.0],
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
                                  controller: _listScroll,
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
