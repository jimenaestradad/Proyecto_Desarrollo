import 'package:flutter/material.dart';
import '../models/achievement.dart';
import '../theme/app_colors.dart';

abstract class AchievementRepository {
  /// Achievements grouped by category, in display order.
  Future<Map<String, List<Achievement>>> getAchievementsByCategory();
}

class MockAchievementRepository implements AchievementRepository {
  @override
  Future<Map<String, List<Achievement>>> getAchievementsByCategory() async {
    return {
      'Consistency': const [
        Achievement(
          id: 'week-warrior',
          category: 'Consistency',
          title: 'Week Warrior',
          subtitle: '7 Day Streak',
          icon: Icons.local_fire_department,
          color: AppColors.primary,
          progressCurrent: 7,
          progressTarget: 7,
          status: AchievementStatus.unlocked,
        ),
        Achievement(
          id: 'monthly-master',
          category: 'Consistency',
          title: 'Monthly Master',
          subtitle: '30 Day Streak',
          icon: Icons.shield,
          color: AppColors.secondary,
          progressCurrent: 30,
          progressTarget: 30,
          status: AchievementStatus.unlocked,
        ),
        Achievement(
          id: 'century-club',
          category: 'Consistency',
          title: 'Century Club',
          subtitle: '100 Day Streak',
          icon: Icons.workspace_premium,
          color: AppColors.tertiary,
          progressCurrent: 42,
          progressTarget: 100,
          status: AchievementStatus.inProgress,
        ),
        Achievement(
          id: 'year-long-legend',
          category: 'Consistency',
          title: 'Year Long Legend',
          subtitle: '365 Day Streak',
          icon: Icons.emoji_events,
          color: AppColors.outline,
          progressCurrent: 0,
          progressTarget: 365,
          status: AchievementStatus.locked,
        ),
      ],
      'Health': const [
        Achievement(
          id: 'hydro-homie',
          category: 'Health',
          title: 'Hydro Homie',
          subtitle: 'Drink 8 glasses of water',
          icon: Icons.water_drop,
          color: AppColors.secondary,
          progressCurrent: 10,
          progressTarget: 10,
          status: AchievementStatus.unlocked,
        ),
        Achievement(
          id: 'gym-hero',
          category: 'Health',
          title: 'Gym Hero',
          subtitle: 'Workout 10 times',
          icon: Icons.fitness_center,
          color: AppColors.primary,
          progressCurrent: 8,
          progressTarget: 10,
          status: AchievementStatus.inProgress,
        ),
        Achievement(
          id: 'zen-master',
          category: 'Health',
          title: 'Zen Master',
          subtitle: 'Meditate for 30 days',
          icon: Icons.self_improvement,
          color: AppColors.outline,
          progressCurrent: 5,
          progressTarget: 30,
          status: AchievementStatus.locked,
        ),
      ],
    };
  }
}
