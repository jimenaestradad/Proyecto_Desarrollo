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
  /// Case-insensitive availability check for live "is this taken" UI as
  /// someone types. This is advisory only, not a reservation — the
  /// username can be taken by someone else between this check and a later
  /// [claim] call, so callers must still handle [UsernameTakenException]
  /// from claim itself rather than trusting this alone.
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

  /// Atomically moves [uid]'s claim from [oldUsername] to [newUsername] --
  /// create-new + delete-old in one transaction, per firestore.rules's own
  /// note that a username change is spec'd that way (delete is only
  /// allowed for the owning uid so this is the one flow that can do it).
  /// Also writes `users/{uid}.username` in that same transaction.
  /// Throws [UsernameTakenException] if [newUsername] is already held by
  /// someone else. A no-op when [newUsername] equals [oldUsername]
  /// case-insensitively (nothing to move in this collection -- the
  /// human-typed display casing lives on users/{uid}.username, not here).
  Future<void> changeUsername({
    required String uid,
    required String oldUsername,
    required String newUsername,
  });
}

/// Turns an email address into a starting suggestion for the username
/// picker — the part before '@', lowercased and stripped down to
/// letters/digits/underscore (real email local-parts can contain '+',
/// '.', etc. that aren't a username this app wants to allow). Falls back
/// to a generic suggestion if that leaves nothing usable.
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
    // Checked up front as well as inside the transaction: an exception thrown
    // from a transaction handler can come back wrapped, so Edit Profile never
    // saw UsernameTakenException and showed "Unable to save changes" for a
    // plainly taken name. The in-transaction check stays as the atomic guard
    // against two people claiming it at once.
    final existing = await newRef.get();
    if (existing.exists && existing.data()?['uid'] != uid) {
      throw UsernameTakenException(newUsername);
    }
    await _firestore.runTransaction((transaction) async {
      // All reads before writes -- Firestore transaction rule.
      final newSnapshot = await transaction.get(newRef);
      if (newSnapshot.exists) {
        throw UsernameTakenException(newUsername);
      }
      transaction.set(newRef, {
        'uid': uid,
        'username': newUsername.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      });
      transaction.delete(oldRef);
      // Same transaction, so the index and the profile can't disagree if
      // the later profile save fails.
      transaction.update(_firestore.collection('users').doc(uid), {
        'username': newUsername.trim(),
      });
    });
  }
}
