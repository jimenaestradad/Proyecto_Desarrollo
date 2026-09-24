import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/habit.dart';
import '../models/habit_day_state.dart';
import '../theme/app_colors.dart';
import 'habit_history_store.dart';

/// What a completion/claim/un-claim action just paid out (or clawed back).
/// Screens apply this to [UserRepository.addXp]/[addCoins].
class HabitRewardResult {
  const HabitRewardResult(this.xpDelta, this.coinsDelta);

  static const none = HabitRewardResult(0, 0);

  final int xpDelta;
  final int coinsDelta;
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
}

class MockHabitRepository implements HabitRepository {
  MockHabitRepository() {
    history.seedHistory(_habits);
  }

  /// Past-day state, shared with [MockCalendarRepository] so the calendar's
  /// day colours and this list can't disagree. Today's own state lives on
  /// [_habits] directly, as it always has — this only covers other days.
  final HabitHistoryStore history = HabitHistoryStore();

  bool _isToday(DateTime date) =>
      dateOnly(date) == dateOnly(DateTime.now());

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
  Future<List<Habit>> getTodayHabits() async => List.unmodifiable(_habits);

  @override
  Future<HabitRewardResult> setHabitCompleted(
    String habitId,
    bool completed,
  ) async {
    final index = _habits.indexWhere((h) => h.id == habitId);
    if (index == -1) return HabitRewardResult.none;
    final habit = _habits[index];

    if (completed) {
      final reward = habit.computeReward();
      _habits[index] = habit.copyWith(
        isCompletedToday: true,
        lastAwardedXp: reward.xp,
        lastAwardedCoins: reward.coins,
      );
      return HabitRewardResult(reward.xp, reward.coins);
    }

    final reversedXp = -habit.lastAwardedXp;
    final reversedCoins = -habit.lastAwardedCoins;
    _habits[index] = habit.copyWith(
      isCompletedToday: false,
      lastAwardedXp: 0,
      lastAwardedCoins: 0,
    );
    return HabitRewardResult(reversedXp, reversedCoins);
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
        : (habit.currentValue + amount).clamp(0, habit.isInverted ? target * 2 : target);
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
    if (target == null || habit.currentValue >= target) return habit.currentValue;
    return target;
  }

