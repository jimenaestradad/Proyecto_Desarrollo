import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nori/models/pet.dart';
import 'package:nori/screens/pet/evolution_screen.dart';

void main() {
  testWidgets('evolution celebration lays out with the wide winged sprite', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360 * 3, 740 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const MaterialApp(
        home: EvolutionScreen(
          petName: 'Nori',
          stage: PetEvolutionStage.evolution1,
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));

    expect(tester.takeException(), isNull);
    expect(find.text('YOUR NORI EVOLVED!'), findsOneWidget);
  });
}
