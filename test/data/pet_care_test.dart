import 'package:flutter_test/flutter_test.dart';
import 'package:nori/data/care_item_catalog.dart';
import 'package:nori/data/inventory_repository.dart';
import 'package:nori/data/pet_repository.dart';
import 'package:nori/models/pet.dart';

CareItem _item(String id) => kCareItemCatalog.firstWhere((i) => i.id == id);

void main() {
  test('using a care item spends one and restores its vital', () async {
    final inventory = MockInventoryRepository();
    final pet = MockPetRepository(inventory);
    final food = _item('food');
    final before = await pet.getPet();

    expect(await pet.useCareItem(food), isTrue);

    expect((await inventory.getInventory()).countOf('food'), 2);
    final after = await pet.getPet();
    expect(after.hunger, (before.hunger + food.restoreAmount).clamp(0, 100));
    expect(after.hygiene, before.hygiene);
  });

  test('an out-of-stock item changes nothing', () async {
    final inventory = MockInventoryRepository();
    final pet = MockPetRepository(inventory);
    final cake = _item('cake'); // the mock starts with none
    final before = await pet.getPet();

    expect(await pet.useCareItem(cake), isFalse);

    expect((await inventory.getInventory()).countOf('cake'), 0);
    expect((await pet.getPet()).hunger, before.hunger);
  });

  group('applyPetDecay', () {
    final start = DateTime(2026, 10, 26, 8);
    Pet petAt(DateTime at, {double hunger = 80}) => Pet(
      id: 'p',
      name: 'Nori',
      stage: PetEvolutionStage.baby,
      evolutionLevelThreshold: 7,
      hunger: hunger,
      hygiene: 90,
      happiness: 70,
      lastDecayAt: at,
    );

    test(
      'every vital drops by the same hourly amount, and the clock resets',
      () {
        final now = start.add(const Duration(hours: 3));
        final decayed = applyPetDecay(petAt(start), now: now);
        expect(decayed.hunger, 80 - 3 * kPetDecayPerHour);
        expect(decayed.hygiene, 90 - 3 * kPetDecayPerHour);
        expect(decayed.happiness, 70 - 3 * kPetDecayPerHour);
        expect(decayed.lastDecayAt, now);
      },
    );

    test('vitals floor at 0', () {
      final decayed = applyPetDecay(
        petAt(start, hunger: 5),
        now: start.add(const Duration(days: 30)),
      );
      expect(decayed.hunger, 0);
      expect(decayed.hygiene, 0);
      expect(decayed.happiness, 0);
    });

    test('no time passed (or a clock set back) changes nothing', () {
      final pet = petAt(start);
      expect(identical(applyPetDecay(pet, now: start), pet), isTrue);
      expect(
        identical(
          applyPetDecay(pet, now: start.subtract(const Duration(hours: 1))),
          pet,
        ),
        isTrue,
      );
    });
  });
}
