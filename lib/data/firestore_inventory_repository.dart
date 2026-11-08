import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/inventory.dart';
import 'inventory_repository.dart';

/// Firestore inventory at `/users/{uid}/inventory/main`.
/// Consumes owned care items and equips accessories through guarded client writes;
/// purchases require Cloud Functions to prevent free item creation.
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
