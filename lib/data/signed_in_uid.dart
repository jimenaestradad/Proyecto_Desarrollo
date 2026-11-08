import 'package:firebase_auth/firebase_auth.dart';

/// Resolves the current uid for repositories that persist across sign-ins.
/// Throws [StateError] naming [caller] if used before login.
String requireSignedInUid(String caller) {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    throw StateError('$caller used with no signed-in user');
  }
  return user.uid;
}
