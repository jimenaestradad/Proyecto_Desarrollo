import 'package:flutter/material.dart';

/// A one-time major life goal (travel a country, run a marathon, graduate)
/// — distinct from a [Habit]: no schedule/streak, completed once, and worth
/// a much larger one-off XP/coin reward. See docs/FEATURES.md §11.
class BucketListItem {
  const BucketListItem({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.xpReward,
    required this.coinReward,
    this.isCompleted = false,
    this.completedAt,
    this.rewardPaid = false,
  });

  /// The most a goal can pay. The completeBucketListItem Cloud Function
  /// clamps to these (BUCKET_LIST_XP_CAP / BUCKET_LIST_COIN_CAP in
  /// functions/src/bucketList.ts), so a bigger number would be a promise the
  /// server doesn't keep — keep the two in step.
  static const maxXpReward = 500;
  static const maxCoinReward = 250;

  final String id;
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final int xpReward;
  final int coinReward;
  final bool isCompleted;
  final DateTime? completedAt;

  /// Whether completing this item has ever paid its reward. An item pays
  /// once and keeps it when un-completed, so this can be true while
  /// [isCompleted] is false — and deleting it then still takes the reward
  /// back (deleteBucketListItem).
  final bool rewardPaid;

  BucketListItem copyWith({
    String? title,
    String? description,
    IconData? icon,
    Color? color,
    int? xpReward,
    int? coinReward,
    bool? isCompleted,
    DateTime? completedAt,
  }) {
    return BucketListItem(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      xpReward: xpReward ?? this.xpReward,
      coinReward: coinReward ?? this.coinReward,
      isCompleted: isCompleted ?? this.isCompleted,
      completedAt: completedAt ?? this.completedAt,
      rewardPaid: rewardPaid,
    );
  }
}
