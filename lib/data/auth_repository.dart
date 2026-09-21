import '../models/nori_user.dart';
import 'user_repository.dart';

/// The contract every auth provider plugs into — [MockAuthRepository] for
/// local dev/demo, [FirebaseAuthRepository] (firebase_auth_repository.dart)
/// for the real thing. `app_data.dart` picks which one screens get; no
/// screen imports either implementation directly.
abstract class AuthRepository {
  Future<NoriUser> signUp({
    required String name,
    required String username,
    required String email,
    required String password,
  });

  Future<NoriUser> logIn({required String email, required String password});

  /// Signs the current user out. Screens should call this (not just
  /// navigate to `/welcome`) so a real backend actually ends the session —
  /// otherwise relaunching the app would just log the user back in.
  Future<void> logOut();

  /// Sends a password-reset email. Throws [AuthException] with a
  /// user-facing message on failure.
  Future<void> sendPasswordResetEmail(String email);

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
}
