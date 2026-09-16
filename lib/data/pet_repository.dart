import '../models/pet.dart';

abstract class PetRepository {
  Future<Pet> getPet();

  /// [amount] is the calling [CareItem]'s `restoreAmount` (see
  /// care_item_catalog.dart) — different items restore different amounts.
  Future<void> feed({required double amount});
  Future<void> groom({required double amount});
  Future<void> play({required double amount});

  /// Keeps the pet's evolution stage in sync with [userLevel] against its
  /// threshold — promotes on crossing it, demotes back if a claim gets
  /// undone and the level drops below it again, so evolution never drifts
  /// out of sync with the level it's derived from. Call after any action
  /// that might change the user's level.
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
  Future<void> feed({required double amount}) async {
    _pet = _applyDecay(_pet);
    _pet = _pet.copyWith(hunger: (_pet.hunger + amount).clamp(0, 100));
  }

  @override
  Future<void> groom({required double amount}) async {
    _pet = _applyDecay(_pet);
    _pet = _pet.copyWith(hygiene: (_pet.hygiene + amount).clamp(0, 100));
  }

  @override
  Future<void> play({required double amount}) async {
    _pet = _applyDecay(_pet);
    _pet = _pet.copyWith(happiness: (_pet.happiness + amount).clamp(0, 100));
  }

  @override
  Future<void> syncEvolution(int userLevel) async {
    final shouldEvolve = userLevel >= _pet.evolutionLevelThreshold;
    if (shouldEvolve && _pet.stage == PetEvolutionStage.baby) {
      _pet = _pet.copyWith(stage: PetEvolutionStage.evolution1);
    } else if (!shouldEvolve && _pet.stage == PetEvolutionStage.evolution1) {
      _pet = _pet.copyWith(stage: PetEvolutionStage.baby);
    }
  }
}
