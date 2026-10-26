import 'package:flutter/material.dart';
import '../data/color_registry.dart';
import '../data/habit_history_store.dart' show dayKey;
import '../data/icon_registry.dart';
import '../utils/firestore_date.dart';
import 'habit_day_state.dart';

enum HabitRepeat { daily, weekdays, weekends, custom }

extension HabitRepeatLabel on HabitRepeat {
  String get label => switch (this) {
    HabitRepeat.daily => 'Daily',
    HabitRepeat.weekdays => 'Weekdays',
    HabitRepeat.weekends => 'Weekends',
    HabitRepeat.custom => 'Custom',
  };
}

/// How a habit's progress is measured. See docs/FEATURES.md §2.
///
/// [quantity] covers both a single running amount (e.g. 250→1000ml water)
/// and a sum of entries logged across a period (e.g. 45 min creative work/
/// week, logged in pieces) — those two behaved identically everywhere in
/// this codebase (same progress/claim/quick-log logic), so they were merged
/// into one type instead of staying as `quantity` + `cumulative`.
enum HabitType { binary, quantity, duration, multipleCompletion, limit }

extension HabitTypeLabel on HabitType {
  String get label => switch (this) {
    HabitType.binary => 'Binary',
    HabitType.quantity => 'Quantity',
    HabitType.duration => 'Duration',
    HabitType.multipleCompletion => 'Multiple',
    HabitType.limit => 'Limit / Negative',
  };

  String get description => switch (this) {
    HabitType.binary => 'Simple yes / no',
    HabitType.quantity => 'Track an amount, e.g. ml, pages, or minutes/week',
    HabitType.duration => 'Track minutes or hours',
    HabitType.multipleCompletion => 'Count out of N, e.g. 2/3 meals',
    HabitType.limit => 'Stay under a max',
  };
}

/// Starting XP tier picked at habit creation. Values are mock MVP defaults
/// adopted from the Stitch mock, not a settled balance decision — see
/// docs/OPEN_DECISIONS.md "XP balancing".
enum HabitDifficulty { easy, medium, hard }

extension HabitDifficultyXp on HabitDifficulty {
  int get baseXp => switch (this) {
    HabitDifficulty.easy => 10,
    HabitDifficulty.medium => 20,
    HabitDifficulty.hard => 30,
  };

  int get baseCoins => baseXp ~/ 2;

  String get label => switch (this) {
    HabitDifficulty.easy => 'Easy',
    HabitDifficulty.medium => 'Medium',
    HabitDifficulty.hard => 'Hard',
  };
}

/// How much of a habit's reward was earned today.
enum HabitRewardTier { none, min, full }

extension HabitRewardTierFraction on HabitRewardTier {
  double get xpFraction => switch (this) {
    HabitRewardTier.none => 0.0,
    HabitRewardTier.min => 0.75,
    HabitRewardTier.full => 1.0,
  };
}

/// One stretch of time a habit was archived. [start]/[end] are device-local
/// `dayKey`s (the same convention as `habitLogs`, see docs/BACKEND.md);
/// [end] is exclusive — the day it was restored counts as active again —
/// and null while it's still archived. The `isArchivedOn` helper in
/// functions/src/habitTransaction.ts applies the identical rule server-side.
class ArchivedRange {
  const ArchivedRange({required this.start, this.end});

  final String start;
  final String? end;

  bool contains(String key) =>
      key.compareTo(start) >= 0 && (end == null || key.compareTo(end!) < 0);

  Map<String, dynamic> toJson() => {'start': start, 'end': end};

  static ArchivedRange? fromJson(dynamic json) {
    if (json is! Map) return null;
    final start = json['start'];
    if (start is! String) return null;
    final end = json['end'];
    return ArchivedRange(start: start, end: end is String ? end : null);
  }
}

class Habit {
  const Habit({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.xpReward,
    required this.coinReward,
    required this.repeat,
    required this.type,
    this.difficulty = HabitDifficulty.medium,
    this.targetValue,
    this.unit,
    this.minThreshold,
    this.quickLogAmount,
    this.currentValue = 0,
    this.adaptiveMultiplier = 1.0,
    this.customDays,
    this.allowVacationFreeze = true,
    this.lastAwardedXp = 0,
    this.lastAwardedCoins = 0,
    this.startDate,
    this.endDate,
    this.isCompletedToday = false,
    this.order = 0,
    this.archived = false,
    this.archivedRanges = const [],
    this.createdAt,
  });

  final String id;
  final String name;
  final String subtitle;
  final IconData icon;
  final Color color;
  final int xpReward;
  final int coinReward;
  final HabitRepeat repeat;
  final HabitType type;
  final HabitDifficulty difficulty;

