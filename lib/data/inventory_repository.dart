import '../models/inventory.dart';

abstract class InventoryRepository {
  Future<Inventory> getInventory();

  /// Each returns `false` (and consumes nothing) when the count is already 0
  /// — callers must not apply the matching pet-care action in that case.
  Future<bool> consumeSnack();
  Future<bool> consumeSoap();
  Future<bool> consumeToy();

  Future<void> addSnacks(int amount);
  Future<void> addSoap(int amount);
  Future<void> addToys(int amount);

  Future<void> addAccessory(String accessoryId);

  /// No-op if [accessoryId] isn't in [Inventory.ownedAccessoryIds] — `null`
  /// (unequip) is always allowed.
  Future<void> setEquippedAccessory(String? accessoryId);
}

class MockInventoryRepository implements InventoryRepository {
  // Starts non-empty so care actions work before anyone visits the Shop;
  // 'smart-glasses' matches the pre-owned demo item Shop already showed.
  Inventory _inventory = const Inventory(
    snacks: 3,
    soap: 2,
    toys: 1,
    ownedAccessoryIds: {'smart-glasses'},
    equippedAccessoryId: 'smart-glasses',
  );

  @override
  Future<Inventory> getInventory() async => _inventory;

  @override
  Future<bool> consumeSnack() async {
    if (_inventory.snacks <= 0) return false;
    _inventory = _inventory.copyWith(snacks: _inventory.snacks - 1);
    return true;
  }

  @override
  Future<bool> consumeSoap() async {
    if (_inventory.soap <= 0) return false;
    _inventory = _inventory.copyWith(soap: _inventory.soap - 1);
    return true;
  }

  @override
  Future<bool> consumeToy() async {
    if (_inventory.toys <= 0) return false;
    _inventory = _inventory.copyWith(toys: _inventory.toys - 1);
    return true;
  }

  @override
  Future<void> addSnacks(int amount) async {
    _inventory = _inventory.copyWith(snacks: _inventory.snacks + amount);
  }

  @override
  Future<void> addSoap(int amount) async {
    _inventory = _inventory.copyWith(soap: _inventory.soap + amount);
  }

  @override
  Future<void> addToys(int amount) async {
    _inventory = _inventory.copyWith(toys: _inventory.toys + amount);
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
