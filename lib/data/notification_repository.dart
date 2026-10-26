import 'package:flutter/material.dart';
import '../models/app_notification.dart';
import '../theme/app_colors.dart';

abstract class NotificationRepository {
  /// Newest first. The Firestore implementation also creates any
  /// notifications owed since the last call before reading (see
  /// FirestoreNotificationRepository).
  Future<List<AppNotification>> getNotifications();

  /// Live: whether any notification is unread. Backs the dot on the bell.
  Stream<bool> watchHasUnread();

  Future<void> markAllRead();
}

/// Demo data for when no account is bound (AppData.unbindUser).
class MockNotificationRepository implements NotificationRepository {
  final List<AppNotification> _notifications = _seed(DateTime.now());

  static List<AppNotification> _seed(DateTime now) => [
    AppNotification(
      id: 'pet-needs-you',
      type: NotificationType.petAction,
      label: 'Pet Needs You',
      message: 'Nori is hungry! Feed Nori from the home screen.',
      createdAt: now,
      icon: Icons.pets,
      color: AppColors.mustardDark,
      ctaLabel: 'Care for Nori',
      action: NotificationAction.carePet,
    ),
    AppNotification(
      id: 'streak-milestone',
      type: NotificationType.milestone,
      label: 'Milestone',
      message: 'You hit a 7-day streak! Keep going!',
      createdAt: now.subtract(const Duration(hours: 2)),
      icon: Icons.local_fire_department,
      color: AppColors.terracotta,
      isRead: true,
    ),
    AppNotification(
      id: 'badge-unlocked',
      type: NotificationType.achievement,
      label: 'Achievement',
      message: 'You unlocked the "Week Warrior" achievement!',
      createdAt: now.subtract(const Duration(days: 1)),
      icon: Icons.emoji_events,
      color: AppColors.moss,
      isRead: true,
    ),
    AppNotification(
      id: 'level-up',
      type: NotificationType.system,
      label: 'Level Up',
      message: 'Nori grew! You reached Level 18.',
      createdAt: now.subtract(const Duration(days: 2)),
      icon: Icons.auto_awesome,
      color: AppColors.inkMuted,
      isRead: true,
    ),
  ];

  @override
  Future<List<AppNotification>> getNotifications() async =>
      List.unmodifiable(_notifications);

  @override
  Stream<bool> watchHasUnread() =>
      Stream.value(_notifications.any((n) => !n.isRead));

  @override
  Future<void> markAllRead() async {
    for (var i = 0; i < _notifications.length; i++) {
      _notifications[i] = _notifications[i].copyWith(isRead: true);
    }
  }
}
