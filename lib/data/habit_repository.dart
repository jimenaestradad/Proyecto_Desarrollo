import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/habit.dart';
import '../models/habit_day_state.dart';
import '../models/pet.dart';
import '../theme/app_colors.dart';
import 'cloud_functions_client.dart';
import 'habit_history_store.dart';
import 'signed_in_uid.dart';

/// What a completion/claim/un-claim action just paid out (or clawed back).
/// With [FirestoreHabitRepository] the claimHabit/unclaimHabit Cloud Function
/// has already applied it to the user and pet docs — screens only reload.
/// [leveledUp]/[evolved] come from the function's before/after values, so a
/// screen can celebrate without holding its own pre-claim snapshot.
class HabitRewardResult {
  const HabitRewardResult(
    this.xpDelta,
    this.coinsDelta, {
    this.leveledUp = false,
    this.evolved = false,
  });

  static const none = HabitRewardResult(0, 0);

  final int xpDelta;
  final int coinsDelta;
  final bool leveledUp;
  final bool evolved;
}

abstract class HabitRepository {
  Future<List<Habit>> getTodayHabits();

  /// Binary habits only. Awards the full reward on `true`; on `false`
  /// (un-checking) returns the exact negative of what was last awarded so
  /// XP/coins reverse cleanly instead of being recomputed against
  /// since-changed state.
  Future<HabitRewardResult> setHabitCompleted(String habitId, bool completed);

  /// Quantity/Duration/Cumulative/MultipleCompletion/Limit quick-log. Never
  /// awards anything by itself — per docs/FEATURES.md §3, logging progress
  /// alone doesn't earn XP, only claiming a completed habit does.
  Future<void> logProgress(String habitId, double amount);

  /// The "Complete" / "Mark Day Safe" button for non-binary habits. No-op
  /// (returns [HabitRewardResult.none]) if already claimed today.
  Future<HabitRewardResult> claimHabit(String habitId);

  Future<void> addHabit(Habit habit);

  /// Replaces a habit's definition (name, target, schedule, etc.) in place.
  /// Today's live `currentValue`/`isCompletedToday`/`lastAwarded*` are always
  /// preserved from the stored habit, no matter what [habit] carries for
  /// those fields — callers (e.g. editing a habit from a past day, where the
  /// only `Habit` object on hand is hydrated with *that day's* state) don't
  /// need to, and can't safely, carry them forward themselves.
  Future<void> updateHabit(Habit habit);

  /// Reverses a non-binary claim, mirroring [setHabitCompleted]'s `false`
  /// branch, so today's progress can be edited again. No-op if not claimed.
  Future<HabitRewardResult> unclaimHabit(String habitId);

  /// Sets today's logged progress to an absolute value (vs. [logProgress]'s
  /// delta) — powers undo / manual correction / reset-to-0. No-op once
  /// claimed; callers should [unclaimHabit] first.
  Future<void> setProgress(String habitId, double value);

  /// Persists a manual drag-reorder of the day's habit list.
  Future<void> reorderHabits(List<String> orderedIds);

  /// Habits scheduled on [date] (per [Habit.isScheduledOn]), hydrated with
  /// that date's logged progress/claim state. For today this is exactly
  /// [getTodayHabits] (which — unlike this method — does not filter by
  /// schedule, so the two can differ in which habits appear even though
  /// they agree on today's own state).
  ///
  /// Dates older than the tracked history window come back with zero
  /// state; there is no "we don't know" distinct from "nothing was logged".
  Future<List<Habit>> getHabitsForDate(DateTime date);

  /// [setHabitCompleted] for an arbitrary past date. Binary habits only.
  Future<HabitRewardResult> setHabitCompletedForDate(
    String habitId,
    DateTime date,
    bool completed,
  );

  /// [logProgress] for an arbitrary past date.
  Future<void> logProgressForDate(String habitId, DateTime date, double amount);

  /// [claimHabit] for an arbitrary past date.
  Future<HabitRewardResult> claimHabitForDate(String habitId, DateTime date);

  /// [unclaimHabit] for an arbitrary past date.
  Future<HabitRewardResult> unclaimHabitForDate(String habitId, DateTime date);

  /// [setProgress] for an arbitrary past date.
  Future<void> setProgressForDate(String habitId, DateTime date, double value);

  /// [getHabitsForDate] for every day in [start, end] (inclusive), keyed by
  /// `dateOnly` day — for callers that walk a whole window (achievements,
  /// profile stats) and would otherwise make one round trip per day.
  Future<Map<DateTime, List<Habit>>> getHabitsForRange(
    DateTime start,
    DateTime end,
  );

  /// Habits currently archived ([Habit.archived]), for the Archived list.
  Future<List<Habit>> getArchivedHabits();

  /// Hides a habit from today onward, keeping all of its history. See
  /// docs/BACKEND.md, "Deleting vs. archiving a habit".
  Future<void> archiveHabit(String habitId);

