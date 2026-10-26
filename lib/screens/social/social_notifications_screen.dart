import 'package:flutter/material.dart';
import 'package:nori/data/app_data.dart';
import 'package:nori/models/social_content.dart';
import 'package:nori/screens/social/competition_invite_screen.dart';
import 'package:nori/screens/social/friend_streak_detail_screen.dart';
import 'package:nori/screens/social/leaderboard_screen.dart';
import 'package:nori/screens/social/post_detail_screen.dart';
import 'package:nori/screens/social/social_load_state.dart';
import 'package:nori/theme/app_theme.dart';
import 'package:nori/utils/relative_time.dart';
import 'package:nori/utils/remote_errors.dart';
import 'package:nori/widgets/nori_card.dart';
import 'package:nori/widgets/nori_empty_state.dart';
import 'package:nori/widgets/nori_icon_badge.dart';
import 'package:nori/widgets/nori_screen_header.dart';
import 'package:nori/widgets/nori_scroll_scaffold.dart';
import 'package:nori/widgets/tactile_button.dart';

class SocialNotificationsScreen extends StatefulWidget {
  const SocialNotificationsScreen({super.key});

  @override
  State<SocialNotificationsScreen> createState() =>
      _SocialNotificationsScreenState();
}

class _SocialNotificationsScreenState extends State<SocialNotificationsScreen>
    with
        RemoteLoadState<SocialNotificationsScreen>,
        SocialLoadState<SocialNotificationsScreen> {
  List<SocialNotification> _notifications = [];
  bool _busy = false;

  @override
  Future<void> loadSocial() async {
    final notifications = await AppData.social.getNotifications();
    if (!mounted) return;
    setState(() => _notifications = notifications);
  }

  Future<void> _act(Future<void> Function() action, String message) async {
    if (_busy) return;
    setState(() => _busy = true);
    final success = await guardedAction(action);
    if (!mounted) return;
    setState(() => _busy = false);
    if (success) showSocialToast(context, message);
  }

  void _open(SocialNotification notification) {
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

  Widget _notificationCard(SocialNotification notification) {
    final id = notification.refId;
    final friendRequest =
        notification.kind == SocialNotificationKind.friendRequest;
    final competitionInvite =
        notification.kind == SocialNotificationKind.competitionInvite;
    final actionable = (friendRequest || competitionInvite) && id != null;
    return NoriCard(
      color: notification.isRead
          ? AppColors.white
          : Color.alphaBlend(
              notification.color.withValues(alpha: 0.28),
              AppColors.white,
            ),
      padding: const EdgeInsets.all(AppSpacing.gutter),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            button:
                notification.kind != SocialNotificationKind.nudge &&
                notification.kind != SocialNotificationKind.friendRequest,
            label: notification.isRead
                ? 'Read notification'
                : 'Unread notification',
            child: InkWell(
              onTap: () => _open(notification),
              borderRadius: BorderRadius.circular(AppRadius.sm),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  NoriIconBadge(
                    icon: notification.icon,
                    background: notification.color,
                    size: 48,
                    iconSize: 24,
                    circle: true,
                  ),
                  const SizedBox(width: AppSpacing.stackSm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(notification.message, style: AppTextStyles.bodyMd),
                        const SizedBox(height: AppSpacing.unit),
                        Text(
                          relativeTimeLabel(notification.createdAt),
                          style: AppTextStyles.labelSm,
                        ),
                      ],
                    ),
                  ),
                  if (!notification.isRead)
                    const Icon(
                      Icons.circle,
                      size: AppSpacing.unit,
                      color: AppColors.terracottaDark,
                    ),
                ],
              ),
            ),
          ),
          if (actionable) ...[
            const SizedBox(height: AppSpacing.stackSm),
            Row(
              children: [
                Expanded(
                  child: TactileButton(
                    label: friendRequest ? 'Accept' : 'Join',
                    onPressed: _busy
                        ? null
                        : () => _act(
                            () => friendRequest
                                ? AppData.social.acceptFriendRequest(id)
                                : AppData.social.acceptCompetitionInvite(id),
                            friendRequest
                                ? 'Friend request accepted'
                                : 'Competition joined',
                          ),
                  ),
                ),
                const SizedBox(width: AppSpacing.stackSm),
                Expanded(
                  child: TextButton(
                    onPressed: _busy
                        ? null
                        : () => _act(
                            () => friendRequest
                                ? AppData.social.declineFriendRequest(id)
                                : AppData.social.declineCompetitionInvite(id),
                            friendRequest
                                ? 'Friend request ignored'
                                : 'Invitation declined',
                          ),
                    child: Text(
                      friendRequest ? 'Ignore' : 'Decline',
                      style: AppTextStyles.labelLg.copyWith(
                        color: AppColors.mossDark,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.linen,
    body: SafeArea(
      child: buildLoaded(
        (context) => NoriScrollScaffold(
          maxWidth: 800,
          children: [
            NoriScreenHeader(
              leading: NoriScreenHeader.backButton(context),
              title: 'Notifications',
              titleStyle: AppTextStyles.headlineLgMobile,
            ),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: AppSpacing.unit,
              children: [
                TextButton(
                  onPressed: _busy || !_notifications.any((n) => !n.isRead)
                      ? null
                      : () => _act(
                          AppData.social.markAllNotificationsRead,
                          'All notifications marked as read',
                        ),
                  child: Text('Mark all read', style: AppTextStyles.labelLg),
                ),
                TextButton(
                  onPressed: _busy || _notifications.isEmpty
                      ? null
                      : () => _act(
                          AppData.social.clearNotifications,
                          'Notifications cleared',
                        ),
                  child: Text('Clear', style: AppTextStyles.labelLg),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.stackMd),
            if (_notifications.isEmpty)
              const NoriEmptyState(
                icon: Icons.notifications_none,
                title: "You're all caught up",
                message: 'Friend requests and encouragement will appear here.',
              )
            else
              for (final notification in _notifications) ...[
                _notificationCard(notification),
                const SizedBox(height: AppSpacing.stackSm),
              ],
          ],
        ),
      ),
    ),
  );
}
