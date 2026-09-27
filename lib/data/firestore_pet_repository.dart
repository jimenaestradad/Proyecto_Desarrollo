import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/pet.dart';
import 'pet_repository.dart';

/// Real Firestore-backed [PetRepository] for `/users/{uid}/pet/main` -- see
/// docs/BACKEND.md, "Firestore schema" and the Architecture table.
///
/// [getPet]/[feed]/[groom]/[play] are direct, rules-guarded client writes
/// (Architecture table: "Feed / groom / play (+ stat decay)" -- spends an
/// already-owned consumable for a pet stat, not currency). Each stat
/// change reads-applies-decay-writes inside a single-document Firestore
/// transaction so a decay tick racing a care action can't clobber the
/// other's write.
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

  // Mirrors MockPetRepository -- same decay rate, see that class's own
  // comment. Balance numbers are still open (docs/BACKEND.md,
  // "Balance numbers are still open"); porting the mock's value as-is is
  // the safe move until OPEN_DECISIONS.md settles a real one.
  static const double _decayPerHour = 2;

  DocumentReference<Map<String, dynamic>> get _doc => _firestore
      .collection('users')
      .doc(_uid)
      .collection('pet')
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
      evolutionLevelThreshold: (data['evolutionLevelThreshold'] as num?)
              ?.toInt() ??
          7,
      hunger: (data['hunger'] as num?)?.toDouble() ?? 100,
      hygiene: (data['hygiene'] as num?)?.toDouble() ?? 100,
      happiness: (data['happiness'] as num?)?.toDouble() ?? 100,
      lastDecayAt: lastDecayAt,
    );
  }

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
    final decayed = _applyDecay(_fromData(data));
    await _doc.update(_decayFields(decayed));
    return decayed;
  }

  /// Applies decay, then adds [amount] to whichever vital [field] names,
  /// clamped 0-100, in one transaction -- shared by [feed]/[groom]/[play],
  /// which differ only in which field they touch.
  Future<void> _adjust(String field, double amount) {
    return _firestore.runTransaction((tx) async {
      final snapshot = await tx.get(_doc);
      final data = snapshot.data();
      if (data == null) _missingDoc();
      final decayed = _applyDecay(_fromData(data));
      final current = switch (field) {
        'hunger' => decayed.hunger,
        'hygiene' => decayed.hygiene,
        'happiness' => decayed.happiness,
        _ => throw ArgumentError('Unknown pet stat field: $field'),
      };
      final updated = (current + amount).clamp(0, 100);
      tx.update(_doc, {..._decayFields(decayed), field: updated});
    });
  }

  @override
  Future<void> feed({required double amount}) => _adjust('hunger', amount);

  @override
  Future<void> groom({required double amount}) => _adjust('hygiene', amount);

  @override
  Future<void> play({required double amount}) => _adjust('happiness', amount);

  @override
  Future<void> syncEvolution(int userLevel) async {
    // See class doc comment -- `stage` is Cloud-Function-only; this is a
    // deliberate no-op, not a missing feature.
  }
}
