import 'package:flutter_test/flutter_test.dart';
import 'package:nori/data/care_item_catalog.dart';
import 'package:nori/data/inventory_repository.dart';
import 'package:nori/data/pet_repository.dart';

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
}
