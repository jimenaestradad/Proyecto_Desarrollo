import 'package:flutter/material.dart';
import 'package:nori/data/app_data.dart';
import 'package:nori/models/app_notification.dart';
import 'package:nori/theme/app_theme.dart';
import 'package:nori/widgets/nori_card.dart';
import 'package:nori/widgets/nori_icon_badge.dart';
import 'package:nori/widgets/nori_scroll_scaffold.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<AppNotification>? _notifications;
  bool _isMarkingRead = false;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    final notifications = await AppData.notifications.getNotifications();
    if (!mounted) return;
    setState(() => _notifications = notifications);
  }

  Future<void> _markAllRead() async {
    if (_isMarkingRead) return;
    setState(() => _isMarkingRead = true);
    try {
      await AppData.notifications.markAllRead();
      final notifications = await AppData.notifications.getNotifications();
      if (!mounted) return;
      setState(() => _notifications = notifications);
    } finally {
      if (mounted) setState(() => _isMarkingRead = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final notifications = _notifications;

    return Scaffold(
      body: SafeArea(
        child: NoriScrollScaffold(
          maxWidth: 800,
          children: [
            _NotificationsHeader(
              isMarkingRead: _isMarkingRead,
              onBack: () => Navigator.pop(context),
              onMarkAllRead: _markAllRead,
            ),
            const SizedBox(height: AppSpacing.stackMd),
            if (notifications == null)
              const Padding(
                padding: EdgeInsets.all(AppSpacing.stackLg),
                child: Center(child: CircularProgressIndicator()),
              )
            else
              for (var index = 0; index < notifications.length; index++) ...[
                _NotificationCard(notification: notifications[index]),
                if (index != notifications.length - 1)
                  const SizedBox(height: AppSpacing.unit),
              ],
          ],
        ),
      ),
    );
  }
}

class _NotificationsHeader extends StatelessWidget {
  const _NotificationsHeader({
    required this.isMarkingRead,
    required this.onBack,
    required this.onMarkAllRead,
  });

  final bool isMarkingRead;
  final VoidCallback onBack;
  final VoidCallback onMarkAllRead;

  @override
  Widget build(BuildContext context) {
    final title = Text('Notifications', style: AppTextStyles.headlineLgMobile);
    final markAllButton = TextButton(
      onPressed: isMarkingRead ? null : onMarkAllRead,
      child: Text(isMarkingRead ? 'Marking...' : 'Mark all as read'),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final backButton = IconButton(
          onPressed: onBack,
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back),
        );

        if (constraints.maxWidth < 360) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  backButton,
                  const SizedBox(width: AppSpacing.unit),
                  Expanded(child: title),
                ],
              ),
              Align(alignment: Alignment.centerRight, child: markAllButton),
            ],
          );
        }

        return Row(
          children: [
            backButton,
            const SizedBox(width: AppSpacing.unit),
            Expanded(child: title),
            markAllButton,
          ],
        );
      },
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({required this.notification});

  final AppNotification notification;

  @override
  Widget build(BuildContext context) {
    final isUnread = !notification.isRead;

    return NoriCard(
      padding: const EdgeInsets.all(AppSpacing.gutter),
      radius: AppRadius.md,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          NoriIconBadge(
            icon: notification.icon,
            background: notification.color,
            size: 48,
            circle: true,
            iconSize: 24,
          ),
          const SizedBox(width: AppSpacing.stackSm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        notification.label.toUpperCase(),
                        style: AppTextStyles.labelSm.copyWith(
                          color: notification.color,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.unit),
                    Text(notification.timeAgo, style: AppTextStyles.labelSm),
                  ],
                ),
                const SizedBox(height: 4),
                Text(notification.message, style: AppTextStyles.bodyMd),
                if (notification.ctaLabel case final ctaLabel?) ...[
                  const SizedBox(height: AppSpacing.stackSm),
                  FilledButton(
                    onPressed: () => Navigator.pop(context),
                    style: FilledButton.styleFrom(
                      backgroundColor: notification.color,
                      foregroundColor: AppColors.ink,
                      side: const BorderSide(
                        color: AppColors.ink,
                        width: AppBorder.thin,
                      ),
                      minimumSize: const Size(0, 48),
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.gutter,
                        vertical: AppSpacing.unit,
                      ),
                      textStyle: AppTextStyles.labelLg,
                    ),
                    child: Text(ctaLabel),
                  ),
                ],
              ],
            ),
          ),
          if (isUnread) ...[
            const SizedBox(width: AppSpacing.unit),
            Semantics(
              label: 'Unread',
              child: Container(
                width: 10,
                height: 10,
                margin: const EdgeInsets.only(top: 4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: notification.color,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
