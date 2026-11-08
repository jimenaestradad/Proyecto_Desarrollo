import 'package:flutter/material.dart';
import '../data/color_registry.dart';
import '../data/habit_history_store.dart' show dayKey;
import '../data/icon_registry.dart';
import '../utils/date_labels.dart';
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

/// How habit progress is measured; see docs/FEATURES.md §2.
/// [quantity] covers both running amounts and accumulated entries.
enum HabitType { binary, quantity, duration, multipleCompletion, limit }

extension HabitTypeLabel on HabitType {
  String get label => switch (this) {
    HabitType.binary => 'Binary',
    HabitType.quantity => 'Quantity',
    HabitType.duration => 'Duration',
    HabitType.multipleCompletion => 'Multiple',
    HabitType.limit => 'Limit / negative',
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

/// An archived stretch using device-local dayKeys, matching habitLogs.
/// [end] is exclusive (restored days are active), or null while still archived;
/// the server applies the same rule.
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
  /// date check, not by flipping [archived].
  final DateTime? startDate;
  final DateTime? endDate;

  final bool isCompletedToday;

  /// Persisted list position for Firestore ordering.
  /// New habits use insertion order; drag-reordering assigns 0..n indices.
  final int order;

  /// Current archive flag used to list archived habits; logs remain intact.
  /// [archivedRanges] determines historical activity so restoration preserves frozen gaps.
  final bool archived;

  /// Every stretch this habit spent archived — see [ArchivedRange] and
  /// [isActiveOn].
  final List<ArchivedRange> archivedRanges;

  /// Creation date, null for mock seeds and set for Firestore habits.
  /// [isScheduledOn] uses it to avoid counting days before creation as missed.
  final DateTime? createdAt;

  bool get hasProgressTracking => type != HabitType.binary;

  /// Per-tap increment: [quickLogAmount], or a default of 5 minutes for duration,
  /// 1 for multiple completion, or 25% of [targetValue] (minimum 1) otherwise.
  /// Not meaningful for binary habits.
  double get quickLogStep {
    final override = quickLogAmount;
    if (override != null) return override;
    switch (type) {
      case HabitType.duration:
        return 5;
      case HabitType.multipleCompletion:
        return 1;
      default:
        return defaultQuickLogStep(targetValue ?? 0);
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

  /// Whether [date] is due under [repeat] and the optional start/end window.
  /// Calendar-day scheduling only; X-times-per-period scheduling remains open.
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

  /// Short human description of [repeat] for lists: "Every day", "Weekdays",
  /// "Weekends" or the chosen days ("Mon · Wed · Fri").
  String get scheduleLabel {
    return switch (repeat) {
      HabitRepeat.daily => 'Every day',
      HabitRepeat.weekdays => 'Weekdays',
      HabitRepeat.weekends => 'Weekends',
      HabitRepeat.custom =>
        customDays == null || customDays!.isEmpty
            ? 'Every day'
            : (customDays!.toList()..sort())
                  .where((day) => day >= 1 && day <= 7)
                  .map(weekdayAbbr)
                  .join(' · '),
    };
  }

  /// Whether [date] is within the start/end window and outside [archivedRanges].
  /// Ignores repeat scheduling; the claimHabit function enforces the same rules.
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

  /// A claimed day or progress reaching [minThreshold] keeps the streak.
  /// The minimum pays no reward; limit habits have no minimum.
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

  /// Applies a day's progress and claim state to this habit definition.
  /// Shared by the Firestore habit and calendar repositories.
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
    icon: IconRegistry.iconFor(json['iconKey'] as String?),
    color: ColorRegistry.colorFor(json['colorKey'] as String?),
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

/// Reads enums by `.name` so enum ordering changes cannot reinterpret stored data.
/// Unknown values use [fallback] instead of failing the whole habit list.
T _enumFromName<T extends Enum>(List<T> values, dynamic value, T fallback) {
  if (value is! String) return fallback;
  for (final entry in values) {
    if (entry.name == value) return entry;
  }
  return fallback;
}

/// The default per-tap amount for target-based habits: 25% of [target], at
/// least 1. Shared with the Add Habit form's hint.
double defaultQuickLogStep(double target) =>
    (target * 0.25).clamp(1, double.infinity).roundToDouble();
