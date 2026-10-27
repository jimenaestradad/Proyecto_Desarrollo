import 'package:firebase_auth/firebase_auth.dart';

/// The signed-in user's uid, for repositories that look it up on every call
/// instead of being handed one (the habit and vacation repositories live in
/// `AppData` for the whole session, across sign-ins). Throws a [StateError]
/// naming [caller] if nobody is signed in — using one before login is a bug,
/// not a case to recover from.
String requireSignedInUid(String caller) {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    throw StateError('$caller used with no signed-in user');
  }
  return user.uid;
}
