import '../models/nori_user.dart';

const kDemoUser = NoriUser(
  id: 'mock-user',
  name: 'Alex Walker',
  username: 'alex_habits',
  email: 'alex@example.com',
  level: 18,
  totalXp: 15400,
  xpIntoLevel: 1250,
  xpForNextLevel: 1650,
  currentStreak: 12,
);

abstract class UserRepository {
  Future<NoriUser> getCurrentUser();
  Future<void> addXp(int amount);
}

class MockUserRepository implements UserRepository {
  NoriUser _user = kDemoUser;

  @override
  Future<NoriUser> getCurrentUser() async => _user;

  @override
  Future<void> addXp(int amount) async {
    _user = _user.copyWith(
      totalXp: _user.totalXp + amount,
      xpIntoLevel: _user.xpIntoLevel + amount,
    );
  }
}
