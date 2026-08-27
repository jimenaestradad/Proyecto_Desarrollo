import 'package:flutter/material.dart';

enum AchievementStatus { unlocked, inProgress, locked }

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

  double get progress =>
      progressTarget == 0 ? 0 : progressCurrent / progressTarget;
}