  /// Null for [HabitType.binary]. The value to reach (or, for [HabitType.limit],
  /// the ceiling to stay under).
  final double? targetValue;
  final String? unit;

  /// Partial-credit threshold. Not meaningful for binary or limit habits.
  final double? minThreshold;

  /// User-set override for [quickLogStep]. Null means "use the default
  /// heuristic" — see [quickLogStep].
  final double? quickLogAmount;

  /// Today's logged progress toward [targetValue].
  final double currentValue;

  /// Static per-habit multiplier standing in for adaptive difficulty — see
  /// docs/OPEN_DECISIONS.md "Adaptive-XP formula and adjustment window",
  /// which this does not attempt to resolve. Clamped 0.5–1.5.
  final double adaptiveMultiplier;

  /// ISO weekday ints (1 = Monday), only meaningful when [repeat] is custom.
  final Set<int>? customDays;

  final bool allowVacationFreeze;

  /// What today's first claim paid out. Kept after an unclaim, since each
  /// day pays once (docs/BACKEND.md, unclaimHabit) — a re-claim pays nothing.
  final int lastAwardedXp;
  final int lastAwardedCoins;

  bool get rewardPaid => lastAwardedXp > 0 || lastAwardedCoins > 0;

  /// Optional habit lifespan (the "Set End Date" control). Outside this
  /// window a habit acts archived (FEATURES.md §2) — see [isActiveOn] — by
  /// date check, not by flipping [archived]; no archived-habit view exists yet.
  final DateTime? startDate;
  final DateTime? endDate;

  final bool isCompletedToday;

  /// Persisted list position — Firestore documents have no inherent order,
  /// unlike the mock's in-memory `List`, so [reorderHabits] needs a real
  /// field to write to. New habits default to insertion order (see
  /// `FirestoreHabitRepository.addHabit`); manual drag-reorder overwrites it
  /// with plain 0..n indices.
  final int order;

  /// Whether the habit is archived right now — hidden from today onward, its
  /// `habitLogs` (streak/calendar history) kept. Only used to list archived
  /// habits; which *days* count is [archivedRanges]' job, so restoring a
  /// habit later doesn't retroactively turn the archived stretch into
  /// missed days. See docs/BACKEND.md, "Deleting vs. archiving a habit".
  final bool archived;

  /// Every stretch this habit spent archived — see [ArchivedRange] and
  /// [isActiveOn].
  final List<ArchivedRange> archivedRanges;

  /// When this habit was created. Null for the mock's seed habits (which
  /// have always "existed"); always set for a real, Firestore-created
  /// habit — see [isScheduledOn], which uses it as an implicit lower bound
  /// so a brand-new habit doesn't retroactively count as "missed" on days
  /// before it existed.
  final DateTime? createdAt;

  bool get hasProgressTracking => type != HabitType.binary;

  /// The amount a single quick-log tap adds. [quickLogAmount] if the user
  /// set one; otherwise a heuristic default: 5 minutes for [HabitType.
  /// duration], 1 completion for [HabitType.multipleCompletion], or 25% of
  /// [targetValue] (minimum 1) for every other progress-tracked type. Not
  /// meaningful for binary habits.
  double get quickLogStep {
    final override = quickLogAmount;
    if (override != null) return override;
    switch (type) {
      case HabitType.duration:
        return 5;
      case HabitType.multipleCompletion:
        return 1;
      default:
        final target = targetValue ?? 0;
        return (target * 0.25).clamp(1, double.infinity).roundToDouble();
    }
  }

  /// Display label for [quickLogStep], e.g. "+250 ml", "+5m", "+1".
  String get quickLogLabel {
    final amount = quickLogStep;
    switch (type) {
      case HabitType.duration:
        return '+${amount.round()}m';
      case HabitType.multipleCompletion:
        return '+${amount.round()}';
      default:
        final u = unit ?? '';
        return '+${amount.round()} $u'.trim();
    }
  }

  /// Whether this habit is due on [date], per its [repeat] schedule and
  /// optional [startDate]/[endDate] window. Drives both today's list and any
  /// past day's list, so history never shows a habit on a day it was never
  /// scheduled (e.g. an M/W/F gym habit on a Tuesday).
  ///
  /// Note this is calendar-day scheduling only. FEATURES.md §5 also describes
  /// X-times-per-period habits ("5x any day this week"), which have no
  /// calendar-day answer — that scheduling style is still open, see
  /// docs/OPEN_DECISIONS.md.
  bool isScheduledOn(DateTime date) {
    final day = DateTime(date.year, date.month, date.day);

    final created = createdAt;
    if (created != null &&
        day.isBefore(DateTime(created.year, created.month, created.day))) {
      return false;
    }

    if (!isActiveOn(day)) return false;

    return switch (repeat) {
      HabitRepeat.daily => true,
      HabitRepeat.weekdays => day.weekday <= DateTime.friday,
      HabitRepeat.weekends => day.weekday >= DateTime.saturday,
      HabitRepeat.custom => customDays?.contains(day.weekday) ?? true,
    };
  }

