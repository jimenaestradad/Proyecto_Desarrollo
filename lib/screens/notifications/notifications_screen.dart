import 'package:flutter/material.dart';
import 'package:nori/data/app_data.dart';
import 'package:nori/models/app_notification.dart';
import 'package:nori/models/social_content.dart';
import 'package:nori/screens/social/competition_invite_screen.dart';
import 'package:nori/screens/social/friend_streak_detail_screen.dart';
import 'package:nori/screens/social/leaderboard_screen.dart';
import 'package:nori/screens/social/post_detail_screen.dart';
import 'package:nori/screens/social/social_load_state.dart';
import 'package:nori/screens/social/widgets/social_notification_card.dart';
import 'package:nori/theme/app_theme.dart';
import 'package:nori/utils/relative_time.dart';
import 'package:nori/utils/remote_errors.dart';
import 'package:nori/widgets/load_error_view.dart';
import 'package:nori/widgets/nori_card.dart';
import 'package:nori/widgets/nori_empty_state.dart';
import 'package:nori/widgets/nori_icon_badge.dart';
import 'package:nori/widgets/nori_scroll_scaffold.dart';
import 'package:nori/widgets/nori_segmented_control.dart';

/// Which slice of the inbox is showing.
enum NotificationFilter {
  all('All'),
  pet('Pet'),
  social('Social');

  const NotificationFilter(this.label);
  final String label;
}

