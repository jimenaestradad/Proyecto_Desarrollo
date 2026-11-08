import 'package:flutter/material.dart';
import 'package:nori/data/app_data.dart';
import 'package:nori/data/habit_local_edits.dart';
import 'package:nori/data/habit_repository.dart';
import 'package:nori/models/habit.dart';
import 'package:nori/models/nori_user.dart';
import 'package:nori/models/pet.dart';
import 'package:nori/screens/customization/customization_screen.dart';
import 'package:nori/screens/pet/evolution_screen.dart';
import 'package:nori/screens/pet/gift_screen.dart';
import 'package:nori/screens/pet/level_up_screen.dart';
import 'package:nori/utils/remote_errors.dart';
import 'package:nori/widgets/reward_burst.dart';

/// Shows a habit change on screen at once and confirms it with the server in
/// the background, so a tap never waits on a network round trip. A failed
/// action (or the last one finishing) re-syncs the list from the server.
mixin OptimisticHabits<T extends StatefulWidget> on RemoteLoadState<T> {
  /// Swaps [change] into the on-screen copy of the habit with [habitId].
  void applyHabitChange(String habitId, Habit Function(Habit) change);

  /// Re-fetches the screen's habit list. It must drop its result when
  /// [editStamp] moved while it was fetching, because the fetched list
  /// predates a newer local change.
  Future<void> reloadActionHabits();

  /// Captures the on-screen habits so [restoreHabitSnapshot] can put them
  /// back if a server call fails. The result is opaque to this mixin, so a
  /// screen can include whatever it needs to restore it safely (the Habits
  /// list includes the day, and skips the restore if the day has changed).
  Object? snapshotHabits();

  /// Puts back what [snapshotHabits] captured.
  void restoreHabitSnapshot(Object snapshot);

  /// The habits as they were before the first action now in flight. A failed
  /// action restores this at once, so the undo never depends on the network
  /// (the re-read below fails too when the server is unreachable). Dropped
  /// once nothing is in flight.
  Object? _baseline;

  int _pending = 0;
  int _rewardsPending = 0;
  int _edits = 0;

  /// Whether a claim is still being confirmed, so the XP and coin totals on
  /// screen are about to change. Badges show a spinner meanwhile.
  bool get rewardSyncing => _rewardsPending > 0;

  /// Bumps with every local change; see [reloadActionHabits].
  int get editStamp => _edits;

  /// Applies [change] now, then runs [server]. Returns whether it succeeded.
  /// [paysReward] marks a claim or unclaim, which moves XP and coins.
  Future<bool> optimisticHabitEdit(
    String habitId,
    Habit Function(Habit) change,
    Future<void> Function() server, {
    bool paysReward = false,
  }) async {
    _edits++;
    if (_pending == 0) _baseline = snapshotHabits();
    _pending++;
    if (paysReward) _rewardsPending++;
    applyHabitChange(habitId, change);
    final ok = await guardedAction(server);
    _pending--;
    if (paysReward) _rewardsPending--;
    final baseline = _baseline;
    if (_pending == 0) _baseline = null;
    if (mounted) {
      setState(() {
        if (!ok && baseline != null) restoreHabitSnapshot(baseline);
      });
    }
    // Only the last action in flight reloads: an earlier one would fetch a
    // list that doesn't yet include the later actions.
    if (mounted && (!ok || _pending == 0)) {
      await guardedAction(reloadActionHabits);
    }
    return ok;
  }
}

