import 'package:flutter/material.dart';
import 'package:nori/models/pet.dart';
import 'package:nori/widgets/celebration_card.dart';
import 'package:nori/widgets/nori_evolved_sprite.dart';

/// Full-screen celebration shown the moment [Pet.stage] advances — the
/// "Pantalla/animacion de evolucion" beat FEATURES.md §6 calls for but
/// doesn't spec further. Shows the evolved winged Nori ([NoriEvolvedSprite])
/// over a warm glow — the same sprite [NoriRoomStage] shows for evolved pets.
///
/// Shares [CelebrationScreen]'s shell with [LevelUpScreen]. Push with
/// [showEvolutionCelebration] rather than a bare `Navigator.push`, so every
/// call site gets the same fade+scale entrance.
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
