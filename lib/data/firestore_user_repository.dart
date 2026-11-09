import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/nori_user.dart';
import '../utils/provisioning_retry.dart';
import 'calendar_repository.dart';
import 'user_repository.dart';
import 'vacation_log.dart';

/// Firestore profile and vacation fields; categories use [HabitCategoryRepository].
/// Bound after authentication; `onUserCreate` must provision the user document.
/// Brief retries absorb the provisioning race.
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

  NoriUser? _lastKnownUser;

  @override
  NoriUser? get lastKnownUser => _lastKnownUser;

  @override
  Future<NoriUser> getCurrentUser() async {
    // Derive currentStreak through the calendar repository rather than storing it.
    // Fetch it alongside the independent user-document read.
    final (data, streak) = await (
      _getDataWithRetry(),
      _calendar.getCurrentStreak(),
    ).wait;
    return _lastKnownUser = NoriUser(
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

  /// Reads the user document with bounded retries while `onUserCreate` finishes.
  /// Auth account creation may return before the document exists.
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
          'yet (see docs/technical/BACKEND.md, Cloud Functions). FirestoreUserRepository '
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
      'name': ?name,
      'username': ?username,
      'email': ?email,
    };
    if (updates.isEmpty) return;
    // Right after sign-up/login this can land before onUserCreate has
    // provisioned the doc — see retryWhileProvisioning.
    await retryWhileProvisioning(() => _doc.update(updates));
  }

  @override
  Future<bool> hasProfile() async {
    final data = (await _doc.get()).data();
    if (data == null) return false;
    return (data['name'] as String? ?? '').trim().isNotEmpty &&
        (data['username'] as String? ?? '').trim().isNotEmpty;
  }

  @override
  Future<void> setVacationMode(bool enabled) async {
    final now = DateTime.now();
    // FirestoreVacationLog writes `vacationRanges` and `vacationModeEnabled`
    // together in one update, and the calendar reads freeze history from
    // that same shared instance. Awaited so a failed write reaches the
    // caller instead of the toggle reporting success.
    if (enabled) {
      await _vacationLog.startFreeze(now);
    } else {
      await _vacationLog.endFreeze(now);
    }
  }
}