  /// Brings an archived habit back from today. The archived stretch stays
  /// recorded in [Habit.archivedRanges], so those days never read as missed.
  Future<void> restoreHabit(String habitId);

  /// How many days have any logged progress or a claim for this habit —
  /// [deleteHabit] is only allowed at or under [kMaxDeletableActiveDays].
  Future<int> activeDayCount(String habitId);

  /// Removes a habit and all of its logs for good, taking back whatever
  /// its claims paid. Only for habits with almost no history (see
  /// [activeDayCount]) — everything else is archived instead.
  Future<HabitRewardResult> deleteHabit(String habitId);
}

/// A habit with activity on more days than this can't be deleted, only
/// archived. "Very little data" per valevasqc (2026-09-30), a default worth
/// revisiting. Keep in sync with MAX_DELETABLE_ACTIVE_DAYS in
/// functions/src/deleteHabit.ts, which enforces it server-side.
const kMaxDeletableActiveDays = 2;

class MockHabitRepository implements HabitRepository {
  MockHabitRepository() {
    history.seedHistory(_habits);
  }

  /// Past-day state, shared with [MockCalendarRepository] so the calendar's
  /// day colours and this list can't disagree. Today's own state lives on
  /// [_habits] directly, as it always has — this only covers other days.
  final HabitHistoryStore history = HabitHistoryStore();

  bool _isToday(DateTime date) => dateOnly(date) == dateOnly(DateTime.now());

  final List<Habit> _habits = [
    const Habit(
      id: 'drink-water',
      name: 'Drink Water',
      subtitle: 'Target: 1,000 ml',
      icon: Icons.water_drop,
      color: AppColors.sky,
      xpReward: 10,
      coinReward: 5,
      repeat: HabitRepeat.daily,
      type: HabitType.quantity,
      difficulty: HabitDifficulty.easy,
      targetValue: 1000,
      unit: 'ml',
      minThreshold: 500,
      currentValue: 750,
    ),
    const Habit(
      id: 'gym-session',
      name: 'Gym Session',
      subtitle: 'Upper Body · 45 mins',
      icon: Icons.fitness_center,
      color: AppColors.mossLight,
      xpReward: 30,
      coinReward: 15,
      repeat: HabitRepeat.custom,
      customDays: {1, 3, 5},
      type: HabitType.duration,
      difficulty: HabitDifficulty.hard,
      targetValue: 45,
      unit: 'mins',
      adaptiveMultiplier: 1.2,
    ),
    const Habit(
      id: 'read',
      name: 'Read 10 mins',
      subtitle: 'Atomic Habits',
      icon: Icons.menu_book,
      color: AppColors.blushPink,
      xpReward: 15,
      coinReward: 5,
      repeat: HabitRepeat.daily,
      type: HabitType.binary,
      difficulty: HabitDifficulty.easy,
    ),
    const Habit(
      id: 'study-react',
      name: 'Study React',
      subtitle: 'Hooks & Context',
      icon: Icons.code,
      color: AppColors.mustardLight,
      xpReward: 20,
      coinReward: 10,
      repeat: HabitRepeat.weekdays,
      type: HabitType.quantity,
      difficulty: HabitDifficulty.medium,
      targetValue: 60,
      unit: 'mins',
      minThreshold: 30,
      currentValue: 45,
    ),
    const Habit(
      id: 'healthy-meals',
      name: 'Healthy Meals',
      subtitle: '3 healthy meals today',
      icon: Icons.restaurant,
      color: AppColors.blush,
      xpReward: 10,
      coinReward: 5,
      repeat: HabitRepeat.daily,
      type: HabitType.multipleCompletion,
      difficulty: HabitDifficulty.easy,
      targetValue: 3,
      unit: 'meals',
      currentValue: 1,
    ),
    const Habit(
      id: 'social-media',
      name: 'Social Media',
      subtitle: 'Keep under 2h today',
      icon: Icons.smartphone,
      color: AppColors.linenAlt,
      xpReward: 20,
      coinReward: 10,
      repeat: HabitRepeat.daily,
      type: HabitType.limit,
      difficulty: HabitDifficulty.medium,
      targetValue: 120,
      unit: 'min',
      currentValue: 45,
    ),
  ];

  @override
  Future<List<Habit>> getTodayHabits() async =>
      List.unmodifiable(_habits.where((h) => h.isActiveOn(DateTime.now())));

  @override
  Future<HabitRewardResult> setHabitCompleted(
    String habitId,
    bool completed,
  ) async {
    final index = _habits.indexWhere((h) => h.id == habitId);
    if (index == -1) return HabitRewardResult.none;
    final habit = _habits[index];

    if (completed) {
      if (habit.rewardPaid) {
        _habits[index] = habit.copyWith(isCompletedToday: true);
        return HabitRewardResult.none;
      }
      final reward = habit.computeReward();
      _habits[index] = habit.copyWith(
        isCompletedToday: true,
        lastAwardedXp: reward.xp,
        lastAwardedCoins: reward.coins,
      );
      return HabitRewardResult(reward.xp, reward.coins);
    }

    // Pay once per day: the reward stays paid (docs/BACKEND.md, unclaimHabit).
    _habits[index] = habit.copyWith(isCompletedToday: false);
    return HabitRewardResult.none;
  }

