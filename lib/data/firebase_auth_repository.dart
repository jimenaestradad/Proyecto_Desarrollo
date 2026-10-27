import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';

import '../models/nori_user.dart';
import 'auth_repository.dart';
import 'cloud_functions_client.dart';
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
       // Web signs in with Google through Firebase's own popup (see
       // _signInWithGoogle), so the plugin is never needed there -- and
       // just constructing it on web kicks off an init that fails without
       // a web client ID, logging a red assertion on every launch.
       _googleSignIn = googleSignIn ?? (kIsWeb ? null : GoogleSignIn()),
       _usernames = usernames ?? FirestoreUsernameRepository();

  final FirebaseAuth _auth;
  final GoogleSignIn? _googleSignIn;
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
      // Best-effort like the verification email below: the account already
      // exists, and failing here would leave it stranded (retrying sign-up
      // says "email already in use"). The Firestore profile holds the name.
      try {
        await credential.user?.updateDisplayName(name);
      } catch (_) {}
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
      // The real claimed username lives in /usernames, not on the Firebase
      // Auth record (only displayName/email do) -- looking it up here
      // mirrors _resultFor's Google-sign-in path below. Without this,
      // updateProfile(username: ...) back in login_screen.dart would
      // overwrite the real /users/{uid}.username with the display name on
      // every single login (this was a real bug: username got clobbered
      // back to the person's full name each time they signed back in).
      final existingUsername = await _usernames.usernameForUid(user.uid);
      return _starterUser(
        id: user.uid,
        name: user.displayName ?? fallbackName,
        username: existingUsername ?? user.displayName ?? fallbackName,
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
      final linkedCredential = await passwordCredential.user!
          .linkWithCredential(pendingCredential);
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
      return await _auth.signInWithCredential(await _nativeGoogleCredential());
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

  /// Shows the native Google account picker and returns the chosen
  /// account's credential, for a sign-in or a re-authentication.
  Future<AuthCredential> _nativeGoogleCredential() async {
    // Forget any cached account selection first so the native picker is
    // always shown too — GoogleSignIn.signIn() otherwise silently
    // re-authenticates the last-used account without prompting. This
    // only clears the local selection, it doesn't revoke access, so
    // re-picking the same account below won't ask for consent again.
    await _googleSignIn!.signOut();
    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) {
      // Person closed the account picker — not a real error, just no
      // sign-in to complete.
      throw const AuthException('Sign-in was canceled.');
    }
    final googleAuth = await googleUser.authentication;
    return GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
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
    if (!kIsWeb && await _googleSignIn!.isSignedIn()) {
      await _googleSignIn.signOut();
    }
    await _auth.signOut();
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      // Reported the same as a sent email, so this form can't be used to
      // check which addresses have an account (OWASP: generic auth errors).
      if (e.code == 'user-not-found') return;
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
      // One message for all three, so a failed login doesn't reveal
      // whether the email has an account.
      case 'user-not-found':
      case 'invalid-credential':
      case 'wrong-password':
        return 'Incorrect email or password.';
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

  @override
  Future<bool> hasPasswordProvider() async {
    final user = _auth.currentUser;
    if (user == null) return false;
    return user.providerData.any((p) => p.providerId == 'password');
  }

  @override
  Future<void> addPassword(String password) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw const AuthException('You need to be signed in to do that.');
    }
    final email = user.email;
    if (email == null || email.isEmpty) {
      throw const AuthException("Your account doesn't have an email on file.");
    }
    try {
      await user.linkWithCredential(
        EmailAuthProvider.credential(email: email, password: password),
      );
    } on FirebaseAuthException catch (e) {
      throw AuthException(_addPasswordMessage(e.code));
    }
  }

  String _addPasswordMessage(String code) {
    switch (code) {
      case 'weak-password':
        return 'Choose a password with at least 6 characters.';
      case 'provider-already-linked':
      case 'credential-already-in-use':
      case 'email-already-in-use':
        return 'This account already has a password set.';
      case 'requires-recent-login':
        return 'Please sign out and back in, then try again.';
      case 'network-request-failed':
        return 'No internet connection. Please try again.';
      default:
        return 'Unable to set a password. Please try again.';
    }
  }

  @override
  String? get currentEmail => _auth.currentUser?.email;

  @override
  String? get currentDisplayName => _auth.currentUser?.displayName;

  @override
  Future<void> changeEmail({
    required String newEmail,
    required String password,
  }) async {
    final user = _auth.currentUser;
    final email = user?.email;
    if (user == null || email == null || email.isEmpty) {
      throw const AuthException('You need to be signed in to do that.');
    }
    try {
      // Re-checking the password up front avoids Firebase's
      // requires-recent-login rejection, which an email change almost
      // always hits on a session restored from a previous launch.
      await user.reauthenticateWithCredential(
        EmailAuthProvider.credential(email: email, password: password),
      );
      await user.verifyBeforeUpdateEmail(newEmail);
    } on FirebaseAuthException catch (e) {
      throw AuthException(_changeEmailMessage(e.code));
    }
  }

  String _changeEmailMessage(String code) {
    switch (code) {
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect password. Try again.';
      case 'invalid-email':
        return 'That email address looks invalid.';
      case 'email-already-in-use':
        return 'That email already has an account.';
      case 'too-many-requests':
        return 'Too many attempts — please wait a moment and try again.';
      case 'network-request-failed':
        return 'No internet connection. Please try again.';
      default:
        return 'Unable to change your email. Please try again.';
    }
  }

  /// Proves the signed-in user is still them, so the server's
  /// "signed in recently" check on deleteAccount passes. Uses the password
  /// when one is given, otherwise asks for Google again.
  Future<void> _reauthenticate(User user, String? password) async {
    if (password != null) {
      final email = user.email;
      if (email == null) {
        throw const AuthException("Couldn't confirm your password.");
      }
      await user.reauthenticateWithCredential(
        EmailAuthProvider.credential(email: email, password: password),
      );
    } else if (kIsWeb) {
      await user.reauthenticateWithPopup(
        GoogleAuthProvider()..setCustomParameters({'prompt': 'select_account'}),
      );
    } else {
      await user.reauthenticateWithCredential(await _nativeGoogleCredential());
    }
    // The callable sends the cached ID token: refresh it so its auth_time is
    // the sign-in that just happened.
    await user.getIdToken(true);
  }

  String _reauthMessage(String code) {
    switch (code) {
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect password. Try again.';
      case 'user-mismatch':
        return "That isn't the account you're signed in with.";
      case 'too-many-requests':
        return 'Too many attempts — please wait a moment and try again.';
      case 'network-request-failed':
        return 'No internet connection. Please try again.';
      case 'popup-closed-by-user':
      case 'cancelled-popup-request':
        return 'Sign-in was canceled.';
      default:
        return "Couldn't confirm it's you. Please try again.";
    }
  }

  @override
  Future<void> deleteAccount({String? password}) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw const AuthException('You need to be signed in to do that.');
    }
    try {
      await _reauthenticate(user, password);
    } on FirebaseAuthException catch (e) {
      throw AuthException(_reauthMessage(e.code));
    }
    try {
      // Generous timeout: it deletes every doc the account owns.
      await callCloudFunction(
        'deleteAccount',
        const {},
        timeout: const Duration(seconds: 60),
      );
    } on CloudFunctionFailure catch (e) {
      throw AuthException(e.message);
    }
    // The Auth user is gone server-side; this just clears the local session.
    await logOut();
  }
}
