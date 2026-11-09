import '../models/pet.dart';
import '../models/social_content.dart';
import '../models/social_people.dart';
import 'habit_repository.dart';
import 'pet_repository.dart';
import 'user_repository.dart';

/// Where the Social tab gets *your own* data from. Friends, posts,
/// competitions and the rest are mock (docs/technical/BACKEND.md lists social as a
/// non-goal), but "you" is the signed-in account, read from the repositories
/// that already exist — reads only, nothing here writes or adds backend.
abstract class SocialAccountSource {
  /// The signed-in user's social profile. Fields that can't be read fall back
  /// to [fallback]'s; throws only if the user itself can't be read.
  Future<SocialUser> loadMe(SocialUser fallback);

  /// Habits you've completed today, as proof candidates. Null when they can't
  /// be read (the caller then keeps its own list).
  Future<List<ProofableHabit>?> loadCompletedHabitsToday();
}

/// Reads through `AppData`'s repositories. Takes getters, not instances,
/// because `AppData.bindToUser` swaps those instances on every sign-in.
class LiveSocialAccount implements SocialAccountSource {
  LiveSocialAccount({
    required UserRepository Function() user,
    required PetRepository Function() pet,
    required HabitRepository Function() habits,
  }) : _user = user,
       _pet = pet,
       _habits = habits;

  final UserRepository Function() _user;
  final PetRepository Function() _pet;
  final HabitRepository Function() _habits;

  @override
  Future<SocialUser> loadMe(SocialUser fallback) async {
    final user = await _user().getCurrentUser();

    var petName = fallback.petName;
    var petStage = fallback.petStage;
    try {
      final pet = await _pet().getPet();
      petName = pet.name;
      petStage = pet.stage == PetEvolutionStage.baby ? 0 : 1;
    } catch (_) {
      // Keep the fallback pet — a missing pet doc shouldn't blank the tab.
    }

    var weeklyXp = fallback.weeklyXp;
    try {
      weeklyXp = await _xpLastSevenDays();
    } catch (_) {
      // Same: keep the fallback figure.
    }

    return SocialUser(
      id: 'me',
      name: user.name,
      username: user.username,
      level: user.level,
      weeklyXp: weeklyXp,
      totalXp: user.totalXp,
      currentStreak: user.currentStreak,
      // Not derivable cheaply from the existing data; stays the seed value.
      proofCount: fallback.proofCount,
      petName: petName,
      petStage: petStage,
    );
  }

  /// XP actually awarded over today and the previous six days.
  Future<int> _xpLastSevenDays() async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day - 6);
    final days = await _habits().getHabitsForRange(start, now);
    var xp = 0;
    for (final habits in days.values) {
      for (final habit in habits) {
        // Undone days hold no XP, so only what is currently paid counts.
        xp += habit.lastAwardedXp;
      }
    }
    return xp;
  }

  @override
  Future<List<ProofableHabit>?> loadCompletedHabitsToday() async {
    try {
      final habits = await _habits().getTodayHabits();
      return [
        for (final habit in habits)
          if (habit.isCompletedToday)
            ProofableHabit(
              id: habit.id,
              name: habit.name,
              icon: habit.icon,
              color: habit.color,
            ),
      ];
    } catch (_) {
      return null;
    }
  }
}