  @override
  Future<void> logProgress(String habitId, double amount) async {
    final index = _habits.indexWhere((h) => h.id == habitId);
    if (index == -1) return;
    final habit = _habits[index];
    if (habit.isCompletedToday) return;
    final target = habit.targetValue;
    final nextValue = target == null
        ? habit.currentValue + amount
        : (habit.currentValue + amount).clamp(
            0,
            habit.isInverted ? target * 2 : target,
          );
    _habits[index] = habit.copyWith(currentValue: nextValue.toDouble());
  }

  /// The value a claim actually completes at. Pressing "Complete" is a
  /// shortcut that finishes the habit outright — like a binary habit's
  /// checkbox — so a progress-tracked habit snaps up to its target instead
  /// of claiming whatever partial number happens to be logged. Limit habits
  /// are excluded: their target is a ceiling to stay under, not a floor to
  /// jump to, so "Mark Day Safe" claims the value as actually logged.
  double _claimValue(Habit habit) {
    if (habit.isInverted) return habit.currentValue;
    final target = habit.targetValue;
    if (target == null || habit.currentValue >= target) {
      return habit.currentValue;
    }
    return target;
  }

  @override
  Future<HabitRewardResult> claimHabit(String habitId) async {
    final index = _habits.indexWhere((h) => h.id == habitId);
    if (index == -1) return HabitRewardResult.none;
    final habit = _habits[index];
    if (habit.isCompletedToday) return HabitRewardResult.none;

    final snapshot = habit.copyWith(currentValue: _claimValue(habit));
    if (habit.rewardPaid) {
      _habits[index] = snapshot.copyWith(isCompletedToday: true);
      return HabitRewardResult.none;
    }
    final reward = snapshot.computeReward();
    _habits[index] = snapshot.copyWith(
      isCompletedToday: true,
      lastAwardedXp: reward.xp,
      lastAwardedCoins: reward.coins,
    );
    return HabitRewardResult(reward.xp, reward.coins);
  }

  @override
  Future<void> addHabit(Habit habit) async {
    _habits.add(habit);
  }

  @override
  Future<void> updateHabit(Habit habit) async {
    final index = _habits.indexWhere((h) => h.id == habit.id);
    if (index == -1) return;
    final live = _habits[index];
    _habits[index] = habit.copyWith(
      currentValue: live.currentValue,
      isCompletedToday: live.isCompletedToday,
      lastAwardedXp: live.lastAwardedXp,
      lastAwardedCoins: live.lastAwardedCoins,
    );
  }

  @override
  Future<HabitRewardResult> unclaimHabit(String habitId) async {
    final index = _habits.indexWhere((h) => h.id == habitId);
    if (index == -1) return HabitRewardResult.none;
    final habit = _habits[index];
    if (!habit.isCompletedToday) return HabitRewardResult.none;

    _habits[index] = habit.copyWith(isCompletedToday: false);
    return HabitRewardResult.none;
  }

  @override
  Future<void> setProgress(String habitId, double value) async {
    final index = _habits.indexWhere((h) => h.id == habitId);
    if (index == -1) return;
    final habit = _habits[index];
    if (habit.isCompletedToday) return;
    final target = habit.targetValue;
    final clamped = target == null
        ? value.clamp(0.0, double.infinity)
        : value.clamp(0.0, habit.isInverted ? target * 2 : target);
    _habits[index] = habit.copyWith(currentValue: clamped);
  }

  @override
  Future<void> reorderHabits(List<String> orderedIds) async {
    final byId = {for (final h in _habits) h.id: h};
    final reordered = [
      for (final id in orderedIds)
        if (byId[id] != null) byId[id]!,
    ];
    for (final h in _habits) {
      if (!orderedIds.contains(h.id)) reordered.add(h);
    }
    _habits
      ..clear()
      ..addAll(reordered);
  }

  @override
  Future<List<Habit>> getHabitsForDate(DateTime date) async {
    if (_isToday(date)) return getTodayHabits();
    final day = dateOnly(date);
    return [
      for (final definition in _habits)
        if (definition.isScheduledOn(day))
          definition.hydrate(history.stateFor(definition.id, day)),
    ];
  }

