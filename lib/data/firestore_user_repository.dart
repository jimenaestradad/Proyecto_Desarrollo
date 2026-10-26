import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart' show FirebaseException;

import '../models/nori_user.dart';
import 'calendar_repository.dart';
import 'user_repository.dart';
import 'vacation_log.dart';

/// Real Firestore-backed [UserRepository] for the fields Jimena's vertical
/// owns directly (see docs/BACKEND.md, "Firestore schema" and the Jimena
/// checklist's `FirestoreUserRepository` entry): name, username, email,
/// avatarUrl, vacationModeEnabled. `habitCategories` lives on the same
/// `/users/{uid}` doc but is served through [HabitCategoryRepository] /
/// `FirestoreHabitCategoryRepository` instead, matching the app's existing
/// interface split rather than folding it into this one.
///
/// Wired into [AppData] via `AppData.bindToUser`, called right after
/// sign-up/login/auto-login succeeds (see login_screen.dart,
/// sign_up_screen.dart, main.dart). This still depends on `onUserCreate`
/// (the Auth-trigger Cloud Function in functions/src/onUserCreate.ts) being
/// deployed to the `nori-pet` Firebase project -- that's what actually
/// creates the `/users/{uid}` document, and it has to be a Cloud Function
/// specifically: the deployed security rules only grant `read`/`update` on
/// `/users/{uid}`, not `create`, on purpose -- a client provisioning its
/// own starting level/XP/coins is exactly the self-granted-currency hole
/// the whole Cloud-Functions boundary in this doc exists to close.
/// [_getDataWithRetry]/[_updateWithRetry] retry briefly on a missing doc
/// to absorb the normal race between sign-up returning and that trigger
/// finishing.
class FirestoreUserRepository implements UserRepository {
  FirestoreUserRepository({
    required String uid,
    required CalendarRepository calendar,
    required VacationLog vacationLog,
    FirebaseFirestore? firestore,
  }) : _uid = uid,
       _calendar = calendar,
       _vacationLog = vacationLog,
       _firestore = firestore ?? FirebaseFirestore.instance;

  final String _uid;
  final CalendarRepository _calendar;
  final VacationLog _vacationLog;
  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> get _doc =>
      _firestore.collection('users').doc(_uid);

  @override
  Future<NoriUser> getCurrentUser() async {
    final data = await _getDataWithRetry();
    // currentStreak is derived, never stored (docs/BACKEND.md, "Derived,
    // never stored") -- same rule MockUserRepository already follows, via
    // whatever CalendarRepository AppData currently has wired (mock or,
    // eventually, Valeria's FirestoreCalendarRepository).
    final streak = (await _calendar.getCurrentMonth()).currentStreak;
    return NoriUser(
      id: _uid,
      name: data['name'] as String? ?? '',
      username: data['username'] as String? ?? '',
      email: data['email'] as String? ?? '',
      level: data['level'] as int? ?? 1,
      totalXp: data['totalXp'] as int? ?? 0,
      xpIntoLevel: data['xpIntoLevel'] as int? ?? 0,
      xpForNextLevel: data['xpForNextLevel'] as int? ?? 100,
      currentStreak: streak,
      coins: data['coins'] as int? ?? 0,
      vacationModeEnabled: data['vacationModeEnabled'] as bool? ?? false,
      avatarUrl: data['avatarUrl'] as String?,
    );
  }

  /// Reads `/users/{uid}`, retrying a few times if it doesn't exist yet --
  /// right after sign-up this can race `onUserCreate` (the Auth-trigger
  /// Cloud Function that actually creates this doc), since Firebase Auth
  /// account creation returns before that trigger is guaranteed to have
  /// run. A handful of short retries covers the normal sub-second gap
  /// without leaving the caller stuck if the doc genuinely never shows up.
  Future<Map<String, dynamic>> _getDataWithRetry({
    int attempts = 5,
    Duration delay = const Duration(milliseconds: 400),
  }) async {
    for (var attempt = 1; attempt <= attempts; attempt++) {
      final snapshot = await _doc.get();
      final data = snapshot.data();
      if (data != null) return data;
      if (attempt == attempts) {
        throw StateError(
          'No /users/$_uid document -- onUserCreate has not provisioned one '
          'yet (see docs/BACKEND.md, Cloud Functions). FirestoreUserRepository '
          "isn't safe to use until that exists.",
        );
      }
      await Future.delayed(delay);
    }
    // Unreachable -- the loop above always returns or throws.
    throw StateError('No /users/$_uid document.');
  }

