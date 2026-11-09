import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/pet.dart';
import '../utils/provisioning_retry.dart';
import 'care_item_catalog.dart';
import 'pet_repository.dart';

/// Firestore pet reads apply decay; care atomically consumes inventory and restores stats.
/// The stage is Cloud-Function-only: claims and deletes sync it server-side.
class FirestorePetRepository implements PetRepository {
  FirestorePetRepository({required String uid, FirebaseFirestore? firestore})
    : _uid = uid,
      _firestore = firestore ?? FirebaseFirestore.instance;

  final String _uid;
  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> get _doc =>
      _firestore.collection('users').doc(_uid).collection('pet').doc('main');

  // Owned by FirestoreInventoryRepository; touched here only by
  // [useCareItem], whose whole point is writing both docs atomically.
  DocumentReference<Map<String, dynamic>> get _inventoryDoc => _firestore
      .collection('users')
      .doc(_uid)
      .collection('inventory')
      .doc('main');

  Pet _fromData(Map<String, dynamic> data) {
    final stageName = data['stage'] as String? ?? PetEvolutionStage.baby.name;
    final stage = PetEvolutionStage.values.firstWhere(
      (s) => s.name == stageName,
      orElse: () => PetEvolutionStage.baby,
    );
    final lastDecayAt =
        (data['lastDecayAt'] as Timestamp?)?.toDate() ?? DateTime.now();
    return Pet(
      id: 'main',
      name: data['name'] as String? ?? 'Nori',
      stage: stage,
      // The stored value (7 on older accounts) is ignored; see kEvolutionLevel.
      evolutionLevelThreshold: kEvolutionLevel,
      hunger: (data['hunger'] as num?)?.toDouble() ?? 100,
      hygiene: (data['hygiene'] as num?)?.toDouble() ?? 100,
      happiness: (data['happiness'] as num?)?.toDouble() ?? 100,
      lastDecayAt: lastDecayAt,
    );
  }

  Map<String, dynamic> _decayFields(Pet pet) => {
    'hunger': pet.hunger,
    'hygiene': pet.hygiene,
    'happiness': pet.happiness,
    'lastDecayAt': Timestamp.fromDate(pet.lastDecayAt),
  };

  Never _missingDoc() {
    throw StateError(
      'No pet/main document for $_uid -- onUserCreate has not provisioned '
      'one yet (see docs/technical/BACKEND.md, Cloud Functions). '
      "FirestorePetRepository isn't safe to use until that exists.",
    );
  }

  @override
  Future<Pet> getPet() async {
    final snapshot = await _doc.get();
    final data = snapshot.data();
    if (data == null) _missingDoc();
    // Not written back: a plain update here could land after a concurrent
    // useCareItem transaction and overwrite its restore with older stats.
    return applyPetDecay(_fromData(data));
  }

  @override
  Future<bool> useCareItem(CareItem item) {
    return _firestore.runTransaction<bool>((tx) async {
      final petSnapshot = await tx.get(_doc);
      final inventorySnapshot = await tx.get(_inventoryDoc);
      final petData = petSnapshot.data();
      if (petData == null) _missingDoc();
      final counts = Map<String, dynamic>.from(
        inventorySnapshot.data()?['careItemCounts'] as Map<String, dynamic>? ??
            const {},
      );
      final current = (counts[item.id] as num?)?.toInt() ?? 0;
      if (current <= 0) return false;
      counts[item.id] = current - 1;

      final restored = applyCareRestore(
        applyPetDecay(_fromData(petData)),
        item,
      );
      tx.update(_inventoryDoc, {'careItemCounts': counts});
      tx.update(_doc, _decayFields(restored));
      return true;
    });
  }

  @override
  Future<void> renamePet(String name) async {
    // Pet names allow direct client writes.
    // Retry while provisioning because pet/main may not exist immediately after sign-up.
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    await retryWhileProvisioning(() => _doc.update({'name': trimmed}));
  }
}
