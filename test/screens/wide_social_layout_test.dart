import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nori/data/app_data.dart';
import 'package:nori/screens/social/competition_detail_screen.dart';
import 'package:nori/screens/social/leaderboard_screen.dart';
import 'package:nori/widgets/nori_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

void expectNoCardFillsScreen(WidgetTester tester, Size size) {
  expect(tester.takeException(), isNull);
  for (final element in find.byType(NoriCard).evaluate()) {
    final box = element.size!;
    expect(
      box.height,
      lessThan(size.height * 0.7),
      reason: 'card ${box.width}x${box.height} in ${size.width}x${size.height}',
    );
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  const sizes = [Size(1400, 900), Size(1400, 500), Size(900, 700)];

  for (final size in sizes) {
    testWidgets('competition detail at ${size.width}x${size.height}', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final competitions = await AppData.social.getCompetitions();
      for (final c in competitions) {
        await tester.pumpWidget(
          MaterialApp(home: CompetitionDetailScreen(competitionId: c.id)),
        );
        await tester.pumpAndSettle();
        expectNoCardFillsScreen(tester, size);
      }
    });

    testWidgets('leaderboard at ${size.width}x${size.height}', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(const MaterialApp(home: LeaderboardScreen()));
      await tester.pumpAndSettle();
      expectNoCardFillsScreen(tester, size);
    });
  }
}
