import '../models/nori_user.dart';
import 'user_repository.dart';

/// Auth is not implemented yet (see docs/OPEN_DECISIONS.md #6). This
/// interface is the seam a real provider (Firebase Auth, custom API, …)
/// plugs into later — swap [MockAuthRepository] for a real implementation
/// in `app_data.dart` and no screen code needs to change.
abstract class AuthRepository {
  Future<NoriUser> signUp({
    required String name,
    required String username,
    required String email,
    required String password,
  });

  Future<NoriUser> logIn({required String email, required String password});
}

class MockAuthRepository implements AuthRepository {
  @override
  Future<NoriUser> signUp({
    required String name,
    required String username,
    required String email,
    required String password,
  }) async {
    await Future.delayed(const Duration(milliseconds: 300));
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
    return kDemoUser;
  }
}