  @override
  Future<HabitRewardResult> setHabitCompletedForDate(
    String habitId,
    DateTime date,
    bool completed,
  ) async {
    if (_isToday(date)) return setHabitCompleted(habitId, completed);
    final index = _habits.indexWhere((h) => h.id == habitId);
    if (index == -1) return HabitRewardResult.none;
    final definition = _habits[index];
    final day = dateOnly(date);
    final previous = history.stateFor(habitId, day);

    if (completed) {
      if (previous.claimed) return HabitRewardResult.none;
      if (previous.rewardPaid) {
        history.write(habitId, day, previous.copyWith(claimed: true));
        return HabitRewardResult.none;
      }
      final reward = definition
          .copyWith(isCompletedToday: true)
          .computeReward();
      history.write(
        habitId,
        day,
        previous.copyWith(
          claimed: true,
          awardedXp: reward.xp,
          awardedCoins: reward.coins,
        ),
      );
      return HabitRewardResult(reward.xp, reward.coins);
    }

    if (!previous.claimed) return HabitRewardResult.none;
    history.write(habitId, day, previous.copyWith(claimed: false));
    return HabitRewardResult.none;
  }

  @override
  Future<void> logProgressForDate(
    String habitId,
    DateTime date,
    double amount,
  ) async {
    if (_isToday(date)) return logProgress(habitId, amount);
    final index = _habits.indexWhere((h) => h.id == habitId);
    if (index == -1) return;
    final definition = _habits[index];
    final day = dateOnly(date);
    final previous = history.stateFor(habitId, day);
    if (previous.claimed) return;
    final target = definition.targetValue;
    final nextValue = target == null
        ? previous.value + amount
        : (previous.value + amount).clamp(
            0,
            definition.isInverted ? target * 2 : target,
          );
    history.write(habitId, day, previous.copyWith(value: nextValue.toDouble()));
  }

  @override
  Future<HabitRewardResult> claimHabitForDate(
    String habitId,
    DateTime date,
  ) async {
    if (_isToday(date)) return claimHabit(habitId);
    final index = _habits.indexWhere((h) => h.id == habitId);
    if (index == -1) return HabitRewardResult.none;
    final definition = _habits[index];
    final day = dateOnly(date);
    final previous = history.stateFor(habitId, day);
    if (previous.claimed) return HabitRewardResult.none;

    final completedValue = _claimValue(
      definition.copyWith(currentValue: previous.value),
    );
    if (previous.rewardPaid) {
      history.write(
        habitId,
        day,
        previous.copyWith(value: completedValue, claimed: true),
      );
      return HabitRewardResult.none;
    }
    final reward = definition
        .copyWith(currentValue: completedValue, isCompletedToday: true)
        .computeReward();
    history.write(
      habitId,
      day,
      previous.copyWith(
        value: completedValue,
        claimed: true,
        awardedXp: reward.xp,
        awardedCoins: reward.coins,
      ),
    );
    return HabitRewardResult(reward.xp, reward.coins);
  }

  @override
  Future<HabitRewardResult> unclaimHabitForDate(
    String habitId,
    DateTime date,
  ) async {
    if (_isToday(date)) return unclaimHabit(habitId);
    final day = dateOnly(date);
    final previous = history.stateFor(habitId, day);
    if (!previous.claimed) return HabitRewardResult.none;
    history.write(habitId, day, previous.copyWith(claimed: false));
    return HabitRewardResult.none;
  }

  @override
  Future<void> setProgressForDate(
    String habitId,
    DateTime date,
    double value,
  ) async {
    if (_isToday(date)) return setProgress(habitId, value);
    final index = _habits.indexWhere((h) => h.id == habitId);
    if (index == -1) return;
    final definition = _habits[index];
    final day = dateOnly(date);
    final previous = history.stateFor(habitId, day);
    if (previous.claimed) return;
    final target = definition.targetValue;
    final clamped = target == null
        ? value.clamp(0.0, double.infinity)
        : value.clamp(0.0, definition.isInverted ? target * 2 : target);
    history.write(habitId, day, previous.copyWith(value: clamped));
  }

  @override
  Future<Map<DateTime, List<Habit>>> getHabitsForRange(
    DateTime start,
    DateTime end,
  ) async {
    final result = <DateTime, List<Habit>>{};
    for (
      var day = dateOnly(start);
      !day.isAfter(dateOnly(end));
      day = addDays(day, 1)
    ) {
      result[day] = await getHabitsForDate(day);
    }
    return result;
  }

  @override
  Future<List<Habit>> getArchivedHabits() async =>
      List.unmodifiable(_habits.where((h) => h.archived));

  @override
  Future<void> archiveHabit(String habitId) async {
    final index = _habits.indexWhere((h) => h.id == habitId);
    if (index == -1 || _habits[index].archived) return;
    final habit = _habits[index];
    _habits[index] = habit.copyWith(
      archived: true,
      archivedRanges: archiveRangesAfterArchiving(habit.archivedRanges),
    );
  }

  @override
  Future<void> restoreHabit(String habitId) async {
    final index = _habits.indexWhere((h) => h.id == habitId);
    if (index == -1 || !_habits[index].archived) return;
    final habit = _habits[index];
    _habits[index] = habit.copyWith(
      archived: false,
      archivedRanges: archiveRangesAfterRestoring(habit.archivedRanges),
    );
  }

