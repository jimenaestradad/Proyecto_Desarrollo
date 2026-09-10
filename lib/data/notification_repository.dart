import 'package:flutter/material.dart';
import '../models/app_notification.dart';
import '../theme/app_colors.dart';

abstract class NotificationRepository {
  Future<List<AppNotification>> getNotifications();
  Future<void> markAllRead();
}

class MockNotificationRepository implements NotificationRepository {
  final List<AppNotification> _notifications = [
    const AppNotification(
      id: 'pet-needs-you',
      type: NotificationType.petAction,
      label: 'Pet Needs You',
      message: 'Nori is hungry! Complete your "Drink Water" habit to feed him.',
      timeAgo: 'Just now',
      icon: Icons.pets,
      color: AppColors.mustardDark,
      ctaLabel: 'Do it now',
    ),
    const AppNotification(
      id: 'streak-milestone',
      type: NotificationType.milestone,
      label: 'Milestone',
      message: 'You hit a 5-day streak! Keep going!',
      timeAgo: '2h ago',
      icon: Icons.local_fire_department,
      color: AppColors.terracotta,
      isRead: true,
    ),
    const AppNotification(
      id: 'badge-unlocked',
      type: NotificationType.achievement,
      label: 'Achievement',
      message: 'You unlocked the "Week Warrior" badge for a 7-day streak!',
      timeAgo: 'Yesterday',
      icon: Icons.emoji_events,
      color: AppColors.moss,
      isRead: true,
    ),
    const AppNotification(
      id: 'level-up',
      type: NotificationType.system,
      label: 'Level Up',
      message: 'Nori grew! You reached Level 18.',
      timeAgo: '2d ago',
      icon: Icons.auto_awesome,
      color: AppColors.inkMuted,
      isRead: true,
    ),
  ];

  @override
  Future<List<AppNotification>> getNotifications() async =>
      List.unmodifiable(_notifications);

  @override
  Future<void> markAllRead() async {
    for (var i = 0; i < _notifications.length; i++) {
      _notifications[i] = _notifications[i].copyWith(isRead: true);
    }
  }
}
