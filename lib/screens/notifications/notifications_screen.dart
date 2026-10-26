import 'package:flutter/material.dart';
import 'package:nori/data/app_data.dart';
import 'package:nori/models/app_notification.dart';
import 'package:nori/theme/app_theme.dart';
import 'package:nori/utils/date_labels.dart';
import 'package:nori/utils/remote_errors.dart';
import 'package:nori/widgets/load_error_view.dart';
import 'package:nori/widgets/nori_card.dart';
import 'package:nori/widgets/nori_empty_state.dart';
import 'package:nori/widgets/nori_icon_badge.dart';
import 'package:nori/widgets/nori_scroll_scaffold.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen>
    with RemoteLoadState<NotificationsScreen> {
  List<AppNotification>? _notifications;
  bool _isMarkingRead = false;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    await guardedLoad(hasData: _notifications != null, () async {
      final notifications = await AppData.notifications.getNotifications();
      if (!mounted) return;
      setState(() => _notifications = notifications);
    });
  }

  Future<void> _markAllRead() async {
    if (_isMarkingRead) return;
    setState(() => _isMarkingRead = true);
    await guardedAction(() async {
      await AppData.notifications.markAllRead();
      final notifications = await AppData.notifications.getNotifications();
      if (!mounted) return;
      setState(() => _notifications = notifications);
    });
    if (mounted) setState(() => _isMarkingRead = false);
  }

  @override
  Widget build(BuildContext context) {
    final notifications = _notifications;
    final error = loadError;

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
            if (notifications == null && error != null)
              LoadErrorView(error: error, onRetry: _loadNotifications)
            else if (notifications == null)
              const Padding(
                padding: EdgeInsets.all(AppSpacing.stackLg),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (notifications.isEmpty)
              const NoriEmptyState(
                icon: Icons.notifications_none,
                title: 'All caught up',
                message:
                    'Level-ups, streaks, achievements and pet alerts show up here.',
                tint: AppColors.mustardLight,
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
                    Text(
                      _timeAgo(notification.createdAt),
                      style: AppTextStyles.labelSm,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(notification.message, style: AppTextStyles.bodyMd),
                if (notification.ctaLabel case final ctaLabel?) ...[
                  const SizedBox(height: AppSpacing.stackSm),
                  FilledButton(
                    // Pops with the action; whoever pushed this screen
                    // routes it (e.g. HabitsListScreen switches to Home).
                    onPressed: () =>
                        Navigator.pop(context, notification.action),
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

String _timeAgo(DateTime createdAt) {
  final elapsed = DateTime.now().difference(createdAt);
  if (elapsed.inMinutes < 1) return 'Just now';
  if (elapsed.inHours < 1) return '${elapsed.inMinutes}m ago';
  if (elapsed.inDays < 1) return '${elapsed.inHours}h ago';
  if (elapsed.inDays == 1) return 'Yesterday';
  if (elapsed.inDays < 7) return '${elapsed.inDays}d ago';
  return '${monthAbbr(createdAt.month)} ${createdAt.day}';
}
