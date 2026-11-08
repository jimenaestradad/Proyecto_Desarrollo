import '../models/pet.dart';
import 'care_item_catalog.dart';
import 'inventory_repository.dart';

abstract class PetRepository {
  Future<Pet> getPet();

  /// Atomically spends one [item] and restores its target vital after decay.
  /// Returns false without changes when the item is out of stock.
  Future<bool> useCareItem(CareItem item);

  /// Sets the pet's display name through a direct client write during onboarding.
  /// Skipping keeps `onUserCreate`'s default name, 'Nori'.
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
    evolutionLevelThreshold: kEvolutionLevel,
    hunger: 78,
    hygiene: 90,
    happiness: 88,
    lastDecayAt: DateTime.now(),
  );

  @override
  Future<Pet> getPet() async {
    _pet = applyPetDecay(_pet);
    return _pet;
  }

  // In memory nothing can fail between the two steps, so consuming
  // through the inventory and then restoring is already all-or-nothing.
  @override
  Future<bool> useCareItem(CareItem item) async {
    if (!await _inventory.consumeCareItem(item.id)) return false;
    _pet = applyCareRestore(applyPetDecay(_pet), item);
    return true;
  }

  @override
  Future<void> renamePet(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    _pet = _pet.copyWith(name: trimmed);
  }
}

/// How many points each vital loses per hour: 1 means a full vital reaches
/// the "Pet needs you" line (30) in about 70 hours, and one cheap care item per
/// vital a day keeps Nori fine (economy pass 2026-11-07, OPEN_DECISIONS.md).
/// `PET_DECAY_PER_HOUR` in functions/src/notifications.ts mirrors it — change
/// both together.
const double kPetDecayPerHour = 1;

/// The level at which Nori first evolves (1,000 XP in total). Every pet uses
/// this: an `evolutionLevelThreshold` stored on older pet documents (7) is
/// ignored. `EVOLUTION_LEVEL` in functions/src/rewards.ts mirrors it.
const int kEvolutionLevel = 5;

/// Applies equal decay to every vital since `lastDecayAt`, floored at zero.
/// Uses whole minutes and resets `lastDecayAt` to [now]; shared by both repositories.
Pet applyPetDecay(Pet pet, {DateTime? now}) {
  final current = now ?? DateTime.now();
  final elapsedHours = current.difference(pet.lastDecayAt).inMinutes / 60;
  if (elapsedHours <= 0) return pet;
  final drop = (elapsedHours * kPetDecayPerHour).clamp(0, 100);
  return pet.copyWith(
    hunger: (pet.hunger - drop).clamp(0, 100),
    hygiene: (pet.hygiene - drop).clamp(0, 100),
    happiness: (pet.happiness - drop).clamp(0, 100),
    lastDecayAt: current,
  );
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
