import 'package:flutter_test/flutter_test.dart';
import 'package:nori/data/habit_local_edits.dart';

import '../support/habits.dart';

void main() {
  final water = testHabit('water', type: 'quantity', target: 3);

  test('reaching the target is what completes a progress habit', () {
    expect(water.reachesTarget(2), isFalse);
    expect(water.reachesTarget(3), isTrue);
    expect(water.reachesTarget(10), isTrue);
    expect(testHabit('b').reachesTarget(5), isFalse);
    expect(
      testHabit('cap', type: 'limit', target: 3).reachesTarget(3),
      isFalse,
    );
  });

  test('Complete snaps to the target and Undo restores a remembered value', () {
    final partway = water.withProgress(1);
    final claimed = partway.claimedLocally();
    expect(claimed.isCompletedToday, isTrue);
    expect(claimed.currentValue, 3);
    expect(claimed.rewardPaid, isTrue);

    final undone = claimed.unclaimedLocally(restoreValue: 1);
    expect(undone.isCompletedToday, isFalse);
    expect(undone.currentValue, 1);
    // Undo takes the payout back, so Complete pays again.
    expect(undone.rewardPaid, isFalse);
    expect(undone.claimedLocally().rewardPaid, isTrue);
  });

  test('logging is capped at the target', () {
    expect(water.withProgress(2).withLogged(5).currentValue, 3);
  });

  test('pre-claim values are returned once', () {
    final day = DateTime(2026, 11, 5);
    PreClaimValues.remember('water', day, 1);
    expect(PreClaimValues.take('water', day), 1);
    expect(PreClaimValues.take('water', day), isNull);
  });
}