  @override
  Future<HabitRewardResult> claimHabit(String habitId) async {
    final index = _habits.indexWhere((h) => h.id == habitId);
    if (index == -1) return HabitRewardResult.none;
    final habit = _habits[index];
    if (habit.isCompletedToday) return HabitRewardResult.none;

    final snapshot = habit.copyWith(currentValue: _claimValue(habit));
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

    final reversedXp = -habit.lastAwardedXp;
    final reversedCoins = -habit.lastAwardedCoins;
    _habits[index] = habit.copyWith(
      isCompletedToday: false,
      lastAwardedXp: 0,
      lastAwardedCoins: 0,
    );
    return HabitRewardResult(reversedXp, reversedCoins);
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
      final reward = definition.copyWith(isCompletedToday: true).computeReward();
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
    final reversedXp = -previous.awardedXp;
    final reversedCoins = -previous.awardedCoins;
    history.write(
      habitId,
      day,
      previous.copyWith(claimed: false, awardedXp: 0, awardedCoins: 0),
    );
    return HabitRewardResult(reversedXp, reversedCoins);
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
    final reversedXp = -previous.awardedXp;
    final reversedCoins = -previous.awardedCoins;
    history.write(
      habitId,
      day,
      previous.copyWith(claimed: false, awardedXp: 0, awardedCoins: 0),
    );
    return HabitRewardResult(reversedXp, reversedCoins);
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
///   writing those fields directly on purpose (see the rules file), so
///   these become Cloud Function calls in the Backend sprint, not plain
///   Firestore writes. Left as [UnimplementedError] here on purpose, so a
///   call site that isn't updated yet fails loudly instead of silently
///   doing nothing.
class FirestoreHabitRepository implements HabitRepository {
  /// Every document lives under the signed-in user — see
  /// docs/BACKEND.md "Firestore schema". Throws if nobody's signed in.
  String get _uid {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw StateError('FirestoreHabitRepository used with no signed-in user');
    }
    return user.uid;
  }

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

  /// Every `habitLogs` entry with `date` in [start, end] (inclusive), keyed
  /// by its document id (`{dayKey}_{habitId}`) — **one** query, not one per
  /// day. [FirestoreCalendarRepository] in `calendar_repository.dart` is
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
        .where('date', isGreaterThanOrEqualTo: dateOnly(start))
        .where('date', isLessThanOrEqualTo: dateOnly(end))
        .get();
    return {
      for (final doc in snapshot.docs) doc.id: HabitDayState.fromJson(doc.data()),
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

  /// Every non-archived habit definition, ordered by `order` — the shared
  /// base [getTodayHabits] and [getHabitsForDate] both hydrate. Filtering
  /// `archived` here in Dart, instead of a Firestore `where`, avoids needing
  /// a composite index (equality + orderBy on a different field) at a scale
  /// — a handful of habits per user — where that index would buy nothing.
  Future<List<Habit>> _fetchDefinitions() async {
    final snapshot = await _habits.orderBy('order').get();
    return [
      for (final doc in snapshot.docs) Habit.fromJson(doc.id, doc.data()),
    ].where((habit) => !habit.archived).toList();
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
    'adaptiveMultiplier': json['adaptiveMultiplier'],
    'customDays': json['customDays'],
    'allowVacationFreeze': json['allowVacationFreeze'],
    'startDate': json['startDate'],
    'endDate': json['endDate'],
  };

  @override
  Future<List<Habit>> getTodayHabits() async {
    // Structurally identical to getHabitsForDate(today), minus the schedule
    // filter — getTodayHabits shows every non-archived habit regardless of
    // whether it's "due" today (see the interface doc comment), while
    // getHabitsForDate below only returns what's actually scheduled.
    final definitions = await _fetchDefinitions();
    final today = dateOnly(DateTime.now());
    final logs = await logsInRange(today, today);
    return [
      for (final definition in definitions)
        definition.hydrate(
          logs['${dayKey(today)}_${definition.id}'] ?? HabitDayState.empty,
        ),
    ];
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
      throw UnimplementedError('claimHabit Cloud Function not wired up yet');

  @override
  Future<HabitRewardResult> claimHabit(String habitId) =>
      throw UnimplementedError('claimHabit Cloud Function not wired up yet');

  @override
  Future<HabitRewardResult> unclaimHabit(String habitId) =>
      throw UnimplementedError('unclaimHabit Cloud Function not wired up yet');

  @override
  Future<List<Habit>> getHabitsForDate(DateTime date) async {
    final day = dateOnly(date);
    final definitions = await _fetchDefinitions();
    final scheduled = [
      for (final definition in definitions)
        if (definition.isScheduledOn(day)) definition,
    ];
    if (scheduled.isEmpty) return const [];

    final logs = await logsInRange(day, day);
    return [
      for (final definition in scheduled)
        definition.hydrate(logs['${dayKey(day)}_${definition.id}'] ?? HabitDayState.empty),
    ];
  }

  @override
  Future<HabitRewardResult> setHabitCompletedForDate(
    String habitId,
    DateTime date,
    bool completed,
  ) => throw UnimplementedError('claimHabit Cloud Function not wired up yet');

  @override
  Future<void> logProgressForDate(String habitId, DateTime date, double amount) async {
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
      final target = definition.targetValue;
      final nextValue = target == null
          ? previous.value + amount
          : (previous.value + amount).clamp(
              0,
              definition.isInverted ? target * 2 : target,
            );
      // set(), not update() — the doc may not exist yet if this is the
      // first time progress was logged on this past day. habitId/dayKey/
      // date are re-sent every time alongside the changed value, but
      // firestore.rules' hasOnly(['value']) still allows it: diff() only
      // flags keys whose *value* actually changed, and those three don't.
      tx.set(ref, {
        ...previous.copyWith(value: nextValue.toDouble()).toJson(),
        'habitId': habitId,
        'dayKey': dayKey(day),
        'date': day,
      });
    });
  }

  @override
  Future<HabitRewardResult> claimHabitForDate(String habitId, DateTime date) =>
      throw UnimplementedError('claimHabit Cloud Function not wired up yet');

  @override
  Future<HabitRewardResult> unclaimHabitForDate(String habitId, DateTime date) =>
      throw UnimplementedError('unclaimHabit Cloud Function not wired up yet');

  @override
  Future<void> setProgressForDate(String habitId, DateTime date, double value) async {
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
      final target = definition.targetValue;
      final clamped = target == null
          ? value.clamp(0.0, double.infinity)
          : value.clamp(0.0, definition.isInverted ? target * 2 : target);
      tx.set(ref, {
        ...previous.copyWith(value: clamped).toJson(),
        'habitId': habitId,
        'dayKey': dayKey(day),
        'date': day,
      });
    });
  }
}
