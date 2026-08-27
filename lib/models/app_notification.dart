import 'package:flutter/material.dart';

enum NotificationType { petAction, milestone, achievement, system }

class AppNotification {
  const AppNotification({
    required this.id,
    required this.type,
    required this.label,
    required this.message,
    required this.timeAgo,
    required this.icon,
    required this.color,
    this.isRead = false,
    this.ctaLabel,
  });

  final String id;
  final NotificationType type;
  final String label;
  final String message;
  final String timeAgo;
  final IconData icon;
  final Color color;
  final bool isRead;
  final String? ctaLabel;

  AppNotification copyWith({bool? isRead}) {
    return AppNotification(
      id: id,
      type: type,
      label: label,
      message: message,
      timeAgo: timeAgo,
      icon: icon,
      color: color,
      isRead: isRead ?? this.isRead,
      ctaLabel: ctaLabel,
    );
  }
}
