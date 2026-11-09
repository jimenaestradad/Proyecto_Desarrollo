import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nori/data/habit_local_edits.dart';
import 'package:nori/models/habit.dart';
import 'package:nori/widgets/reward_burst.dart';

Habit _habit({bool completed = false, int paidXp = 0, int paidCoins = 0}) =>
    Habit(
      id: 'h1',
      name: 'Read',
      subtitle: 'Study',
      icon: Icons.book,
      color: Colors.white,
      xpReward: 20,
      coinReward: 10,
      repeat: HabitRepeat.daily,
      type: HabitType.binary,
      isCompletedToday: completed,
      lastAwardedXp: paidXp,
      lastAwardedCoins: paidCoins,
    );

Future<BuildContext> _pumpApp(WidgetTester tester) async {
  late BuildContext captured;
  await tester.pumpWidget(
    MaterialApp(
      builder: (context, child) => RewardBurst.trackPointer(child: child!),
      home: Builder(
        builder: (context) {
          captured = context;
          return const Scaffold(body: SizedBox.expand());
        },
      ),
    ),
  );
  return captured;
}

void main() {
  testWidgets('shows the reward chip, then removes it', (tester) async {
    final context = await _pumpApp(tester);
    RewardBurst.show(context, xp: 13, coins: 5);
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('+13 XP'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 1500));
    expect(find.text('+13 XP'), findsNothing);
  });

  testWidgets('a claim that pays shows the chip', (tester) async {
    final context = await _pumpApp(tester);
    final before = _habit();
    RewardBurst.showForClaim(
      context,
      before: before,
      after: before.claimedLocally(),
    );
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.textContaining('XP'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1500));
  });

  testWidgets('undo and a re-claim of a paid day show nothing', (tester) async {
    final context = await _pumpApp(tester);

    final claimed = _habit(completed: true, paidXp: 20, paidCoins: 10);
    RewardBurst.showForClaim(
      context,
      before: claimed,
      after: claimed.unclaimedLocally(),
    );
    final unclaimedButPaid = _habit(paidXp: 20, paidCoins: 10);
    RewardBurst.showForClaim(
      context,
      before: unclaimedButPaid,
      after: unclaimedButPaid.claimedLocally(),
    );
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.textContaining('XP'), findsNothing);
  });
}
