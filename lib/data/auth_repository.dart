import 'package:firebase_auth/firebase_auth.dart' show AuthCredential;

import '../models/nori_user.dart';
import 'user_repository.dart';

/// Authentication contract selected by `app_data.dart` for screens.
/// [AuthCredential] exposes the provider's pending credential for account linking.
abstract class AuthRepository {
  Future<NoriUser> signUp({
    required String name,
    required String username,
    required String email,
    required String password,
  });

  Future<NoriUser> logIn({required String email, required String password});

  /// Signs in with Google; throws [AuthException] or [GoogleAccountLinkingRequired].
  /// Use [linkGoogleAccount] for an existing password account and
  /// [GoogleSignInResult.needsUsername] to route unfinished username setup.
  Future<GoogleSignInResult> logInWithGoogle();

  /// Signs into an existing password account and links [pendingCredential].
  /// Throws [AuthException] if authentication or linking fails.
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

  /// Emits when a signed-in session ends without the person asking: the token
  /// expired or was revoked, or the account was disabled or deleted elsewhere.
  /// Never emits for [logOut] or [deleteAccount]; those screens navigate on
  /// their own. Listened to once, by the app shell (main.dart).
  Stream<void> get sessionLost;

  /// Whether email/password login is available; gates the [addPassword] option.
  /// Always true in [MockAuthRepository] or when signed out.
  Future<bool> hasPasswordProvider();

  /// Adds password login to the current Google-only account, preserving its uid.
  /// Throws [AuthException] with a user-facing failure message.
  Future<void> addPassword(String password);

  /// The email the signed-in user actually logs in with, or null when
  /// signed out. This, not the Firestore profile's copy, is the source of
  /// truth: a [changeEmail] only lands here once the link is clicked.
  String? get currentEmail;

  /// The signed-in account's display name (set at sign-up, or by Google), or
  /// null when signed out or none was set. Only a fallback for filling in a
  /// profile that was never written; the Firestore profile owns the name.
  String? get currentDisplayName;

  /// Starts changing the login email of a password account: re-checks
  /// [password], then emails a confirmation link to [newEmail]. The login
  /// email only changes once that link is clicked. Throws [AuthException]
  /// with a user-facing message on failure (wrong password, email taken).
  Future<void> changeEmail({
    required String newEmail,
    required String password,
  });

  /// Changes the password of a password account: re-checks [currentPassword],
  /// then sets [newPassword]. Throws [AuthException] with a user-facing
  /// message on failure (wrong current password, weak new one).
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  });

  /// Re-authenticates, deletes the account and its data, then signs out.
  /// Supply [password] for password accounts; Google-only accounts use Google's picker.
  /// Throws [AuthException] on failure.
  Future<void> deleteAccount({String? password});
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

/// Signals a Google email already registered with password authentication.
/// Carries the credentials [AuthRepository.linkGoogleAccount] needs after password entry.
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
  Stream<void> get sessionLost => const Stream.empty();

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

  @override
  Future<bool> hasPasswordProvider() async => true;

  @override
  Future<void> addPassword(String password) async {
    await Future.delayed(const Duration(milliseconds: 300));
  }

  @override
  String? get currentEmail => _currentUserId == null ? null : kDemoUser.email;

  @override
  String? get currentDisplayName =>
      _currentUserId == null ? null : kDemoUser.name;

  @override
  Future<void> changeEmail({
    required String newEmail,
    required String password,
  }) async {
    await Future.delayed(const Duration(milliseconds: 300));
  }

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await Future.delayed(const Duration(milliseconds: 300));
  }

  @override
  Future<void> deleteAccount({String? password}) async {
    await Future.delayed(const Duration(milliseconds: 300));
    _currentUserId = null;
  }
}
