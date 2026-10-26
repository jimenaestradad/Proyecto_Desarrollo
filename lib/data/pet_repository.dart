import '../models/pet.dart';
import 'care_item_catalog.dart';
import 'inventory_repository.dart';

abstract class PetRepository {
  Future<Pet> getPet();

  /// Spends one [item] from the inventory and restores the vital its
  /// [CareItem.category] targets by [CareItem.restoreAmount] (after
  /// decay), as one unit: either both happen or neither does. Returns false,
  /// changing nothing, when the item is out of stock. Replaced separate
  /// consume + feed/groom/play calls (2026-10-06), which could spend an item
  /// without restoring anything if the second write failed.
  Future<bool> useCareItem(CareItem item);

  /// Keeps the pet's evolution stage in sync with [userLevel] against its
  /// threshold — promotes on crossing it, demotes back if a claim gets
  /// undone and the level drops below it again, so evolution never drifts
  /// out of sync with the level it's derived from. Call after any action
  /// that might change the user's level.
  Future<void> syncEvolution(int userLevel);

  /// Sets the pet's display name -- a direct client write, not
  /// Cloud-Function-only (docs/BACKEND.md, "Onboarding answer (pet
  /// name)": it's typed on a screen after sign-up, not currency, so an
  /// auth trigger can't see it and it needs no Cloud Function). Called
  /// once from the "name your pet" onboarding screen; skipping onboarding
  /// just never calls this, leaving onUserCreate's default of 'Nori'.
  Future<void> renamePet(String name);
}

class MockPetRepository implements PetRepository {
  MockPetRepository(this._inventory);

  final InventoryRepository _inventory;

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

  // In memory nothing can fail between the two steps, so consuming
  // through the inventory and then restoring is already all-or-nothing.
  @override
  Future<bool> useCareItem(CareItem item) async {
    if (!await _inventory.consumeCareItem(item.id)) return false;
    _pet = applyCareRestore(_applyDecay(_pet), item);
    return true;
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

  @override
  Future<void> renamePet(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    _pet = _pet.copyWith(name: trimmed);
  }
}

/// [pet] with [item]'s vital raised by its restoreAmount, clamped to 100.
/// Shared by both repositories so the category → vital mapping lives once.
Pet applyCareRestore(Pet pet, CareItem item) {
  final amount = item.restoreAmount;
  return switch (item.category) {
    CareCategory.hunger => pet.copyWith(
      hunger: (pet.hunger + amount).clamp(0, 100),
    ),
    CareCategory.hygiene => pet.copyWith(
      hygiene: (pet.hygiene + amount).clamp(0, 100),
    ),
    CareCategory.love => pet.copyWith(
      happiness: (pet.happiness + amount).clamp(0, 100),
    ),
  };
}