/// Shared date-specific log, claim, unclaim and progress-edit handlers.
/// Screens supply [actionDate] and [OptimisticHabits] hooks; mix in after that mixin.
/// Home handles today's actions separately to detect celebrations across tabs.
mixin HabitDayActions<T extends StatefulWidget> on OptimisticHabits<T> {
  /// The day these actions apply to. Read when an action starts, never
  /// after an `await`: the Habits list can change day mid-action.
  DateTime get actionDate;

  /// Called inside the guarded block after every claim or unclaim, which can
  /// move XP, coins and the streak (an unclaim keeps its payout but can still
  /// break the day). A screen that shows the user's totals refreshes them here
  /// and returns the fresh user (reused if a celebration needs the level); the
  /// default leaves them alone.
  Future<NoriUser?> onRewardApplied(HabitRewardResult reward) async => null;

  /// Called after a progress edit that didn't complete the habit but did
  /// change whether the day keeps the streak (reaching or dropping below the
  /// minimum). Refreshes the user in the background; failures are ignored,
  /// the next load corrects it.
  Future<void> onStreakMayHaveChanged() async {}

  /// Runs a claim-style call, optionally followed by [then]; server flags drive celebration.
  /// Celebrate outside the guarded block because dialogs may outlast [remoteTimeout].
  Future<void> runClaim(
    Habit habit,
    Habit Function(Habit) change,
    Future<HabitRewardResult> Function() claim, {
    Future<void> Function()? then,
  }) async {
    HabitRewardResult? reward;
    Pet? pet;
    NoriUser? user;
    RewardBurst.showForClaim(context, before: habit, after: change(habit));
    final ok = await optimisticHabitEdit(habit.id, change, () async {
      final result = reward = await claim();
      user = await onRewardApplied(result);
      if (result.leveledUp ||
          result.evolved ||
          result.giftedAccessoryId != null) {
        pet = await AppData.pet.getPet();
        user ??= await AppData.user.getCurrentUser();
      }
      if (then != null) await then();
    }, paysReward: true);
    final result = reward;
    final celebratedPet = pet;
    final celebratedUser = user;
    if (!ok ||
        !mounted ||
        result == null ||
        celebratedPet == null ||
        celebratedUser == null) {
      return;
    }
    if (result.evolved) {
      await showEvolutionCelebration(
        context,
        petName: celebratedPet.name,
        stage: celebratedPet.stage,
      );
    } else if (result.leveledUp) {
      await showLevelUpCelebration(
        context,
        level: celebratedUser.level,
        petName: celebratedPet.name,
      );
    }
    final gift = result.giftedAccessoryId;
    if (gift != null && mounted) {
      final tryItOn = await showGiftCelebration(
        context,
        accessoryId: gift,
        petName: celebratedPet.name,
      );
      if (tryItOn && mounted) {
        await Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const CustomizationScreen()));
      }
    }
  }

  Future<void> toggleBinary(Habit habit, bool completed) => runClaim(
    habit,
    (h) => completed ? h.claimedLocally() : h.unclaimedLocally(),
    () => AppData.habits.setHabitCompletedForDate(
      habit.id,
      actionDate,
      completed,
    ),
  );

  /// Adds [amount] to today's progress; reaching the target completes the
  /// habit by itself.
  Future<void> logProgress(Habit habit, double amount) async {
    final date = actionDate;
    if (habit.reachesTarget(habit.currentValue + amount)) {
      PreClaimValues.remember(habit.id, date, habit.currentValue);
      await runClaim(
        habit,
        (h) => h.withLogged(amount).claimedLocally(),
        () async {
          await AppData.habits.logProgressForDate(habit.id, date, amount);
          return AppData.habits.claimHabitForDate(habit.id, date);
        },
      );
      return;
    }
    await optimisticHabitEdit(
      habit.id,
      (h) => h.withLogged(amount),
      () => AppData.habits.logProgressForDate(habit.id, date, amount),
    );
    await _refreshStreakIfKeptChanged(habit, habit.withLogged(amount));
  }

  Future<void> claim(Habit habit) {
    final date = actionDate;
    if (habit.completesAtTarget) {
      PreClaimValues.remember(habit.id, date, habit.currentValue);
    }
    return runClaim(
      habit,
      (h) => h.claimedLocally(),
      () => AppData.habits.claimHabitForDate(habit.id, date),
    );
  }

  /// Un-marks the day's claim — the claim button turns into this once a
  /// habit is completed. The day keeps what it paid, and a progress habit
  /// goes back to where it was before Complete.
  Future<void> unclaim(Habit habit) {
    final date = actionDate;
    final restore = PreClaimValues.take(habit.id, date);
    final restoring = restore != null && restore != habit.currentValue;
    return runClaim(
      habit,
      (h) => h.unclaimedLocally(restoreValue: restoring ? restore : null),
      () => AppData.habits.unclaimHabitForDate(habit.id, date),
      then: restoring
          ? () => AppData.habits.setProgressForDate(habit.id, date, restore)
          : null,
    );
  }

  /// Applies an absolute value from the tap-to-edit / undo / reset-to-0
  /// dialog. Un-claims first if the habit was completed, and completes it
  /// again if the new value reaches the target.
  Future<void> editProgress(Habit habit, double value) async {
    // Captured: the screen's day may change during the round trips.
    final date = actionDate;
    final reaches = habit.reachesTarget(value);
    // A completed progress habit already sits at its target.
    if (habit.isCompletedToday && reaches) return;

    if (habit.isCompletedToday) {
      PreClaimValues.forget(habit.id, date);
      await runClaim(
        habit,
        (h) => h.unclaimedLocally().withProgress(value),
        () => AppData.habits.unclaimHabitForDate(habit.id, date),
        then: () => AppData.habits.setProgressForDate(habit.id, date, value),
      );
      return;
    }
    if (reaches) {
      PreClaimValues.remember(habit.id, date, habit.currentValue);
      await runClaim(
        habit,
        (h) => h.withProgress(value).claimedLocally(),
        () async {
          await AppData.habits.setProgressForDate(habit.id, date, value);
          return AppData.habits.claimHabitForDate(habit.id, date);
        },
      );
      return;
    }
    await optimisticHabitEdit(
      habit.id,
      (h) => h.withProgress(value),
      () => AppData.habits.setProgressForDate(habit.id, date, value),
    );
    await _refreshStreakIfKeptChanged(habit, habit.withProgress(value));
  }

  Future<void> _refreshStreakIfKeptChanged(Habit before, Habit after) async {
    if (before.keptStreak == after.keptStreak) return;
    try {
      await onStreakMayHaveChanged();
    } catch (_) {
      // Best effort: the streak badge corrects itself on the next load.
    }
  }
}
