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
  /// [UsernameTakenException] if it's already held.
  Future<void> claim({required String username, required String uid});

  /// The username already claimed by [uid], or null if they haven't
  /// claimed one yet. Used by the Google Sign-In flow to tell an existing
  /// account (route straight in) apart from one that still needs the
  /// username picker.
  Future<String?> usernameForUid(String uid);
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
}
