import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';

import '../models/nori_user.dart';
import 'auth_repository.dart';
import 'username_repository.dart';

/// Real Firebase Authentication-backed [AuthRepository]: email/password and
/// Google Sign-In, plus the username-uniqueness/account-linking pieces of
/// Google Sign-In that live in [UsernameRepository].
///
/// This only proves *who* is signed in. The rest of that person's profile
/// (level, XP, coins, streak, ...) still comes from [UserRepository]'s mock
/// today — connecting that to real per-user data in Firestore is a
/// separate, bigger task (see docs/OPEN_DECISIONS.md), not part of "auth
/// simple". On sign-up/login this hands back a fresh starter [NoriUser]
/// shell so the rest of the app (which expects a NoriUser back from auth)
/// keeps working unchanged.
class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository({
    FirebaseAuth? auth,
    GoogleSignIn? googleSignIn,
    UsernameRepository? usernames,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _googleSignIn = googleSignIn ?? GoogleSignIn(),
       _usernames = usernames ?? FirestoreUsernameRepository();

  final FirebaseAuth _auth;
  final GoogleSignIn _googleSignIn;
  final UsernameRepository _usernames;

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
      try {
        await credential.user?.sendEmailVerification();
      } catch (_) {
        // Best-effort: the account is already created either way, and the
        // banner's own Resend button is the real backstop if this fails
        // (e.g. no network right at this instant).
      }
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
  Future<GoogleSignInResult> logInWithGoogle() async {
    try {
      final userCredential = await _signInWithGoogle();
      return _resultFor(userCredential);
    } on FirebaseAuthException catch (e) {
      throw AuthException(_logInMessage(e.code));
    }
  }

  @override
  Future<GoogleSignInResult> linkGoogleAccount({
    required String email,
    required String password,
    required AuthCredential pendingCredential,
  }) async {
    try {
      final passwordCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      final linkedCredential = await passwordCredential.user!.linkWithCredential(
        pendingCredential,
      );
      return _resultFor(linkedCredential);
    } on FirebaseAuthException catch (e) {
      throw AuthException(_logInMessage(e.code));
    }
  }

  /// Runs the platform-appropriate Google Sign-In popup/picker and returns
  /// the resulting [UserCredential], translating the one error case the
  /// callers above need to handle specially (a password-based account
  /// already exists for that email) into [GoogleAccountLinkingRequired]
  /// rather than letting it fall through as a generic sign-in failure.
  Future<UserCredential> _signInWithGoogle() async {
    try {
      if (kIsWeb) {
        // On web, Firebase's own popup flow needs no native setup at all —
        // no SHA-1, no Android SDK — which is what this machine can
        // actually test today (`flutter run -d chrome`). This is the path
        // exercised during dev; see the else-branch below for the native
        // Android flow that ships to production (needs the SHA-1
        // fingerprint registered in Firebase console — see
        // docs/OPEN_DECISIONS.md).
        //
        // 'prompt': 'select_account' forces Google's account chooser to
        // show every time, even when the browser only has one Google
        // session signed in — without it, signInWithPopup silently
        // re-authenticates whichever account was used last instead of
        // letting the person pick (or switch accounts).
        final provider = GoogleAuthProvider()
          ..setCustomParameters({'prompt': 'select_account'});
        return await _auth.signInWithPopup(provider);
      }
      // Forget any cached account selection first so the native picker is
      // always shown too — GoogleSignIn.signIn() otherwise silently
      // re-authenticates the last-used account without prompting. This
      // only clears the local selection, it doesn't revoke access, so
      // re-picking the same account below won't ask for consent again.
      await _googleSignIn.signOut();
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        // Person closed the account picker — not a real error, just no
        // sign-in to complete.
        throw const AuthException('Sign-in was canceled.');
      }
      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      return await _auth.signInWithCredential(credential);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'account-exists-with-different-credential') {
        // The only other sign-in method this app supports is
        // email/password, so a conflict here can only mean that: the
        // caller (login_screen.dart) catches this specific type and
        // prompts for that account's password instead of showing a plain
        // error.
        throw GoogleAccountLinkingRequired(
          email: e.email ?? '',
          pendingCredential: e.credential!,
        );
      }
      rethrow;
    }
  }

  /// Builds the [GoogleSignInResult] for a just-authenticated Google user:
  /// looks up whether this uid has already claimed a username (an
  /// existing account, or a re-run of a previously-interrupted sign-up) to
  /// decide whether the caller needs to route through the username picker.
  Future<GoogleSignInResult> _resultFor(UserCredential userCredential) async {
    final user = userCredential.user!;
    final email = user.email ?? '';
    final existingUsername = await _usernames.usernameForUid(user.uid);
    final fallbackName = email.contains('@') ? email.split('@').first : email;
    return GoogleSignInResult(
      user: _starterUser(
        id: user.uid,
        name: user.displayName ?? fallbackName,
        // Not a real username when null — just a placeholder so the
        // NoriUser shell is valid; needsUsername tells the caller not to
        // treat it as one.
        username: existingUsername ?? fallbackName,
        email: email,
      ),
      needsUsername: existingUsername == null,
    );
  }

  @override
  Future<void> logOut() async {
    // On web, Google sign-in goes through Firebase's own popup
    // (_auth.signInWithPopup, see _signInWithGoogle) rather than the
    // google_sign_in plugin, so _googleSignIn was never actually used to
    // sign in there. Calling it here anyway throws on web (no web client
    // ID is configured for that plugin, since it's never otherwise
    // needed) -- and since nothing caught that, it silently broke this
    // entire method, logout included. Only exercise it on the platforms
    // that actually use it (see the native branch of _signInWithGoogle).
    if (!kIsWeb && await _googleSignIn.isSignedIn()) {
      await _googleSignIn.signOut();
    }
    await _auth.signOut();
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw AuthException(_resetMessage(e.code));
    }
  }

  @override
  Future<bool> needsEmailVerification() async {
    final user = _auth.currentUser;
    if (user == null) return false;
    final isPasswordAccount = user.providerData.any(
      (p) => p.providerId == 'password',
    );
    if (!isPasswordAccount) return false;
    try {
      // emailVerified on the cached currentUser can be stale if the person
      // verified in another tab/device — reload before trusting it.
      await user.reload();
    } catch (_) {
      // Offline or otherwise unreachable right now; fall back to the
      // last-known value below rather than blocking the banner on this.
    }
    return !(_auth.currentUser?.emailVerified ?? true);
  }

  @override
  Future<void> sendEmailVerification() async {
    try {
      await _auth.currentUser?.sendEmailVerification();
    } on FirebaseAuthException catch (e) {
      throw AuthException(_verificationMessage(e.code));
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

  String _verificationMessage(String code) {
    switch (code) {
      case 'too-many-requests':
        return 'Too many requests — please wait a moment and try again.';
      case 'network-request-failed':
        return 'No internet connection. Please try again.';
      default:
        return 'Unable to send the verification email. Please try again.';
    }
  }
}
