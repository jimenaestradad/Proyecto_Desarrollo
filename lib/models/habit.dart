import 'package:flutter/material.dart';
import '../data/color_registry.dart';
import '../data/icon_registry.dart';

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

  /// What today's completion actually paid out, so un-claiming can reverse
  /// the reward exactly instead of recomputing it against since-changed state.
  final int lastAwardedXp;
  final int lastAwardedCoins;

  /// Optional habit lifespan. Stored for the "Set End Date" UI control, but
  /// nothing currently reads these to auto-archive a habit — no archived-habit
  /// view exists yet. Do not treat their presence as working archival.
  final DateTime? startDate;
  final DateTime? endDate;

  final bool isCompletedToday;

  /// Persisted list position — Firestore documents have no inherent order,
  /// unlike the mock's in-memory `List`, so [reorderHabits] needs a real
  /// field to write to. New habits default to insertion order (see
  /// `FirestoreHabitRepository.addHabit`); manual drag-reorder overwrites it
  /// with plain 0..n indices.
  final int order;

  /// Soft-delete flag — deleting a habit archives it instead of removing
  /// the doc, so `habitLogs` (streak/calendar history) survives. No UI
  /// calls this yet (there's no delete button built) — the field exists so
  /// the schema doesn't need a migration once one is.
  final bool archived;

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

    final start = startDate;
    if (start != null &&
        day.isBefore(DateTime(start.year, start.month, start.day))) {
      return false;
    }
    final end = endDate;
    if (end != null && day.isAfter(DateTime(end.year, end.month, end.day))) {
      return false;
    }

    return switch (repeat) {
      HabitRepeat.daily => true,
      HabitRepeat.weekdays => day.weekday <= DateTime.friday,
      HabitRepeat.weekends => day.weekday >= DateTime.saturday,
      HabitRepeat.custom => customDays?.contains(day.weekday) ?? true,
    };
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

  Habit copyWith({
    bool? isCompletedToday,
    double? currentValue,
    int? lastAwardedXp,
    int? lastAwardedCoins,
    int? order,
    bool? archived,
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
    repeat: HabitRepeat.values.byName(json['repeat'] as String),
    type: HabitType.values.byName(json['type'] as String),
    difficulty: HabitDifficulty.values.byName(json['difficulty'] as String),
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
    startDate: _dateFrom(json['startDate']),
    endDate: _dateFrom(json['endDate']),
    isCompletedToday: json['isCompletedToday'] as bool? ?? false,
    order: json['order'] as int? ?? 0,
    archived: json['archived'] as bool? ?? false,
  );
}

/// Reads a date field written by [Habit.toJson]. `cloud_firestore` accepts a
/// raw [DateTime] on write but hands back its own `Timestamp` type on read —
/// calling `.toDate()` dynamically (instead of importing `cloud_firestore`
/// here just for that one type check) keeps this model file backend-agnostic
/// like every other repository interface in `lib/data/`.
DateTime? _dateFrom(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  return (value as dynamic).toDate() as DateTime;
}
