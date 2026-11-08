import 'package:flutter/material.dart';
import 'package:nori/models/pet.dart';
import 'package:nori/widgets/celebration_card.dart';
import 'package:nori/widgets/nori_evolved_sprite.dart';

/// Celebrates a pet stage advance with [NoriEvolvedSprite] in [CelebrationScreen].
/// Use [showEvolutionCelebration] for the shared fade-and-scale entrance.
class EvolutionScreen extends StatelessWidget {
  const EvolutionScreen({
    super.key,
    required this.petName,
    required this.stage,
  });

  final String petName;
  final PetEvolutionStage stage;

  @override
  Widget build(BuildContext context) {
    return CelebrationScreen(
      kicker: 'YOUR NORI EVOLVED!',
      // The wings spread well past the 160px circle, so let the sprite
      // overflow it sideways instead of shrinking Nori to fit.
      badge: const OverflowBox(
        maxWidth: 260,
        maxHeight: 200,
        child: NoriEvolvedSprite(width: 250),
      ),
      title: stage.label,
      message:
          '$petName grew thanks to your consistency. Keep those habits up!',
    );
  }
}

Future<void> showEvolutionCelebration(
  BuildContext context, {
  required String petName,
  required PetEvolutionStage stage,
}) => showCelebrationRoute(
  context,
  (_) => EvolutionScreen(petName: petName, stage: stage),
);