  /// Whether [date] falls inside the optional [startDate]/[endDate] window
  /// and outside every [archivedRanges] stretch. Unlike [isScheduledOn] this
  /// ignores the repeat schedule, so today's list can hide an ended or
  /// archived habit while still showing unscheduled ones. The claimHabit
  /// Cloud Function enforces the same rules.
  bool isActiveOn(DateTime date) {
    final day = DateTime(date.year, date.month, date.day);
    if (archivedRanges.isNotEmpty) {
      final key = dayKey(day);
      if (archivedRanges.any((range) => range.contains(key))) return false;
    }
    final start = startDate;
    if (start != null &&
        day.isBefore(DateTime(start.year, start.month, start.day))) {
      return false;
    }
    final end = endDate;
    if (end != null && day.isAfter(DateTime(end.year, end.month, end.day))) {
      return false;
    }
    return true;
  }

  /// "Stay under a max" instead of "reach a target".
  bool get isInverted => type == HabitType.limit;

  double get progressFraction {
    if (type == HabitType.binary) return isCompletedToday ? 1 : 0;
    final target = targetValue;
    if (target == null || target == 0) return 0;
    return (currentValue / target).clamp(0, 1);
  }

  double? get minThresholdFraction {
    final target = targetValue;
    final min = minThreshold;
    if (isInverted || target == null || target == 0 || min == null) return null;
    return (min / target).clamp(0, 1);
  }

  bool get isTargetMet => switch (type) {
    HabitType.binary => isCompletedToday,
    HabitType.limit => targetValue != null && currentValue <= targetValue!,
    _ => targetValue != null && currentValue >= targetValue!,
  };

  bool get isMinMet =>
      !isInverted && minThreshold != null && currentValue >= minThreshold!;

  /// Whether this day counts toward streaks: claimed, or — even unclaimed —
  /// logged up to [minThreshold]. Reaching the minimum pays nothing (Complete
  /// always snaps to the full target, see MockHabitRepository._claimValue),
  /// so this is its whole job: "didn't finish, but showed up" keeps the
  /// streak, per FEATURES.md §3. Limit habits have no minimum.
  bool get keptStreak => isCompletedToday || isMinMet;

  HabitRewardTier get rewardTier {
    if (isTargetMet) return HabitRewardTier.full;
    if (isInverted) return HabitRewardTier.none;
    return isMinMet ? HabitRewardTier.min : HabitRewardTier.none;
  }

  /// XP/coins today's state would pay out. Deliberately `base × adaptive ×
  /// tier` only — no cadence multiplier, since docs/OPEN_DECISIONS.md defers
  /// "exact cadence multipliers" and this doesn't attempt to resolve it.
  ({int xp, int coins}) computeReward() {
    final fraction = rewardTier.xpFraction;
    return (
      xp: (xpReward * adaptiveMultiplier * fraction).round(),
      coins: (coinReward * fraction).round(),
    );
  }

  /// Applies a specific day's logged progress/claim state onto this
  /// definition — the shape every screen expects a [Habit] in (see
  /// [MockHabitRepository]'s own private version of this, which this
  /// mirrors for the real Firestore-backed repositories in
  /// `habit_repository.dart` and `calendar_repository.dart`, so both share
  /// one implementation instead of three copies).
  Habit hydrate(HabitDayState state) => copyWith(
    currentValue: state.value,
    isCompletedToday: state.claimed,
    lastAwardedXp: state.awardedXp,
    lastAwardedCoins: state.awardedCoins,
  );

  Habit copyWith({
    bool? isCompletedToday,
    double? currentValue,
    int? lastAwardedXp,
    int? lastAwardedCoins,
    int? order,
    bool? archived,
    List<ArchivedRange>? archivedRanges,
  }) {
    return Habit(
      id: id,
      name: name,
      subtitle: subtitle,
      icon: icon,
      color: color,
      xpReward: xpReward,
      coinReward: coinReward,
      repeat: repeat,
      type: type,
      difficulty: difficulty,
      targetValue: targetValue,
      unit: unit,
      minThreshold: minThreshold,
      quickLogAmount: quickLogAmount,
      currentValue: currentValue ?? this.currentValue,
      adaptiveMultiplier: adaptiveMultiplier,
      customDays: customDays,
      allowVacationFreeze: allowVacationFreeze,
      lastAwardedXp: lastAwardedXp ?? this.lastAwardedXp,
      lastAwardedCoins: lastAwardedCoins ?? this.lastAwardedCoins,
      startDate: startDate,
      endDate: endDate,
      isCompletedToday: isCompletedToday ?? this.isCompletedToday,
      order: order ?? this.order,
      archived: archived ?? this.archived,
      archivedRanges: archivedRanges ?? this.archivedRanges,
      createdAt: createdAt,
    );
  }

