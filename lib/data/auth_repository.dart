import 'package:firebase_auth/firebase_auth.dart' show AuthCredential;

import '../models/nori_user.dart';
import 'user_repository.dart';

/// The contract every auth provider plugs into — [MockAuthRepository] for
/// local dev/demo, [FirebaseAuthRepository] (firebase_auth_repository.dart)
/// for the real thing. `app_data.dart` picks which one screens get; no
/// screen imports either implementation directly.
///
/// [AuthCredential] (from firebase_auth) leaking into this otherwise
/// provider-agnostic interface is a deliberate exception: account linking
/// is inherently tied to how the underlying provider represents a pending
/// credential, and there's only ever going to be one non-mock
/// implementation of this contract — see CLAUDE.md's note on not
/// over-engineering provider-swappability this project doesn't need.
abstract class AuthRepository {
  Future<NoriUser> signUp({
    required String name,
    required String username,
    required String email,
    required String password,
  });

  Future<NoriUser> logIn({required String email, required String password});

  /// Signs in (or, the first time, creates an account) with a Google
  /// account. Throws [AuthException] with a user-facing message if the
  /// person cancels the picker or the sign-in otherwise fails, or
  /// [GoogleAccountLinkingRequired] if that email already has a
  /// password-based Nori account — the caller should prompt for that
  /// account's password and retry via [linkGoogleAccount].
  ///
  /// [GoogleSignInResult.needsUsername] tells the caller whether to route
  /// through a username picker (new Google sign-up, or a previous attempt
  /// that never finished claiming one) before treating the person as
  /// signed in for real.
  Future<GoogleSignInResult> logInWithGoogle();

  /// Finishes a Google sign-in that [logInWithGoogle] flagged via
  /// [GoogleAccountLinkingRequired]: signs into the existing
  /// password-based account and links [pendingCredential] to it so future
  /// sign-ins can use either method. Throws [AuthException] if the
  /// password is wrong or linking otherwise fails.
  Future<GoogleSignInResult> linkGoogleAccount({
    required String email,
    required String password,
    required AuthCredential pendingCredential,
  });

  /// Signs the current user out. Screens should call this (not just
  /// navigate to `/welcome`) so a real backend actually ends the session —
  /// otherwise relaunching the app would just log the user back in.
  Future<void> logOut();

  /// Sends a password-reset email. Throws [AuthException] with a
  /// user-facing message on failure.
  Future<void> sendPasswordResetEmail(String email);

  /// Whether the signed-in user still needs to verify their email. Always
  /// false when signed out, signed in with Google (that email is already
  /// verified by Google), or in [MockAuthRepository] — this only applies
  /// to a real email/password Firebase account.
  Future<bool> needsEmailVerification();

  /// Re-sends Firebase's verification email to the current user. Throws
  /// [AuthException] with a user-facing message on failure.
  Future<void> sendEmailVerification();

  /// Id of whoever is currently signed in, or null if signed out. Read once
  /// at app startup (see main.dart) to decide whether to open straight to
  /// Home or to the Welcome screen.
  String? get currentUserId;
}

/// A message already safe to show in the UI — screens display
/// `e.message` directly instead of parsing provider-specific error codes.
class AuthException implements Exception {
  const AuthException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Outcome of a successful Google sign-in/sign-up. See
/// [AuthRepository.logInWithGoogle].
class GoogleSignInResult {
  const GoogleSignInResult({required this.user, required this.needsUsername});

  final NoriUser user;

  /// True when this Google account has no username claimed yet — either
  /// it's brand new, or a previous attempt got signed in but never
  /// finished the username step. [NoriUser.username] on [user] is a
  /// placeholder (not a claimed username) whenever this is true.
  final bool needsUsername;
}

/// Thrown by [AuthRepository.logInWithGoogle] when the Google account's
/// email already has a password-based Nori account (the only other
/// sign-in method this app supports). Carries what
/// [AuthRepository.linkGoogleAccount] needs to finish connecting the two
/// once the person re-enters that account's password.
class GoogleAccountLinkingRequired implements Exception {
  const GoogleAccountLinkingRequired({
    required this.email,
    required this.pendingCredential,
  });

  final String email;
  final AuthCredential pendingCredential;
}

class MockAuthRepository implements AuthRepository {
  String? _currentUserId;

  @override
  String? get currentUserId => _currentUserId;

  @override
  Future<NoriUser> signUp({
    required String name,
    required String username,
    required String email,
    required String password,
  }) async {
    await Future.delayed(const Duration(milliseconds: 300));
    _currentUserId = 'mock-user';
    return NoriUser(
      id: 'mock-user',
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

  @override
  Future<NoriUser> logIn({
    required String email,
    required String password,
  }) async {
    await Future.delayed(const Duration(milliseconds: 300));
    _currentUserId = kDemoUser.id;
    return kDemoUser;
  }

  @override
  Future<void> logOut() async {
    await Future.delayed(const Duration(milliseconds: 100));
    _currentUserId = null;
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    await Future.delayed(const Duration(milliseconds: 300));
  }

  @override
  Future<bool> needsEmailVerification() async => false;

  @override
  Future<void> sendEmailVerification() async {
    await Future.delayed(const Duration(milliseconds: 300));
  }

  @override
  Future<GoogleSignInResult> logInWithGoogle() async {
    await Future.delayed(const Duration(milliseconds: 300));
    _currentUserId = kDemoUser.id;
    return GoogleSignInResult(user: kDemoUser, needsUsername: false);
  }

  @override
  Future<GoogleSignInResult> linkGoogleAccount({
    required String email,
    required String password,
    required AuthCredential pendingCredential,
  }) async {
    await Future.delayed(const Duration(milliseconds: 300));
    _currentUserId = kDemoUser.id;
    return GoogleSignInResult(user: kDemoUser, needsUsername: false);
  }
}