  @override
  Future<int> activeDayCount(String habitId) async {
    final index = _habits.indexWhere((h) => h.id == habitId);
    if (index == -1) return 0;
    final today = _habits[index];
    var count = today.currentValue > 0 || today.isCompletedToday ? 1 : 0;
    final now = dateOnly(DateTime.now());
    for (var back = 1; back <= history.seedDayCount; back++) {
      final state = history.stateFor(habitId, addDays(now, -back));
      if (state.value > 0 || state.claimed) count++;
    }
    return count;
  }

  /// In-memory stand-in: no user/XP state lives here to take back, so it
  /// just drops the habit (its seeded history entries become unreachable).
  @override
  Future<HabitRewardResult> deleteHabit(String habitId) async {
    _habits.removeWhere((h) => h.id == habitId);
    return HabitRewardResult.none;
  }
}

/// Real Firestore-backed implementation of the plain-CRUD subset of
/// [HabitRepository] — create/update/reorder, and progress logging for any
/// day, today included. A habit doc holds only its *definition*; a day's
/// logged progress (`currentValue`/`isCompletedToday`/`lastAwardedXp`/
/// `lastAwardedCoins`) always lives in `habitLogs`, keyed by date — there is
/// no separate "today" storage to fall out of sync at midnight. See
/// docs/BACKEND.md "Data sprint" for what's in scope here vs. deferred:
///
/// - [setHabitCompleted], [claimHabit], [unclaimHabit] (and their `*ForDate`
///   twins) mint/burn XP and coins — `firestore.rules` denies clients from
///   writing those fields directly on purpose (see the rules file), so they
///   call the claimHabit/unclaimHabit Cloud Functions instead, which update
///   the log, user, pet and inventory in one transaction.
class FirestoreHabitRepository implements HabitRepository {
  /// Every document lives under the signed-in user — see
  /// docs/BACKEND.md "Firestore schema". Throws if nobody's signed in.
  String get _uid => requireSignedInUid('FirestoreHabitRepository');

  /// A `CollectionReference` is just a *pointer* to a path — it does no
  /// network call by itself. The actual read/write happens on `.get()`,
  /// `.set()`, `.update()` etc. below.
  CollectionReference<Map<String, dynamic>> get _habits => FirebaseFirestore
      .instance
      .collection('users')
      .doc(_uid)
      .collection('habits');

  /// Flat, not nested under `_habits` — see docs/BACKEND.md's "Why
  /// `habitLogs` is a flat collection" for why: it's what makes [logsInRange]
  /// below a single range query instead of one query per habit.
  CollectionReference<Map<String, dynamic>> get _habitLogs => FirebaseFirestore
      .instance
      .collection('users')
      .doc(_uid)
      .collection('habitLogs');

  /// Every `habitLogs` entry for the days [start]..[end] (inclusive), keyed
  /// by its document id (`{dayKey}_{habitId}`) — **one** query, not one per
  /// day. Filters on the `dayKey` string (`yyyy-mm-dd` sorts chronologically),
  /// not the `date` Timestamp: that one is the device's local midnight when
  /// written, so after a time-zone change a day's log could fall outside that
  /// day's query and vanish from the calendar. [FirestoreCalendarRepository] in `calendar_repository.dart` is
  /// built entirely on this: fetch the whole visible range once, then derive
  /// day statuses/streaks/stats in memory, instead of the N+1 query pattern
  /// [MockCalendarRepository] gets away with only because its "queries" are
  /// free in-memory map lookups.
  ///
  /// Public (not `_`-prefixed) specifically so a different file can call it
  /// — `HabitRepository` itself has no "batch fetch a range" concept, since
  /// that's a Firestore-specific optimization, not something every backend
  /// needs to expose the same way.
  Future<Map<String, HabitDayState>> logsInRange(
    DateTime start,
    DateTime end,
  ) async {
    final snapshot = await _habitLogs
        .where('dayKey', isGreaterThanOrEqualTo: dayKey(start))
        .where('dayKey', isLessThanOrEqualTo: dayKey(end))
        .get();
    return {
      for (final doc in snapshot.docs)
        doc.id: HabitDayState.fromJson(doc.data()),
    };
  }

  /// A single habit's definition, or `null` if it doesn't exist — used by
  /// [logProgressForDate]/[setProgressForDate], which only need one habit's
  /// `targetValue`/`isInverted` to clamp against, not the whole collection.
  Future<Habit?> _fetchDefinition(String habitId) async {
    final doc = await _habits.doc(habitId).get();
    if (!doc.exists) return null;
    return Habit.fromJson(doc.id, doc.data()!);
  }

  /// Every habit definition, archived and ended ones included, ordered by
  /// `order`. Deliberately unfiltered: whether a habit counts on a given day
  /// is [Habit.isActiveOn]'s call (its archived stretches, its end date), so
  /// an archived habit still shows up on the past days it was active instead
  /// of vanishing from history. Public for [FirestoreCalendarRepository].
  Future<List<Habit>> fetchAllDefinitions() async {
    final snapshot = await _habits.orderBy('order').get();
    return [
      for (final doc in snapshot.docs) Habit.fromJson(doc.id, doc.data()),
    ];
  }

