import 'package:flutter_test/flutter_test.dart';
import 'package:nori/models/habit_day_state.dart';

void main() {
  test('HabitDayState.toJson/fromJson round-trips', () {
    const states = [
      HabitDayState.empty,
      HabitDayState(
        value: 42.5,
        claimed: true,
        awardedXp: 20,
        awardedCoins: 10,
      ),
    ];

    for (final state in states) {
      final restored = HabitDayState.fromJson(state.toJson());
      expect(restored.toJson(), equals(state.toJson()));
    }
  });
}
