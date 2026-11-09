import 'package:flutter/material.dart';

enum NotificationType { petAction, milestone, achievement, system }

/// Where a notification's call-to-action button takes the user.
/// NotificationsScreen pops with it, and whoever pushed the screen routes it.
enum NotificationAction { carePet }

class AppNotification {
  const AppNotification({
    required this.id,
    required this.type,
    required this.label,
    required this.message,
    required this.createdAt,
    required this.icon,
    required this.color,
    this.isRead = false,
    this.ctaLabel,
    this.action,
  });

  final String id;
  final NotificationType type;
  final String label;
  final String message;
  final DateTime createdAt;
  final IconData icon;
  final Color color;
  final bool isRead;
  final String? ctaLabel;
  final NotificationAction? action;

  AppNotification copyWith({bool? isRead}) {
    return AppNotification(
      id: id,
      type: type,
      label: label,
      message: message,
      createdAt: createdAt,
      icon: icon,
      color: color,
      isRead: isRead ?? this.isRead,
      ctaLabel: ctaLabel,
      action: action,
    );
  }
}
