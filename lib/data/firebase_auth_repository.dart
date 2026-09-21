import 'package:firebase_auth/firebase_auth.dart';

import '../models/nori_user.dart';
import 'auth_repository.dart';

/// Real Firebase Authentication-backed [AuthRepository] (email/password
/// only — Google Sign-In is a separate task on the board). Swapped in for
/// [MockAuthRepository] in `app_data.dart`.
///
/// This only proves *who* is signed in. The rest of that person's profile
/// (level, XP, coins, streak, ...) still comes from [UserRepository]'s mock
/// today — connecting that to real per-user data in Firestore is a
/// separate, bigger task (see docs/OPEN_DECISIONS.md), not part of "auth
/// simple". On sign-up/login this hands back a fresh starter [NoriUser]
/// shell so the rest of the app (which expects a NoriUser back from auth)
/// keeps working unchanged.
class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository({FirebaseAuth? auth})
    : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;

  @override
  String? get currentUserId => _auth.currentUser?.uid;

  @override
  Future<NoriUser> signUp({
    required String name,
    required String username,
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      await credential.user?.updateDisplayName(name);
      return _starterUser(
        id: credential.user!.uid,
        name: name,
        username: username,
        email: email,
      );
    } on FirebaseAuthException catch (e) {
      throw AuthException(_signUpMessage(e.code));
    }
  }

  @override
  Future<NoriUser> logIn({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      final user = credential.user!;
      final fallbackName = email.contains('@') ? email.split('@').first : email;
      return _starterUser(
        id: user.uid,
        name: user.displayName ?? fallbackName,
        username: user.displayName ?? fallbackName,
        email: email,
      );
    } on FirebaseAuthException catch (e) {
      throw AuthException(_logInMessage(e.code));
    }
  }

  @override
  Future<void> logOut() => _auth.signOut();

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw AuthException(_resetMessage(e.code));
    }
  }

  NoriUser _starterUser({
    required String id,
    required String name,
    required String username,
    required String email,
  }) {
    return NoriUser(
      id: id,
      name: name,
      username: username,
      email: email,
      level: 1,
      totalXp: 0,
      xpIntoLevel: 0,
      xpForNextLevel: 100,
      currentStreak: 0,
    );
  }

  String _signUpMessage(String code) {
    switch (code) {
      case 'email-already-in-use':
        return 'That email already has an account — try logging in instead.';
      case 'invalid-email':
        return 'That email address looks invalid.';
      case 'weak-password':
        return 'Choose a password with at least 6 characters.';
      case 'operation-not-allowed':
        return 'Email/password sign-up isn\'t enabled for this project yet.';
      case 'network-request-failed':
        return 'No internet connection. Please try again.';
      default:
        return 'Unable to create your account. Please try again.';
    }
  }

  String _logInMessage(String code) {
    switch (code) {
      case 'user-not-found':
      case 'invalid-credential':
        return 'No account found with that email and password.';
      case 'wrong-password':
        return 'Incorrect password. Try again.';
      case 'invalid-email':
        return 'That email address looks invalid.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'too-many-requests':
        return 'Too many attempts — please wait a moment and try again.';
      case 'network-request-failed':
        return 'No internet connection. Please try again.';
      default:
        return 'Unable to sign in. Please try again.';
    }
  }

  String _resetMessage(String code) {
    switch (code) {
      case 'user-not-found':
        return 'No account found with that email.';
      case 'invalid-email':
        return 'That email address looks invalid.';
      case 'network-request-failed':
        return 'No internet connection. Please try again.';
      default:
        return 'Unable to send the reset email. Please try again.';
    }
  }
}
