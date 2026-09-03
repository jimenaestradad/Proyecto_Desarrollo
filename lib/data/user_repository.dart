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
  coins: 340,
);

abstract class UserRepository {
  Future<NoriUser> getCurrentUser();

  /// Adds (or, for un-claiming a habit, subtracts) XP, leveling up whenever
  /// `xpIntoLevel` crosses `xpForNextLevel`. Uses a flat per-level curve —
  /// docs/OPEN_DECISIONS.md defers "the full XP-per-level curve", so this
  /// doesn't invent one.
  Future<void> addXp(int amount);

  /// May be negative (spending in the Shop or on Play).
  Future<void> addCoins(int amount);

  Future<void> setVacationMode(bool enabled);
}

class MockUserRepository implements UserRepository {
  NoriUser _user = kDemoUser;

  @override
  Future<NoriUser> getCurrentUser() async => _user;

  @override
  Future<void> addXp(int amount) async {
    var xpIntoLevel = _user.xpIntoLevel + amount;
    var level = _user.level;

    while (xpIntoLevel >= _user.xpForNextLevel) {
      xpIntoLevel -= _user.xpForNextLevel;
      level += 1;
    }
    while (xpIntoLevel < 0 && level > 1) {
      level -= 1;
      xpIntoLevel += _user.xpForNextLevel;
    }
    if (xpIntoLevel < 0) xpIntoLevel = 0;

    _user = _user.copyWith(
      totalXp: (_user.totalXp + amount).clamp(0, 1 << 30),
      xpIntoLevel: xpIntoLevel,
      level: level,
    );
  }

  @override
  Future<void> addCoins(int amount) async {
    _user = _user.copyWith(coins: (_user.coins + amount).clamp(0, 1 << 30));
  }

  @override
  Future<void> setVacationMode(bool enabled) async {
    _user = _user.copyWith(vacationModeEnabled: enabled);
  }
}
