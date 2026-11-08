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

  /// The most a goal can pay: the biggest [BucketGoalSize]. The
  /// completeBucketListItem Cloud Function clamps to these
  /// (BUCKET_LIST_XP_CAP / BUCKET_LIST_COIN_CAP in functions/src/bucketRewards.ts),
  /// so a bigger number would be a promise the server doesn't keep — keep the
  /// two in step.
  static const maxXpReward = 300;
  static const maxCoinReward = 100;

  /// At most this many goals pay out in any rolling week; the rest still count
  /// as achieved but pay nothing (BUCKET_PAID_GOALS_PER_WEEK on the server).
  static const paidGoalsPerWeek = 2;

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

  /// Whether [other] is the same goal as typed, ignoring [id]: used to tell a
  /// retry of a failed add from a new goal.
  bool sameGoalAs(BucketListItem other) =>
      title == other.title &&
      description == other.description &&
      icon == other.icon &&
      color == other.color &&
      xpReward == other.xpReward &&
      coinReward == other.coinReward;

  BucketListItem copyWith({
    String? title,
    String? description,
    IconData? icon,
    Color? color,
    int? xpReward,
    int? coinReward,
    bool? isCompleted,
    DateTime? completedAt,
    bool? rewardPaid,
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
      rewardPaid: rewardPaid ?? this.rewardPaid,
    );
  }
}

/// The three reward sizes a goal can have (economy pass 2026-11-07): picking
/// one replaces typing XP and coin numbers, which let a goal pay anything up
/// to the cap.
enum BucketGoalSize {
  small(label: 'Small', xp: 75, coins: 25),
  medium(label: 'Medium', xp: 150, coins: 50),
  big(label: 'Big', xp: 300, coins: 100);

  const BucketGoalSize({
    required this.label,
    required this.xp,
    required this.coins,
  });

  final String label;
  final int xp;
  final int coins;

  /// The size closest to a stored coin reward, for goals saved before sizes
  /// existed (their exact numbers are replaced the next time they are saved).
  static BucketGoalSize nearest(int coinReward) {
    var best = BucketGoalSize.medium;
    for (final size in BucketGoalSize.values) {
      if ((size.coins - coinReward).abs() < (best.coins - coinReward).abs()) {
        best = size;
      }
    }
    return best;
  }
}
