/// Vision is multiple evolution stages (docs/FEATURES.md §6); MVP ships one.
enum PetEvolutionStage { baby, evolution1 }

extension PetEvolutionStageLabel on PetEvolutionStage {
  String get label => switch (this) {
    PetEvolutionStage.baby => 'Baby Stage',
    PetEvolutionStage.evolution1 => 'Evolution 1',
  };
}

/// A user's pet and its care stats. Stats never drop below 0 and there is no
/// "death" state — a neglected pet can be unhappy/dirty/hungry, but coming
/// back to the app should never feel punishing (docs/FEATURES.md §8).
class Pet {
  const Pet({
    required this.id,
    required this.name,
    required this.stage,
    required this.evolutionLevelThreshold,
    required this.hunger,
    required this.hygiene,
    required this.happiness,
    required this.lastDecayAt,
  });

  final String id;
  final String name;
  final PetEvolutionStage stage;

  /// User level at which this pet promotes to [PetEvolutionStage.evolution1].
  final int evolutionLevelThreshold;

  final double hunger;
  final double hygiene;
  final double happiness;
  final DateTime lastDecayAt;

  double progressToNextEvolution(int userLevel) =>
      (userLevel / evolutionLevelThreshold).clamp(0, 1).toDouble();

  int levelsUntilNextEvolution(int userLevel) =>
      (evolutionLevelThreshold - userLevel).clamp(0, evolutionLevelThreshold);

  Pet copyWith({
    String? name,
    PetEvolutionStage? stage,
    double? hunger,
    double? hygiene,
    double? happiness,
    DateTime? lastDecayAt,
  }) {
    return Pet(
      id: id,
      name: name ?? this.name,
      stage: stage ?? this.stage,
      evolutionLevelThreshold: evolutionLevelThreshold,
      hunger: hunger ?? this.hunger,
      hygiene: hygiene ?? this.hygiene,
      happiness: happiness ?? this.happiness,
      lastDecayAt: lastDecayAt ?? this.lastDecayAt,
    );
  }
}
