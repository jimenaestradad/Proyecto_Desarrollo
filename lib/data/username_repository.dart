import 'package:cloud_firestore/cloud_firestore.dart';

/// Thrown by [UsernameRepository.claim] when someone already holds the
/// username (case-insensitively) by the time the claim commits — including
/// a concurrent claim that lands mid-transaction.
class UsernameTakenException implements Exception {
  const UsernameTakenException(this.username);
  final String username;

  @override
  String toString() => 'Username "$username" is already taken.';
}

/// Backs the `/usernames` uniqueness collection in Firestore (see
/// `firestore.rules`). Used by both the email/password sign-up flow
/// (sign_up_screen.dart) and the Google Sign-In username picker
/// (choose_username_screen.dart).
abstract class UsernameRepository {
  /// Checks case-insensitive availability without reserving the username.
  /// Callers must still handle [UsernameTakenException] from [claim].
  Future<bool> isAvailable(String username);

  /// Atomically claims [username] for [uid]. Throws
  /// [UsernameTakenException] if someone else holds it. Claiming a name
  /// [uid] already holds is a no-op, so a sign-up that claimed it and then
  /// failed later can safely run again.
  Future<void> claim({required String username, required String uid});

  /// The username already claimed by [uid], or null if they haven't
  /// claimed one yet. Used by the Google Sign-In flow to tell an existing
  /// account (route straight in) apart from one that still needs the
  /// username picker.
  Future<String?> usernameForUid(String uid);

  /// Atomically moves [uid]'s claim and updates the user's username.
  /// Throws [UsernameTakenException] when taken; case-insensitive equality is a no-op
  /// because display casing lives on the user document.
  Future<void> changeUsername({
    required String uid,
    required String oldUsername,
    required String newUsername,
  });
}

/// Suggests a username from the email local part, lowercased and stripped to
/// letters, digits and underscores; uses a generic fallback if nothing remains.
String suggestUsernameFromEmail(String email) {
  final localPart = email.split('@').first;
  final cleaned = localPart.toLowerCase().replaceAll(RegExp(r'[^a-z0-9_]'), '');
  return cleaned.length >= 3 ? cleaned : 'nori_fan';
}

class FirestoreUsernameRepository implements UsernameRepository {
  FirestoreUsernameRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _usernames =>
      _firestore.collection('usernames');

  /// Usernames collide case-insensitively ("Alex" and "alex" are the same
  /// claim), so the doc id is always the lowercased form; the
  /// human-typed casing is kept in the `username` field for display.
  String _key(String username) => username.trim().toLowerCase();

  @override
  Future<bool> isAvailable(String username) async {
    final key = _key(username);
    if (key.isEmpty) return false;
    final doc = await _usernames.doc(key).get();
    return !doc.exists;
  }

  @override
  Future<void> claim({required String username, required String uid}) async {
    final key = _key(username);
    final ref = _usernames.doc(key);
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(ref);
      if (snapshot.exists) {
        if (snapshot.data()?['uid'] == uid) return;
        throw UsernameTakenException(username);
      }
      transaction.set(ref, {
        'uid': uid,
        'username': username.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  }

  @override
  Future<String?> usernameForUid(String uid) async {
    final query = await _usernames.where('uid', isEqualTo: uid).limit(1).get();
    if (query.docs.isEmpty) return null;
    return query.docs.first.data()['username'] as String?;
  }

  @override
  Future<void> changeUsername({
    required String uid,
    required String oldUsername,
    required String newUsername,
  }) async {
    final oldKey = _key(oldUsername);
    final newKey = _key(newUsername);
    if (newKey == oldKey) return;
    final oldRef = _usernames.doc(oldKey);
    final newRef = _usernames.doc(newKey);
    // Check before the transaction to surface UsernameTakenException without wrapping.
    // Keep the transaction check as the atomic guard against competing claims.
    final existing = await newRef.get();
    if (existing.exists && existing.data()?['uid'] != uid) {
      throw UsernameTakenException(newUsername);
    }
    await _firestore.runTransaction((transaction) async {
      // All reads before writes -- Firestore transaction rule.
      final newSnapshot = await transaction.get(newRef);
      final oldSnapshot = await transaction.get(oldRef);
      // Already ours: a retry after the profile save failed once, when this
      // transaction had committed. Finish the move instead of reporting "taken".
      final newIsMine = newSnapshot.data()?['uid'] == uid;
      if (newSnapshot.exists && !newIsMine) {
        throw UsernameTakenException(newUsername);
      }
      if (!newIsMine) {
        transaction.set(newRef, {
          'uid': uid,
          'username': newUsername.trim(),
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      // The rules only allow deleting a doc that exists and is ours.
      if (oldSnapshot.data()?['uid'] == uid) transaction.delete(oldRef);
      // Same transaction, so the index and the profile can't disagree if
      // the later profile save fails.
      transaction.update(_firestore.collection('users').doc(uid), {
        'username': newUsername.trim(),
      });
    });
  }
}
