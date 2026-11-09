import '../models/nori_user.dart';
import 'calendar_repository.dart';
import 'vacation_log.dart';

const kDemoUser = NoriUser(
  id: 'mock-user',
  name: 'Hannah Walker',
  username: 'hannah_habits',
  email: 'hannah@example.com',
  // Level 5 is the evolution level (kEvolutionLevel).
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

  /// The newest user [getCurrentUser] has returned, or null before the first
  /// read. Tabs show it the moment they become active, so the XP and coin
  /// pills don't flash the value from their own last visit while their own
  /// reload is still in flight.
  NoriUser? get lastKnownUser;

  Future<void> setVacationMode(bool enabled);

  Future<void> updateProfile({String? name, String? username, String? email});

  /// Whether the account's profile has a name and a username, which sign-up
  /// writes last. False for one interrupted after the username was claimed but
  /// before the profile was saved (see `isSignUpComplete`).
  Future<bool> hasProfile();
}

class MockUserRepository implements UserRepository {
  MockUserRepository(this._calendar, this._vacationLog);

  final CalendarRepository _calendar;
  final VacationLog _vacationLog;

  NoriUser _user = kDemoUser;

  // The mock only runs signed out, where no tab shows a user.
  @override
  NoriUser? get lastKnownUser => null;

  @override
  Future<NoriUser> getCurrentUser() async {
    // Live-computed from habit history (see MockCalendarRepository), rather
    // than a stored field — a stored copy previously went stale and
    // disagreed with the real streak shown on Profile's Habit Statistics
    // card and Calendar's own stats panel.
    final streak = await _calendar.getCurrentStreak();
    if (streak != _user.currentStreak) {
      _user = _user.copyWith(currentStreak: streak);
    }
    return _user;
  }

  @override
  Future<void> setVacationMode(bool enabled) async {
    final now = DateTime.now();
    if (enabled) {
      await _vacationLog.startFreeze(now);
    } else {
      await _vacationLog.endFreeze(now);
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

  @override
  Future<bool> hasProfile() async => true;
}
