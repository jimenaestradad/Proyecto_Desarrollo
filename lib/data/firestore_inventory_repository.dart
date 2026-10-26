import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/inventory.dart';
import 'inventory_repository.dart';

/// Real Firestore-backed [InventoryRepository] for
/// `/users/{uid}/inventory/main` -- see docs/BACKEND.md, "Firestore
/// schema" and the Architecture table.
///
/// [consumeCareItem] and [setEquippedAccessory] are direct, rules-guarded
/// client writes -- no currency involved (Architecture table:
/// "`consumeCareItem` as part of feed/groom/play" and "Equip/unequip an
/// already-owned accessory"). [addCareItem] and [addAccessory] are the two
/// places a client write could otherwise mint an owned item for free, so
/// per the same table they're Cloud-Function-only
/// (`purchaseCareItem`/`purchaseAccessory` in functions/src/shop.ts) --
/// this repository deliberately doesn't attempt a direct write for
/// either, matching FirestoreUserRepository.addXp's UnsupportedError
/// idiom. Screens call the Cloud Function directly instead (see
/// shop_screen.dart's `_buyCareItem`/`_buyAccessory`, via
/// cloud_functions_client.dart's shared helper).
class FirestoreInventoryRepository implements InventoryRepository {
  FirestoreInventoryRepository({
    required String uid,
    FirebaseFirestore? firestore,
  }) : _uid = uid,
       _firestore = firestore ?? FirebaseFirestore.instance;

  final String _uid;
  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> get _doc => _firestore
      .collection('users')
      .doc(_uid)
      .collection('inventory')
      .doc('main');

  Inventory _fromData(Map<String, dynamic> data) {
    final rawCounts =
        data['careItemCounts'] as Map<String, dynamic>? ?? const {};
    final rawOwned = data['ownedAccessoryIds'] as List<dynamic>? ?? const [];
    return Inventory(
      careItemCounts: rawCounts.map(
        (key, value) => MapEntry(key, (value as num?)?.toInt() ?? 0),
      ),
      ownedAccessoryIds: {for (final id in rawOwned) id as String},
      equippedAccessoryId: data['equippedAccessoryId'] as String?,
    );
  }

  @override
  Future<Inventory> getInventory() async {
    final snapshot = await _doc.get();
    final data = snapshot.data();
    if (data == null) {
      throw StateError(
        'No inventory/main document for $_uid -- onUserCreate has not '
        'provisioned one yet (see docs/BACKEND.md, Cloud Functions). '
        "FirestoreInventoryRepository isn't safe to use until that exists.",
      );
    }
    return _fromData(data);
  }

  @override
  Future<bool> consumeCareItem(String careItemId) {
    return _firestore.runTransaction<bool>((tx) async {
      final snapshot = await tx.get(_doc);
      final data = snapshot.data();
      if (data == null) return false;
      final counts = Map<String, dynamic>.from(
        data['careItemCounts'] as Map<String, dynamic>? ?? const {},
      );
      final current = (counts[careItemId] as num?)?.toInt() ?? 0;
      if (current <= 0) return false;
      counts[careItemId] = current - 1;
      tx.update(_doc, {'careItemCounts': counts});
      return true;
    });
  }

  @override
  Future<void> addCareItem(String careItemId, int amount) {
    throw UnsupportedError(
      'FirestoreInventoryRepository.addCareItem: careItemCounts may only '
      'be INCREASED via the purchaseCareItem Cloud Function '
      '(docs/BACKEND.md, "Security rules") -- the deployed rules reject a '
      'direct client increase. Call purchaseCareItem from the screen '
      'instead.',
    );
  }

  @override
  Future<void> addAccessory(String accessoryId) {
    throw UnsupportedError(
      'FirestoreInventoryRepository.addAccessory: ownedAccessoryIds may '
      'only grow via the purchaseAccessory Cloud Function '
      '(docs/BACKEND.md, "Security rules") -- the deployed rules reject a '
      'direct client addition. Call purchaseAccessory from the screen '
      'instead.',
    );
  }

  @override
  Future<void> setEquippedAccessory(String? accessoryId) async {
    final snapshot = await _doc.get();
    final data = snapshot.data();
    if (data == null) return;
    final owned = {
      for (final id
          in (data['ownedAccessoryIds'] as List<dynamic>? ?? const []))
        id as String,
    };
    if (accessoryId != null && !owned.contains(accessoryId)) return;
    await _doc.update({'equippedAccessoryId': accessoryId});
  }
}