  /// The document body for `/users/{uid}/habits/{habitId}` — `id` is the
  /// path segment, not a field, so it's deliberately left out here (see
  /// [fromJson]). See docs/BACKEND.md "Firestore schema".
  Map<String, dynamic> toJson() => {
    'name': name,
    'subtitle': subtitle,
    'iconKey': IconRegistry.keyFor(icon),
    'colorKey': ColorRegistry.keyFor(color),
    'xpReward': xpReward,
    'coinReward': coinReward,
    'repeat': repeat.name,
    'type': type.name,
    'difficulty': difficulty.name,
    'targetValue': targetValue,
    'unit': unit,
    'minThreshold': minThreshold,
    'quickLogAmount': quickLogAmount,
    'currentValue': currentValue,
    'adaptiveMultiplier': adaptiveMultiplier,
    'customDays': customDays?.toList(),
    'allowVacationFreeze': allowVacationFreeze,
    'lastAwardedXp': lastAwardedXp,
    'lastAwardedCoins': lastAwardedCoins,
    'startDate': startDate,
    'endDate': endDate,
    'isCompletedToday': isCompletedToday,
    'order': order,
    'archived': archived,
    'archivedRanges': [for (final range in archivedRanges) range.toJson()],
    'createdAt': createdAt,
  };

  /// [id] comes from the Firestore document snapshot's `.id`, not from
  /// [json] itself — mirrors [toJson] leaving it out of the map.
  factory Habit.fromJson(String id, Map<String, dynamic> json) => Habit(
    id: id,
    name: json['name'] as String,
    subtitle: json['subtitle'] as String,
    icon: IconRegistry.iconFor(json['iconKey'] as String),
    color: ColorRegistry.colorFor(json['colorKey'] as String),
    xpReward: json['xpReward'] as int,
    coinReward: json['coinReward'] as int,
    repeat: _enumFromName(
      HabitRepeat.values,
      json['repeat'],
      HabitRepeat.daily,
    ),
    type: _enumFromName(HabitType.values, json['type'], HabitType.binary),
    difficulty: _enumFromName(
      HabitDifficulty.values,
      json['difficulty'],
      HabitDifficulty.medium,
    ),
    targetValue: (json['targetValue'] as num?)?.toDouble(),
    unit: json['unit'] as String?,
    minThreshold: (json['minThreshold'] as num?)?.toDouble(),
    quickLogAmount: (json['quickLogAmount'] as num?)?.toDouble(),
    currentValue: (json['currentValue'] as num? ?? 0).toDouble(),
    adaptiveMultiplier: (json['adaptiveMultiplier'] as num? ?? 1.0).toDouble(),
    customDays: (json['customDays'] as List<dynamic>?)
        ?.map((day) => day as int)
        .toSet(),
    allowVacationFreeze: json['allowVacationFreeze'] as bool? ?? true,
    lastAwardedXp: json['lastAwardedXp'] as int? ?? 0,
    lastAwardedCoins: json['lastAwardedCoins'] as int? ?? 0,
    startDate: dateFromFirestoreValue(json['startDate']),
    endDate: dateFromFirestoreValue(json['endDate']),
    isCompletedToday: json['isCompletedToday'] as bool? ?? false,
    order: json['order'] as int? ?? 0,
    archived: json['archived'] as bool? ?? false,
    archivedRanges: [
      for (final raw in json['archivedRanges'] as List<dynamic>? ?? const [])
        ?ArchivedRange.fromJson(raw),
    ],
    createdAt: dateFromFirestoreValue(json['createdAt']),
  );
}

/// Matches [value] against an enum's `.name` (see docs/BACKEND.md
/// "Conventions" — enums are stored as `.name`, never index ints, since
/// index order silently changes if someone adds a value later). Falls back
/// to [fallback] instead of throwing on a value this build doesn't
/// recognize — e.g. an older client reading a `HabitType` a newer client
/// added — rather than crashing the whole habit list over one bad field.
T _enumFromName<T extends Enum>(List<T> values, dynamic value, T fallback) {
  if (value is! String) return fallback;
  for (final entry in values) {
    if (entry.name == value) return entry;
  }
  return fallback;
}
