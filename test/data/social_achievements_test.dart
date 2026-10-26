import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nori/data/achievement_repository.dart';
import 'package:nori/data/bucket_list_repository.dart';
import 'package:nori/data/calendar_repository.dart';
import 'package:nori/data/habit_repository.dart';
import 'package:nori/data/inventory_repository.dart';
import 'package:nori/data/mock_social_repository.dart';
import 'package:nori/data/pet_repository.dart';
import 'package:nori/data/vacation_log.dart';
import 'package:nori/models/achievement.dart';
import 'package:nori/models/social_content.dart';
import 'package:nori/theme/app_colors.dart';

void main() {
  Future<(MockSocialRepository, Map<String, Achievement>)> load(
    MockSocialRepository social,
  ) async {
    final habits = MockHabitRepository();
    final inventory = MockInventoryRepository();
    final repo = MockAchievementRepository(
      habits,
      MockCalendarRepository(habits, MockVacationLog()),
      MockBucketListRepository(),
      MockPetRepository(inventory),
      inventory,
      social,
    );
    final byCategory = await repo.getAchievementsByCategory();
    return (social, {for (final a in byCategory['Social']!) a.id: a});
  }

  test('Social achievements are live, not coming-soon placeholders', () async {
    final (_, social) = await load(MockSocialRepository());
    expect(
      social.keys,
      containsAll([
        'better-together',
        'helping-hand',
        'proof-pal',
        'circle-starter',
        'accountability-duo',
      ]),
    );
    expect(
      social.values.where((a) => a.status == AchievementStatus.comingSoon),
      isEmpty,
    );
  });

  test('progress follows what you do in the Social tab', () async {
    final repo = MockSocialRepository();
    final (_, before) = await load(repo);
    expect(before['circle-starter']!.status, AchievementStatus.locked);
    final reactionsBefore = before['helping-hand']!.progressCurrent;

    await repo.createCircle(
      name: 'Study crew',
      icon: Icons.groups,
      color: AppColors.mossLight,
      memberIds: const ['jimena'],
    );
    // React to someone else's post (p1 is Jimena's).
    await repo.toggleReaction('p1', Reaction.fire);

    final (_, after) = await load(repo);
    expect(after['circle-starter']!.status, AchievementStatus.unlocked);
    expect(after['helping-hand']!.progressCurrent, reactionsBefore + 1);
  });
}
