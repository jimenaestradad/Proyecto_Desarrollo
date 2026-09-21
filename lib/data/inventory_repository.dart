import '../models/inventory.dart';

abstract class InventoryRepository {
  Future<Inventory> getInventory();

  /// Returns `false` (and consumes nothing) when [careItemId]'s count is
  /// already 0 — callers must not apply the matching pet-care action then.
  Future<bool> consumeCareItem(String careItemId);

  Future<void> addCareItem(String careItemId, int amount);

  Future<void> addAccessory(String accessoryId);

  /// No-op if [accessoryId] isn't in [Inventory.ownedAccessoryIds] — `null`
  /// (unequip) is always allowed.
  Future<void> setEquippedAccessory(String? accessoryId);
}

class MockInventoryRepository implements InventoryRepository {
  // Starts non-empty so care actions work before anyone visits the Shop;
  // 'sunglasses' matches a pre-owned demo item Shop already shows (was
  // 'smart-glasses' before that placeholder was dropped from the catalog —
  // see accessory_catalog.dart).
  Inventory _inventory = const Inventory(
    careItemCounts: {'food': 3, 'shampoo': 2, 'plushie': 1},
    ownedAccessoryIds: {'sunglasses'},
    equippedAccessoryId: 'sunglasses',
  );

  @override
  Future<Inventory> getInventory() async => _inventory;

  @override
  Future<bool> consumeCareItem(String careItemId) async {
    final count = _inventory.countOf(careItemId);
    if (count <= 0) return false;
    _inventory = _inventory.copyWith(
      careItemCounts: {..._inventory.careItemCounts, careItemId: count - 1},
    );
    return true;
  }

  @override
  Future<void> addCareItem(String careItemId, int amount) async {
    _inventory = _inventory.copyWith(
      careItemCounts: {
        ..._inventory.careItemCounts,
        careItemId: _inventory.countOf(careItemId) + amount,
      },
    );
  }

  @override
  Future<void> addAccessory(String accessoryId) async {
    _inventory = _inventory.copyWith(
      ownedAccessoryIds: {..._inventory.ownedAccessoryIds, accessoryId},
    );
  }

  @override
  Future<void> setEquippedAccessory(String? accessoryId) async {
    if (accessoryId != null &&
        !_inventory.ownedAccessoryIds.contains(accessoryId)) {
      return;
    }
    _inventory = _inventory.copyWith(equippedAccessoryId: accessoryId);
  }
}
