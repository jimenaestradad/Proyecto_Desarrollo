import '../models/pet.dart';

abstract class PetRepository {
  Future<Pet> getPet();

  Future<void> feed();
  Future<void> groom();
  Future<void> play();

  /// Promotes the pet's evolution stage once [userLevel] crosses its
  /// threshold. Call after any action that might change the user's level.
  Future<void> syncEvolution(int userLevel);
}

class MockPetRepository implements PetRepository {
  // ADOPTED-FROM-STITCH demo numbers.
  Pet _pet = Pet(
    id: 'nori-pet',
    name: 'Nori',
    stage: PetEvolutionStage.baby,
    evolutionLevelThreshold: 7,
    hunger: 78,
    hygiene: 90,
    happiness: 88,
    lastDecayAt: DateTime.now(),
  );

  static const double _decayPerHour = 2;

  Pet _applyDecay(Pet pet) {
    final elapsedHours =
        DateTime.now().difference(pet.lastDecayAt).inMinutes / 60;
    if (elapsedHours <= 0) return pet;
    final drop = (elapsedHours * _decayPerHour).clamp(0, 100);
    return pet.copyWith(
      hunger: (pet.hunger - drop).clamp(0, 100),
      hygiene: (pet.hygiene - drop).clamp(0, 100),
      happiness: (pet.happiness - drop).clamp(0, 100),
      lastDecayAt: DateTime.now(),
    );
  }

  @override
  Future<Pet> getPet() async {
    _pet = _applyDecay(_pet);
    return _pet;
  }

  @override
  Future<void> feed() async {
    _pet = _applyDecay(_pet);
    _pet = _pet.copyWith(hunger: (_pet.hunger + 25).clamp(0, 100));
  }

  @override
  Future<void> groom() async {
    _pet = _applyDecay(_pet);
    _pet = _pet.copyWith(hygiene: (_pet.hygiene + 25).clamp(0, 100));
  }

  @override
  Future<void> play() async {
    _pet = _applyDecay(_pet);
    _pet = _pet.copyWith(happiness: (_pet.happiness + 20).clamp(0, 100));
  }

  @override
  Future<void> syncEvolution(int userLevel) async {
    if (_pet.stage == PetEvolutionStage.baby &&
        userLevel >= _pet.evolutionLevelThreshold) {
      _pet = _pet.copyWith(stage: PetEvolutionStage.evolution1);
    }
  }
}
