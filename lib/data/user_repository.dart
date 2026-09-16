import '../models/nori_user.dart';
import 'calendar_repository.dart';
import 'vacation_log.dart';

const kDemoUser = NoriUser(
  id: 'mock-user',
  name: 'Hannah Walker',
  username: 'hannah_habits',
  email: 'hannah@example.com',
  // Level 5, not 1 or 18+: the breathing sprite (see nori_breathing_sprite.dart)
  // reads visually as a toddler, not a newborn baby or an already-evolved
  // pet — level 5 is the mock's best current guess at where that art
  // actually belongs on the level curve. See docs/OPEN_DECISIONS.md "Pet
  // mechanics" — evolution level thresholds are still otherwise undecided.
  level: 5,
  totalXp: 7220,
  xpIntoLevel: 620,
  xpForNextLevel: 1650,
  // Overwritten on the first getCurrentUser() call with the real,
  // computed-from-history streak (see MockUserRepository) — this initial
  // value is never actually shown.
  currentStreak: 0,
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

  Future<void> updateProfile({String? name, String? username, String? email});
}

class MockUserRepository implements UserRepository {
  MockUserRepository(this._calendar, this._vacationLog);

  final CalendarRepository _calendar;
  final VacationLog _vacationLog;

  NoriUser _user = kDemoUser;

  @override
  Future<NoriUser> getCurrentUser() async {
    // Live-computed from habit history (see MockCalendarRepository), rather
    // than a stored field — a stored copy previously went stale and
    // disagreed with the real streak shown on Profile's Habit Statistics
    // card and Calendar's own stats panel.
    final streak = (await _calendar.getCurrentMonth()).currentStreak;
    if (streak != _user.currentStreak) {
      _user = _user.copyWith(currentStreak: streak);
    }
    return _user;
  }

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
    final now = DateTime.now();
    if (enabled) {
      _vacationLog.startFreeze(now);
    } else {
      _vacationLog.endFreeze(now);
    }
    _user = _user.copyWith(vacationModeEnabled: enabled);
  }

  @override
  Future<void> updateProfile({
    String? name,
    String? username,
    String? email,
  }) async {
    _user = _user.copyWith(name: name, username: username, email: email);
  }
}
