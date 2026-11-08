/// One habit's logged state on one date, separate from its [Habit] definition.
/// Corresponds to storage keyed by habit id and date.
class HabitDayState {
  const HabitDayState({
    this.value = 0,
    this.claimed = false,
    this.awardedXp = 0,
    this.awardedCoins = 0,
  });

  /// A day with nothing logged.
  static const empty = HabitDayState();

  /// Progress logged toward the habit's target on this date.
  final double value;

  /// Whether the reward was claimed on this date.
  final bool claimed;

  /// What this date's first claim paid out. Kept after an unclaim: each
  /// day pays once, so a re-claim pays nothing — same contract as
  /// [Habit.lastAwardedXp].
  final int awardedXp;
  final int awardedCoins;

  bool get rewardPaid => awardedXp > 0 || awardedCoins > 0;

  HabitDayState copyWith({
    double? value,
    bool? claimed,
    int? awardedXp,
    int? awardedCoins,
  }) {
    return HabitDayState(
      value: value ?? this.value,
      claimed: claimed ?? this.claimed,
      awardedXp: awardedXp ?? this.awardedXp,
      awardedCoins: awardedCoins ?? this.awardedCoins,
    );
  }

  /// Just the state fields — `habitId`/`dayKey`/`date` aren't part of the
  /// state itself (this class has no notion of "which day" it is), so the
  /// repository writing to Firestore adds those on top. See
  /// docs/BACKEND.md "Firestore schema" for the full `habitLogs` doc shape.
  Map<String, dynamic> toJson() => {
    'value': value,
    'claimed': claimed,
    'awardedXp': awardedXp,
    'awardedCoins': awardedCoins,
  };

  factory HabitDayState.fromJson(Map<String, dynamic> json) => HabitDayState(
    value: (json['value'] as num? ?? 0).toDouble(),
    claimed: json['claimed'] as bool? ?? false,
    awardedXp: json['awardedXp'] as int? ?? 0,
    awardedCoins: json['awardedCoins'] as int? ?? 0,
  );
}
