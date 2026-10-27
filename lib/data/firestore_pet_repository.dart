import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/pet.dart';
import '../utils/provisioning_retry.dart';
import 'care_item_catalog.dart';
import 'pet_repository.dart';

/// Real Firestore-backed [PetRepository] for `/users/{uid}/pet/main` -- see
/// docs/BACKEND.md, "Firestore schema" and the Architecture table.
///
/// [useCareItem] is a direct, rules-guarded client write (Architecture
/// table: "Feed / groom / play (+ stat decay)" -- spends an already-owned
/// consumable for a pet stat, not currency). [getPet] only reads: decay is
/// a pure function of the stored stats and `lastDecayAt`, so it's applied
/// on read and persisted only by the next care action. [useCareItem]
/// decrements `inventory/main`'s count and applies decay + restore to
/// `pet/main` in one transaction across both docs, so an item is never
/// spent without the pet getting its restore (or the reverse).
///
/// [syncEvolution] is deliberately a no-op here. `stage` is
/// Cloud-Function-only (docs/BACKEND.md, "Security rules":
/// "`stage` and `evolutionLevelThreshold` are denied to client writes...
/// Only claimHabit's transaction (Admin SDK) touches them") -- the one
/// seam into this vertical's data is inside Valeria's claimHabit/
/// unclaimHabit transaction (docs/BACKEND.md, "Division of labor"), not a
/// direct write from here. `home_screen.dart`, `calendar_screen.dart` and
/// `habits_list_screen.dart` still call `AppData.pet.syncEvolution(...)`
/// after a (still-mock) habit claim -- see docs/BACKEND.md, "Gaps/risks
/// found while planning this" #1: that call site is expected to go away
/// once `claimHabit` becomes a real Cloud Function doing the sync itself.
/// Until then this silently does nothing rather than attempt a write the
/// deployed rules would reject anyway.
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
      evolutionLevelThreshold:
          (data['evolutionLevelThreshold'] as num?)?.toInt() ?? 7,
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
      'one yet (see docs/BACKEND.md, Cloud Functions). '
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
  Future<void> syncEvolution(int userLevel) async {
    // See class doc comment -- `stage` is Cloud-Function-only; this is a
    // deliberate no-op, not a missing feature.
  }

  @override
  Future<void> renamePet(String name) async {
    // `name` is a direct-client-write field on pet/main (firestore.rules'
    // /pet/main update rule already allows it alongside the stat fields) --
    // see PetRepository.renamePet's doc comment. Retried because this fires
    // right after sign-up, when pet/main might not exist yet (see
    // retryWhileProvisioning).
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    await retryWhileProvisioning(() => _doc.update({'name': trimmed}));
  }
}
