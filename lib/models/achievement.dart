import 'package:flutter/material.dart';

/// [comingSoon] is for achievements whose underlying feature isn't built yet
/// (no per-day pet-care history, no social backend, no multi-pet support) —
/// distinct from [locked], which means the feature exists and is tracked,
/// just not yet met.
enum AchievementStatus { unlocked, inProgress, locked, comingSoon }

class Achievement {
  const Achievement({
    required this.id,
    required this.category,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.progressCurrent,
    required this.progressTarget,
    required this.status,
    this.imageAsset,
  });

  final String id;
  final String category;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final int progressCurrent;
  final int progressTarget;
  final AchievementStatus status;

  /// Custom crest art (see `assets/source/README.md`'s achievements/ section)
  /// for the handful of achievements that have it — falls back to [icon] in
  /// a flat badge when null, since only some of the 18 have art so far.
  final String? imageAsset;

  double get progress =>
      progressTarget == 0 ? 0 : progressCurrent / progressTarget;
}