  /// The subset of `Habit.toJson()` that actually lives on the habit doc.
  /// `currentValue`/`isCompletedToday`/`lastAwardedXp`/`lastAwardedCoins`
  /// live in `habitLogs` instead — for *every* day, including today, not
  /// just past ones (that's the fix for the midnight-rollover bug: a habit
  /// doc is now a pure, dateless definition, so there's nothing on it that
  /// needs resetting when the calendar day changes). `order`/`archived`/
  /// `createdAt` are each owned by a different write path — `reorderHabits`,
  /// a future archive/delete flow, and [addHabit] respectively — not by
  /// editing a habit's own definition, so [updateHabit] excludes them too.
  /// `adaptiveMultiplier` is left out as well: claimHabit recomputes and
  /// stores it on every claim (functions/src/adaptiveXp.ts), so a client
  /// write would only ever put back a stale value.
  Map<String, dynamic> _definitionFields(Map<String, dynamic> json) => {
    'name': json['name'],
    'subtitle': json['subtitle'],
    'iconKey': json['iconKey'],
    'colorKey': json['colorKey'],
    'xpReward': json['xpReward'],
    'coinReward': json['coinReward'],
    'repeat': json['repeat'],
    'type': json['type'],
    'difficulty': json['difficulty'],
    'targetValue': json['targetValue'],
    'unit': json['unit'],
    'minThreshold': json['minThreshold'],
    'quickLogAmount': json['quickLogAmount'],
    'customDays': json['customDays'],
    'allowVacationFreeze': json['allowVacationFreeze'],
    'startDate': json['startDate'],
    'endDate': json['endDate'],
  };

  @override
  Future<List<Habit>> getTodayHabits() async {
    // Structurally identical to getHabitsForDate(today), minus the schedule
    // filter — getTodayHabits shows every active habit regardless of
    // whether it's "due" today (see the interface doc comment), while
    // getHabitsForDate below only returns what's actually scheduled.
    final definitions = await fetchAllDefinitions();
    final today = dateOnly(DateTime.now());
    final logs = await logsInRange(today, today);
    return hydrateDay(today, [
      for (final definition in definitions)
        if (definition.isActiveOn(today)) definition,
    ], logs);
  }

  @override
  Future<void> addHabit(Habit habit) async {
    // .doc(habit.id).set(data) writes (or overwrites) the document at that
    // exact id — habit.id already comes from IdGenerator client-side (see
    // add_habit_screen.dart), so there's no server-assigned id to wait on.
    await _habits.doc(habit.id).set({
      ..._definitionFields(habit.toJson()),
      // New habits sort after everything existing. A millisecond timestamp
      // is a simpler source of "always bigger than what's there" than
      // counting existing docs first — reorderHabits overwrites it with
      // plain 0..n indices the moment a user actually drags to reorder.
      'order': DateTime.now().millisecondsSinceEpoch,
      'archived': false,
      // Read by Habit.isScheduledOn as an implicit lower bound, so a
      // brand-new habit doesn't retroactively count as "missed" on
      // calendar days before it existed.
      'createdAt': DateTime.now(),
    });
  }

  @override
  Future<void> updateHabit(Habit habit) async {
    // .update() only touches the keys given — everything else on the
    // stored document is left alone, which is what makes this safe to call
    // without needing to preserve anything: there's no currentValue/
    // isCompletedToday/lastAwarded* on the habit doc to clobber anymore
    // (see _definitionFields), and order/archived/createdAt are each owned
    // by a different write path than "edit this habit's definition".
    await _habits.doc(habit.id).update(_definitionFields(habit.toJson()));
  }

  @override
  Future<void> reorderHabits(List<String> orderedIds) async {
    // A WriteBatch groups several writes into one atomic unit, like a
    // transaction, but without a read step first — right for this, since
    // reordering doesn't need to know any doc's current contents.
    final batch = FirebaseFirestore.instance.batch();
    for (var i = 0; i < orderedIds.length; i++) {
      batch.update(_habits.doc(orderedIds[i]), {'order': i});
    }
    await batch.commit();
  }

  // logProgress/setProgress are just logProgressForDate/setProgressForDate
  // for today — there's no separate "today" storage anymore (that was the
  // midnight-rollover bug: see docs/KNOWN_ISSUES.md), so today needs no
  // special-cased transaction of its own.
  @override
  Future<void> logProgress(String habitId, double amount) =>
      logProgressForDate(habitId, DateTime.now(), amount);

  @override
  Future<void> setProgress(String habitId, double value) =>
      setProgressForDate(habitId, DateTime.now(), value);

  @override
  Future<HabitRewardResult> setHabitCompleted(String habitId, bool completed) =>
      setHabitCompletedForDate(habitId, DateTime.now(), completed);

  @override
  Future<HabitRewardResult> claimHabit(String habitId) =>
      claimHabitForDate(habitId, DateTime.now());

  @override
  Future<HabitRewardResult> unclaimHabit(String habitId) =>
      unclaimHabitForDate(habitId, DateTime.now());

