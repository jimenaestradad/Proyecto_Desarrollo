import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import '../models/bucket_list_item.dart';
import '../theme/app_colors.dart';
import 'habit_repository.dart' show HabitRewardResult;

abstract class BucketListRepository {
  Future<List<BucketListItem>> getItems();

  Future<void> addItem(BucketListItem item);

  Future<void> updateItem(BucketListItem item);

  Future<void> deleteItem(String id);

  /// Marks an item done and returns the one-off XP/coin reward it pays out.
  /// No-op (returns [HabitRewardResult.none]) if already completed.
  Future<HabitRewardResult> completeItem(String id);

  /// Reverses a completion — mirrors [HabitRepository.unclaimHabit].
  Future<HabitRewardResult> uncompleteItem(String id);
}

class MockBucketListRepository implements BucketListRepository {
  final List<BucketListItem> _items = [
    const BucketListItem(
      id: 'visit-japan',
      title: 'Visit Japan',
      description: 'Cherry blossoms, Tokyo, and a bowl of real ramen.',
      icon: Icons.flight_takeoff,
      color: AppColors.blushPink,
      xpReward: 300,
      coinReward: 100,
    ),
    const BucketListItem(
      id: 'run-marathon',
      title: 'Run a Marathon',
      description: '42.2 km, one finish line.',
      icon: Icons.directions_run,
      color: AppColors.mossLight,
      xpReward: 150,
      coinReward: 50,
    ),
    const BucketListItem(
      id: 'graduate',
      title: 'Graduate University',
      description: 'Walk the stage.',
      icon: Icons.school,
      color: AppColors.sky,
      xpReward: 300,
      coinReward: 100,
    ),
    // Debug-only XP fast-forward for testing leveling and evolution.
    // Toggle completion to add or remove the reward.
    if (kDebugMode)
      const BucketListItem(
        id: 'dev-level-up',
        title: 'DEV: Level Up',
        description:
            'Testing only — grants XP/coins to exercise leveling '
            'and evolution without grinding real habits.',
        icon: Icons.bug_report,
        color: AppColors.terracotta,
        xpReward: 3000,
        coinReward: 300,
      ),
  ];

  @override
  Future<List<BucketListItem>> getItems() async => List.unmodifiable(_items);

  @override
  Future<void> addItem(BucketListItem item) async {
    _items.add(item);
  }

  @override
  Future<void> updateItem(BucketListItem item) async {
    final index = _items.indexWhere((i) => i.id == item.id);
    if (index == -1) return;
    _items[index] = item;
  }

  @override
  Future<void> deleteItem(String id) async {
    _items.removeWhere((i) => i.id == id);
  }

  @override
  Future<HabitRewardResult> completeItem(String id) async {
    final index = _items.indexWhere((i) => i.id == id);
    if (index == -1) return HabitRewardResult.none;
    final item = _items[index];
    if (item.isCompleted) return HabitRewardResult.none;
    _items[index] = item.copyWith(
      isCompleted: true,
      completedAt: DateTime.now(),
    );
    return HabitRewardResult(item.xpReward, item.coinReward);
  }

  @override
  Future<HabitRewardResult> uncompleteItem(String id) async {
    final index = _items.indexWhere((i) => i.id == id);
    if (index == -1) return HabitRewardResult.none;
    final item = _items[index];
    if (!item.isCompleted) return HabitRewardResult.none;
    // Not copyWith: its null-means-"keep old value" convention can't
    // express clearing completedAt back to null.
    _items[index] = BucketListItem(
      id: item.id,
      title: item.title,
      description: item.description,
      icon: item.icon,
      color: item.color,
      xpReward: item.xpReward,
      coinReward: item.coinReward,
    );
    return HabitRewardResult(-item.xpReward, -item.coinReward);
  }
}
