import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';

import '../models/nori_user.dart';
import 'auth_repository.dart';
import 'cloud_functions_client.dart';
import 'session_watch.dart';
import 'username_repository.dart';
import '../utils/app_log.dart';
import '../utils/validators.dart' show passwordMinLength;

/// Firebase email/password and Google authentication with [UsernameRepository] linking.
/// Returns a starter [NoriUser] shell; authentication establishes identity.
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
  final SessionWatch _session = SessionWatch();

  @override
  String? get currentUserId => _auth.currentUser?.uid;

  @override
  Stream<void> get sessionLost =>
      _session.lost(_auth.authStateChanges().map((user) => user != null));

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
      logError('signUp', e);
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
      // Read the claimed username from /usernames, rather than Auth's displayName,
      // so login does not overwrite /users/{uid}.username with the person's full name.
      // Only fills the returned shell, which the callers use for the id and
      // email. If the lookup fails the person IS signed in, so a failure here
      // must not read as "Unable to sign in"; the login screen runs its own
      // sign-up-complete check right after and handles an unreachable server.
      String? existingUsername;
      try {
        existingUsername = await _usernames.usernameForUid(user.uid);
      } catch (error, stackTrace) {
        logError('logIn username lookup', error, stackTrace);
      }
      return _starterUser(
        id: user.uid,
        name: user.displayName ?? fallbackName,
        username: existingUsername ?? user.displayName ?? fallbackName,
        email: email,
      );
    } on FirebaseAuthException catch (e) {
      logError('logIn', e);
      throw AuthException(_logInMessage(e.code));
    }
  }

  @override
  Future<GoogleSignInResult> logInWithGoogle() async {
    try {
      final userCredential = await _signInWithGoogle();
      return _resultFor(userCredential);
    } on FirebaseAuthException catch (e) {
      logError('logInWithGoogle', e);
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
      logError('linkGoogleAccount', e);
      throw AuthException(_logInMessage(e.code));
    }
  }

  /// Runs the platform Google picker and returns its [UserCredential].
  /// Translates existing password-account conflicts to [GoogleAccountLinkingRequired].
  Future<UserCredential> _signInWithGoogle() async {
    try {
      if (kIsWeb) {
        // Firebase's web popup needs no native setup.
        // Force select_account so each sign-in lets the person choose an account.
        final provider = GoogleAuthProvider()
          ..setCustomParameters({'prompt': 'select_account'});
        return await _auth.signInWithPopup(provider);
      }
      return await _auth.signInWithCredential(await _nativeGoogleCredential());
    } on FirebaseAuthException catch (e) {
      if (e.code == 'account-exists-with-different-credential') {
        // Email/password is the only other supported provider.
        // Login catches this conflict to request the existing account's password.
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
    // Clear the cached native selection to show the account picker each time.
    // This does not revoke access or require consent again for the same account.
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
    if (_auth.currentUser != null) _session.expectEnd();
    // Only sign out of google_sign_in on native platforms that use it.
    // Web uses Firebase's popup; the plugin has no web client ID configured.
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
      logError('sendEmailVerification', e);
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

  /// Firebase's own floor is 6, so this only appears if the app's check was
  /// bypassed; it must still state the app's rule, not Firebase's.
  static const _weakPasswordMessage =
      'Choose a password with at least $passwordMinLength characters, '
      'including a letter and a number.';

  String _signUpMessage(String code) {
    switch (code) {
      case 'email-already-in-use':
        return 'That email already has an account — try logging in instead.';
      case 'invalid-email':
        return 'That email address looks invalid.';
      case 'weak-password':
        return _weakPasswordMessage;
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
      logError('addPassword', e);
      throw AuthException(_addPasswordMessage(e.code));
    }
  }

  String _addPasswordMessage(String code) {
    switch (code) {
      case 'weak-password':
        return _weakPasswordMessage;
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
      logError('changeEmail', e);
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

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = _auth.currentUser;
    final email = user?.email;
    if (user == null || email == null || email.isEmpty) {
      throw const AuthException('You need to be signed in to do that.');
    }
    try {
      // Checking the current password also satisfies Firebase's
      // requires-recent-login rule for updatePassword.
      await user.reauthenticateWithCredential(
        EmailAuthProvider.credential(email: email, password: currentPassword),
      );
      await user.updatePassword(newPassword);
    } on FirebaseAuthException catch (e) {
      logError('changePassword', e);
      throw AuthException(_changePasswordMessage(e.code));
    }
  }

  String _changePasswordMessage(String code) {
    switch (code) {
      case 'wrong-password':
      case 'invalid-credential':
        return 'Your current password is incorrect.';
      case 'weak-password':
        return _weakPasswordMessage;
      case 'too-many-requests':
        return 'Too many attempts — please wait a moment and try again.';
      case 'network-request-failed':
        return 'No internet connection. Please try again.';
      default:
        return 'Unable to change your password. Please try again.';
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
      logError('deleteAccount (re-authenticate)', e);
      throw AuthException(_reauthMessage(e.code));
    }
    // The server removes the Auth user, which can sign this device out
    // before logOut below runs; that is not a lost session.
    _session.expectEnd();
    try {
      // Generous timeout: it deletes every doc the account owns.
      await callCloudFunction(
        'deleteAccount',
        const {},
        timeout: const Duration(seconds: 60),
      );
    } on CloudFunctionFailure catch (e) {
      _session.cancelExpectedEnd();
      throw AuthException(e.message);
    } catch (_) {
      _session.cancelExpectedEnd();
      rethrow;
    }
    // The Auth user is gone server-side; this just clears the local session.
    await logOut();
  }
}