  /// Calls the claimHabit/unclaimHabit Cloud Function for [date]. The day is
  /// sent as the device-local key + local midnight, never derived on the
  /// server (docs/BACKEND.md, "Dates and the day-rollover rule"). Throws
  /// [CloudFunctionFailure] with a user-facing message on any failure.
  Future<HabitRewardResult> _callRewardFunction(
    String function,
    String habitId,
    DateTime date,
  ) async {
    final day = dateOnly(date);
    final result = await callCloudFunction(function, {
      'habitId': habitId,
      'dayKey': dayKey(day),
      'dayStartMillis': day.millisecondsSinceEpoch,
    });
    int asInt(Object? value) => (value as num?)?.toInt() ?? 0;
    int stageIndex(Object? name) =>
        PetEvolutionStage.values.indexWhere((stage) => stage.name == name);
    return HabitRewardResult(
      asInt(result['xpDelta']),
      asInt(result['coinsDelta']),
      leveledUp: asInt(result['level']) > asInt(result['previousLevel']),
      evolved:
          stageIndex(result['petStage']) >
          stageIndex(result['previousPetStage']),
    );
  }

  @override
  Future<List<Habit>> getHabitsForDate(DateTime date) async {
    final day = dateOnly(date);
    final definitions = await fetchAllDefinitions();
    final scheduled = [
      for (final definition in definitions)
        if (definition.isScheduledOn(day)) definition,
    ];
    if (scheduled.isEmpty) return const [];

    final logs = await logsInRange(day, day);
    return hydrateDay(day, scheduled, logs);
  }

  @override
  Future<HabitRewardResult> setHabitCompletedForDate(
    String habitId,
    DateTime date,
    bool completed,
  ) => completed
      ? claimHabitForDate(habitId, date)
      : unclaimHabitForDate(habitId, date);

  @override
  Future<void> logProgressForDate(
    String habitId,
    DateTime date,
    double amount,
  ) => _writeProgress(habitId, date, (current) => current + amount);

  @override
  Future<HabitRewardResult> claimHabitForDate(String habitId, DateTime date) =>
      _callRewardFunction('claimHabit', habitId, date);

  @override
  Future<HabitRewardResult> unclaimHabitForDate(
    String habitId,
    DateTime date,
  ) => _callRewardFunction('unclaimHabit', habitId, date);

  @override
  Future<void> setProgressForDate(
    String habitId,
    DateTime date,
    double value,
  ) => _writeProgress(habitId, date, (_) => value);

  /// The one write path behind [logProgressForDate] (add to the day's
  /// value) and [setProgressForDate] (replace it): [next] maps the day's
  /// current value to the one to store, and the result is clamped by
  /// [clampProgress]. Does nothing if the habit doesn't exist or the day is
  /// already claimed — a claimed day's value only changes by un-claiming
  /// first, since the claim fixed it (claimValue in functions/src/rewards.ts).
  Future<void> _writeProgress(
    String habitId,
    DateTime date,
    double Function(double current) next,
  ) async {
    // A single doc read, not the whole collection — MockHabitRepository's
    // equivalent (`_habits.indexWhere`) is a free in-memory scan, but that's
    // not true here, and unlike firstWhere this also matches the mock's
    // no-op-if-the-habit-doesn't-exist behavior instead of throwing.
    final definition = await _fetchDefinition(habitId);
    if (definition == null) return;
    final day = dateOnly(date);
    final ref = _habitLogs.doc('${dayKey(day)}_$habitId');

    await FirebaseFirestore.instance.runTransaction((tx) async {
      final snapshot = await tx.get(ref);
      final previous = snapshot.exists
          ? HabitDayState.fromJson(snapshot.data()!)
          : HabitDayState.empty;
      if (previous.claimed) return;
      // set(), not update() — the doc may not exist yet if this is the
      // first time progress was logged on this past day. habitId/dayKey/
      // date are re-sent every time alongside the changed value, but
      // firestore.rules' hasOnly(['value']) still allows it: diff() only
      // flags keys whose *value* actually changed, and those three don't.
      tx.set(ref, {
        ...previous
            .copyWith(value: clampProgress(definition, next(previous.value)))
            .toJson(),
        'habitId': habitId,
        'dayKey': dayKey(day),
        'date': day,
      });
    });
  }

  @override
  Future<Map<DateTime, List<Habit>>> getHabitsForRange(
    DateTime start,
    DateTime end,
  ) async {
    // Two queries for the whole window — same approach as
    // FirestoreCalendarRepository.
    final definitions = await fetchAllDefinitions();
    final logs = await logsInRange(start, end);
    final result = <DateTime, List<Habit>>{};
    for (
      var day = dateOnly(start);
      !day.isAfter(dateOnly(end));
      day = addDays(day, 1)
    ) {
      result[day] = hydrateScheduled(day, definitions, logs);
    }
    return result;
  }