  @override
  Future<void> updateProfile({
    String? name,
    String? username,
    String? email,
  }) async {
    final updates = <String, dynamic>{
      if (name != null) 'name': name,
      if (username != null) 'username': username,
      if (email != null) 'email': email,
    };
    if (updates.isEmpty) return;
    await _updateWithRetry(updates);
  }

  /// Writes to `/users/{uid}`, retrying on the same onUserCreate race
  /// described on [_getDataWithRetry] -- this is the call sign-up/login
  /// make right after auth succeeds, so it's the one most likely to land
  /// before the trigger has provisioned the doc.
  ///
  /// A doc-not-yet-provisioned write can surface as either 'not-found'
  /// (backend rejects the update outright) or 'permission-denied' (the
  /// security rule's `resource.data.diff(...)` check on the /users/{uid}
  /// update rule can only be evaluated once `resource` exists; before that
  /// it's cleanly denied rather than erroring, per firestore.rules). Both
  /// mean the same thing here -- the doc isn't there yet -- so both are
  /// retried the same way.
  Future<void> _updateWithRetry(
    Map<String, dynamic> updates, {
    int attempts = 5,
    Duration delay = const Duration(milliseconds: 400),
  }) async {
    for (var attempt = 1; attempt <= attempts; attempt++) {
      try {
        await _doc.update(updates);
        return;
      } on FirebaseException catch (e) {
        final isMissingDocRace =
            e.code == 'not-found' || e.code == 'permission-denied';
        if (!isMissingDocRace || attempt == attempts) rethrow;
        await Future.delayed(delay);
      }
    }
  }

  @override
  Future<void> setVacationMode(bool enabled) async {
    final now = DateTime.now();
    // Kept in sync with the shared in-memory VacationLog regardless of
    // mock/real split -- whatever CalendarRepository is currently wired
    // reads freeze history from this same instance to compute streaks
    // (see vacation_log.dart's own doc comment for why it's a separate
    // shared store rather than living on this repository).
    if (enabled) {
      _vacationLog.startFreeze(now);
    } else {
      _vacationLog.endFreeze(now);
    }
    await _doc.update({'vacationModeEnabled': enabled});
    // TODO(docs/BACKEND.md schema): `vacationRanges` -- the persisted
    // history that would let VacationLog rebuild itself on a fresh app
    // launch instead of starting empty every time -- isn't written or
    // rehydrated here yet. Worth wiring up once habit history itself is
    // real (Valeria's FirestoreCalendarRepository); a persisted vacation
    // history with nothing but mock habit history to apply it to isn't
    // useful on its own.
  }

  @override
  Future<void> addXp(int amount) {
    throw UnsupportedError(
      'FirestoreUserRepository.addXp: level/totalXp/xpIntoLevel are '
      'Cloud-Function-only fields (docs/BACKEND.md, "Security rules") -- '
      'the deployed rules reject a direct client write to them. This '
      "repository deliberately doesn't attempt one. The real replacement "
      "is calling Valeria's claimHabit/unclaimHabit Cloud Function from "
      'the screen, not this method -- see docs/BACKEND.md, Gaps/risks #1.',
    );
  }

  @override
  Future<void> addCoins(int amount) {
    throw UnsupportedError(
      'FirestoreUserRepository.addCoins: coins is a Cloud-Function-only '
      'field (docs/BACKEND.md, "Security rules") -- the deployed rules '
      'reject a direct client write to it. Call the relevant Cloud '
      'Function (claimHabit/unclaimHabit, purchaseCareItem, '
      'purchaseAccessory, ...) instead once it exists.',
    );
  }
}