/// The one inbox: pet and app events (level-ups, evolution, achievements,
/// "pet needs you") and social activity (friend requests, nudges, invites)
/// in a single list, with All / Pet / Social filters.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({
    super.key,
    this.initialFilter = NotificationFilter.all,
  });

  final NotificationFilter initialFilter;

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen>
    with RemoteLoadState<NotificationsScreen> {
  List<AppNotification>? _notifications;
  List<SocialNotification> _social = const [];
  late NotificationFilter _filter = widget.initialFilter;
  bool _isMarkingRead = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    await guardedLoad(hasData: _notifications != null, () async {
      final social = await AppData.social.getNotifications();
      if (!mounted) return;
      setState(() => _social = social);
      // Paint what's stored right away; the full call below also works out
      // new streak/achievement notifications, which reads months of history
      // and takes a few seconds.
      if (_notifications == null) {
        final stored = await AppData.notifications.getNotifications(
          sync: false,
        );
        if (!mounted) return;
        setState(() => _notifications = stored);
      }
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
      await AppData.social.markAllNotificationsRead();
      if (!mounted) return;
      // Updated locally rather than re-fetched: getNotifications re-runs the
      // whole achievement/streak sync, which reads months of history.
      setState(() {
        _notifications = [
          for (final n in _notifications ?? const <AppNotification>[])
            n.copyWith(isRead: true),
        ];
        _social = [for (final n in _social) n.copyWith(isRead: true)];
      });
    });
    if (mounted) setState(() => _isMarkingRead = false);
  }

  /// Answers a friend request or competition invite, then refreshes the
  /// social half of the list.
  Future<void> _answer(Future<void> Function() action, String message) async {
    if (_busy) return;
    setState(() => _busy = true);
    final ok = await guardedAction(() async {
      await action();
      final social = await AppData.social.getNotifications();
      if (mounted) setState(() => _social = social);
    });
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) showSocialToast(context, message);
  }

  void _openSocial(SocialNotification notification) {
    final id = notification.refId;
    final Widget? screen = switch (notification.kind) {
      SocialNotificationKind.reaction || SocialNotificationKind.comment =>
        id == null ? null : PostDetailScreen(postId: id),
      SocialNotificationKind.rank => const LeaderboardScreen(),
      SocialNotificationKind.streakAtRisk || SocialNotificationKind.highFive =>
        id == null ? null : FriendStreakDetailScreen(friendId: id),
      SocialNotificationKind.competitionInvite =>
        id == null ? null : CompetitionInviteScreen(competitionId: id),
      SocialNotificationKind.friendRequest ||
      SocialNotificationKind.nudge => null,
    };
    if (screen != null) {
      Navigator.push(context, MaterialPageRoute<void>(builder: (_) => screen));
    }
  }

  Widget _socialCard(SocialNotification n) {
    final id = n.refId;
    final friendRequest = n.kind == SocialNotificationKind.friendRequest;
    return SocialNotificationCard(
      notification: n,
      busy: _busy,
      onOpen: () => _openSocial(n),
      onAccept: id == null
          ? () {}
          : () => _answer(
              () => friendRequest
                  ? AppData.social.acceptFriendRequest(id)
                  : AppData.social.acceptCompetitionInvite(id),
              friendRequest ? 'Friend request accepted' : 'Competition joined',
            ),
      onDecline: id == null
          ? () {}
          : () => _answer(
              () => friendRequest
                  ? AppData.social.declineFriendRequest(id)
                  : AppData.social.declineCompetitionInvite(id),
              friendRequest ? 'Friend request ignored' : 'Invitation declined',
            ),
    );
  }

  /// The cards for the current filter, newest first.
  List<Widget> _cards(List<AppNotification> pet) {
    final entries = <(DateTime, Widget)>[
      if (_filter != NotificationFilter.social)
        for (final n in pet) (n.createdAt, _NotificationCard(notification: n)),
      if (_filter != NotificationFilter.pet)
        for (final n in _social) (n.createdAt, _socialCard(n)),
    ]..sort((a, b) => b.$1.compareTo(a.$1));
    return [
      for (var i = 0; i < entries.length; i++) ...[
        entries[i].$2,
        if (i != entries.length - 1) const SizedBox(height: AppSpacing.stackSm),
      ],
    ];
  }

  @override
  Widget build(BuildContext context) {
    final notifications = _notifications;
    final error = loadError;
    final petUnread = notifications?.where((n) => !n.isRead).length ?? 0;
    final socialUnread = _social.where((n) => !n.isRead).length;

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
            const SizedBox(height: AppSpacing.stackSm),
            NoriSegmentedControl(
              labels: [for (final f in NotificationFilter.values) f.label],
              selectedIndex: _filter.index,
              onChanged: (i) =>
                  setState(() => _filter = NotificationFilter.values[i]),
              badges: {
                if (petUnread > 0) NotificationFilter.pet.index: petUnread,
                if (socialUnread > 0)
                  NotificationFilter.social.index: socialUnread,
              },
            ),
            const SizedBox(height: AppSpacing.stackMd),
            if (notifications == null && error != null)
              LoadErrorView(error: error, onRetry: _loadNotifications)
            else if (notifications == null)
              const Padding(
                padding: EdgeInsets.all(AppSpacing.stackLg),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_cards(notifications).isEmpty)
              NoriEmptyState(
                icon: Icons.notifications_none,
                title: 'All caught up',
                message: switch (_filter) {
                  NotificationFilter.all =>
                    'Level-ups, streaks, achievements, pet alerts and friend '
                        'activity show up here.',
                  NotificationFilter.pet =>
                    'Level-ups, streaks, achievements and pet alerts show up '
                        'here.',
                  NotificationFilter.social =>
                    'Friend requests and encouragement will appear here.',
                },
                tint: AppColors.mustardLight,
              )
            else
              ..._cards(notifications),
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

        // Narrow, or a large system font: stack "Mark all as read" under the
        // title instead of squeezing the title into a mid-word break.
        final largeText = MediaQuery.textScalerOf(context).scale(1) > 1.15;
        if (constraints.maxWidth < 360 || largeText) {
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
                          // The type color is a fill (moss is 2.8:1 on
                          // white as text); pull it toward ink for the label.
                          color: Color.lerp(
                            notification.color,
                            AppColors.ink,
                            0.5,
                          ),
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.unit),
                    Text(
                      relativeTimeLabel(notification.createdAt),
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
                      // Lightened: ink on the raw type color was 3.3:1 for the
                      // mustardDark "Pet needs you" button.
                      backgroundColor: Color.lerp(
                        notification.color,
                        AppColors.white,
                        0.45,
                      ),
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