  @override
  Future<List<Habit>> getArchivedHabits() async => [
    for (final habit in await fetchAllDefinitions())
      if (habit.archived) habit,
  ];

  @override
  Future<void> archiveHabit(String habitId) async {
    final habit = await _fetchDefinition(habitId);
    if (habit == null || habit.archived) return;
    await _habits.doc(habitId).update({
      'archived': true,
      'archivedRanges': [
        for (final range in archiveRangesAfterArchiving(habit.archivedRanges))
          range.toJson(),
      ],
    });
  }

  @override
  Future<void> restoreHabit(String habitId) async {
    final habit = await _fetchDefinition(habitId);
    if (habit == null || !habit.archived) return;
    await _habits.doc(habitId).update({
      'archived': false,
      'archivedRanges': [
        for (final range in archiveRangesAfterRestoring(habit.archivedRanges))
          range.toJson(),
      ],
    });
  }

  @override
  Future<int> activeDayCount(String habitId) async {
    // Single-field equality — Firestore indexes it automatically.
    final snapshot = await _habitLogs
        .where('habitId', isEqualTo: habitId)
        .get();
    // Same test as deleteHabit's server-side count (functions/src/
    // deleteHabit.ts): a day that paid and was then un-claimed keeps its
    // payout, so it still counts as active even with value 0.
    return snapshot.docs.where((doc) {
      final state = HabitDayState.fromJson(doc.data());
      return state.value > 0 ||
          state.claimed ||
          state.awardedXp > 0 ||
          state.awardedCoins > 0;
    }).length;
  }

  /// The deleteHabit Cloud Function — deleting logs that hold claims takes
  /// XP/coins back, which is currency, so it can't be a client write
  /// (firestore.rules denies deleting a habit doc outright).
  @override
  Future<HabitRewardResult> deleteHabit(String habitId) async {
    final result = await callCloudFunction('deleteHabit', {'habitId': habitId});
    int asInt(Object? value) => value is num ? value.toInt() : 0;
    return HabitRewardResult(
      asInt(result['xpDelta']),
      asInt(result['coinsDelta']),
    );
  }
}

/// [ranges] with a new open-ended stretch starting today — what archiving
/// writes. Shared by both repositories so they can't disagree.
List<ArchivedRange> archiveRangesAfterArchiving(List<ArchivedRange> ranges) => [
  ...ranges,
  ArchivedRange(start: dayKey(DateTime.now())),
];

/// [ranges] with the open stretch closed at today (exclusive, so today is
/// active again). A same-day archive + restore leaves an empty stretch,
/// which is dropped rather than stored.
List<ArchivedRange> archiveRangesAfterRestoring(List<ArchivedRange> ranges) {
  final today = dayKey(DateTime.now());
  return [
    for (final range in ranges)
      if (range.end != null)
        range
      else if (range.start.compareTo(today) < 0)
        ArchivedRange(start: range.start, end: today),
  ];
}

/// [habits] (definitions) hydrated with [day]'s entry from [logs] — the
/// shape every screen expects (see [Habit.hydrate]). [logs] is keyed by log
/// doc id (`{dayKey}_{habitId}`), as returned by
/// [FirestoreHabitRepository.logsInRange]; a habit with no entry for the day
/// gets [HabitDayState.empty]. Shared by the habit and calendar repositories
/// so a day's list and that day's calendar colour are built the same way.
List<Habit> hydrateDay(
  DateTime day,
  Iterable<Habit> habits,
  Map<String, HabitDayState> logs,
) {
  final key = dayKey(day);
  return [
    for (final habit in habits)
      habit.hydrate(logs['${key}_${habit.id}'] ?? HabitDayState.empty),
  ];
}

/// [hydrateDay] for just the [definitions] scheduled on [day]
/// ([Habit.isScheduledOn]) — which habits a day's list and calendar cell
/// show, as opposed to [FirestoreHabitRepository.getTodayHabits], which
/// shows every active one. Reads from an already-fetched [logs] map, so
/// loops over many days ([FirestoreCalendarRepository]'s month, streak and
/// stats) cost no extra queries. Pass every habit as [definitions], archived
/// and ended ones included
/// ([FirestoreHabitRepository.fetchAllDefinitions]): taking only today's
/// active habits would erase an ended habit from the past days it was
/// actually on.
List<Habit> hydrateScheduled(
  DateTime day,
  Iterable<Habit> definitions,
  Map<String, HabitDayState> logs,
) => hydrateDay(day, [
  for (final definition in definitions)
    if (definition.isScheduledOn(day)) definition,
], logs);

/// [value] limited to what [habit] can log: never negative, and no more
/// than its target — or twice the target for a limit habit, whose target is
/// a ceiling it can exceed (the card then reads "Limit Exceeded"). A habit
/// with no target has no upper limit.
double clampProgress(Habit habit, double value) {
  final target = habit.targetValue;
  final cap = target == null
      ? double.infinity
      : (habit.isInverted ? target * 2 : target);
  return value.clamp(0.0, cap).toDouble();
}
