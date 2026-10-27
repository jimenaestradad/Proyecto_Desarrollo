import 'package:flutter/material.dart';
import 'package:nori/data/app_data.dart';
import 'package:nori/data/habit_repository.dart';
import 'package:nori/models/habit.dart';
import 'package:nori/models/nori_user.dart';
import 'package:nori/models/pet.dart';
import 'package:nori/screens/pet/evolution_screen.dart';
import 'package:nori/screens/pet/level_up_screen.dart';
import 'package:nori/utils/remote_errors.dart';

/// The log / claim / un-claim / edit-progress handlers for a screen that
/// shows one day's habits for any date — the Habits list and the Calendar's
/// day sheet, which used to carry two copies of this. Home keeps its own:
/// it is today-only and detects level-ups by diffing before/after state so
/// a claim made on another tab still celebrates.
///
/// The screen supplies the day ([actionDate]) and how to refresh its list
/// ([reloadActionHabits]); everything else is shared. Mix in after
/// [RemoteLoadState].
mixin HabitDayActions<T extends StatefulWidget> on RemoteLoadState<T> {
  /// The day these actions apply to. Read when an action starts, never
  /// after an `await` — the Habits list can change day mid-action.
  DateTime get actionDate;

  /// Re-fetches the screen's habit list for [actionDate].
  Future<void> reloadActionHabits();

  /// Called inside the guarded block after a claim that changed XP or
  /// coins, before the list reloads. A screen that shows the user's totals
  /// refreshes them here and returns the fresh user (reused if a
  /// celebration needs the level); the default leaves them alone.
  Future<NoriUser?> onRewardApplied(HabitRewardResult reward) async => null;

  /// Runs one claim-style call (optionally followed by [then], e.g. setting
  /// a new progress value). The claimHabit/unclaimHabit Cloud Function
  /// already applied the reward server-side — its own flags say whether to
  /// celebrate, so there's no before/after snapshot to diff. The
  /// celebration runs after the guarded block on purpose: it awaits a
  /// dialog the user may leave open past [remoteTimeout].
  Future<void> runClaim(
    Future<HabitRewardResult> Function() claim, {
    Future<void> Function()? then,
  }) async {
    HabitRewardResult? reward;
    Pet? pet;
    NoriUser? user;
    final ok = await guardedAction(() async {
      final result = reward = await claim();
      if (result.xpDelta != 0 || result.coinsDelta != 0) {
        user = await onRewardApplied(result);
      }
      if (result.leveledUp || result.evolved) {
        pet = await AppData.pet.getPet();
        user ??= await AppData.user.getCurrentUser();
      }
      if (then != null) await then();
      await reloadActionHabits();
    });
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
  }

  Future<void> toggleBinary(Habit habit, bool completed) => runClaim(
    () => AppData.habits.setHabitCompletedForDate(
      habit.id,
      actionDate,
      completed,
    ),
  );

  Future<void> logProgress(Habit habit, double amount) async {
    final date = actionDate;
    await guardedAction(() async {
      await AppData.habits.logProgressForDate(habit.id, date, amount);
      await reloadActionHabits();
    });
  }

  Future<void> claim(Habit habit) =>
      runClaim(() => AppData.habits.claimHabitForDate(habit.id, actionDate));

  /// Un-marks the day's claim without touching the logged value — the claim
  /// button turns into this once a habit is completed. The day keeps what
  /// it paid.
  Future<void> unclaim(Habit habit) =>
      runClaim(() => AppData.habits.unclaimHabitForDate(habit.id, actionDate));

  /// Un-claims first whenever the habit was already completed, then applies
  /// the new absolute value — powers the progress card's tap-to-edit /
  /// undo / reset-to-0 dialog.
  Future<void> editProgress(Habit habit, double value) async {
    // Captured: setValue runs after the unclaim round-trip, by which time
    // the screen's day may have changed.
    final date = actionDate;
    Future<void> setValue() =>
        AppData.habits.setProgressForDate(habit.id, date, value);
    if (habit.isCompletedToday) {
      await runClaim(
        () => AppData.habits.unclaimHabitForDate(habit.id, date),
        then: setValue,
      );
      return;
    }
    await guardedAction(() async {
      await setValue();
      await reloadActionHabits();
    });
  }
}
