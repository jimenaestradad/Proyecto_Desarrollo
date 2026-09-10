/// One habit's logged state on one specific date.
///
/// This is the per-date half of a habit: [Habit] holds the *definition*
/// (name, target, schedule) which is the same every day, while this holds
/// what actually happened on a given day. Mirrors how a backend would store
/// it — a row keyed by (habit id, date) — so swapping the mock for a real
/// repository is a data-source change, not a model change.
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

  /// What the claim actually paid out, so un-claiming reverses it exactly
  /// rather than recomputing against since-changed state — same contract as
  /// [Habit.lastAwardedXp].
  final int awardedXp;
  final int awardedCoins;

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
}
