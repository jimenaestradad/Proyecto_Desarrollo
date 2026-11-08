import 'package:flutter/material.dart';
import 'package:nori/models/social_content.dart';
import 'package:nori/theme/app_theme.dart';
import 'package:nori/utils/relative_time.dart';
import 'package:nori/widgets/nori_card.dart';
import 'package:nori/widgets/nori_icon_badge.dart';
import 'package:nori/widgets/tactile_button.dart';

/// One social notification in the shared inbox. Friend requests and
/// competition invites carry an answer (Accept/Ignore, Join/Decline); every
/// other kind just opens its target. The inbox supplies the callbacks.
class SocialNotificationCard extends StatelessWidget {
  const SocialNotificationCard({
    super.key,
    required this.notification,
    required this.busy,
    required this.onOpen,
    required this.onAccept,
    required this.onDecline,
  });

  final SocialNotification notification;

  /// An answer is in flight; the buttons wait.
  final bool busy;
  final VoidCallback onOpen;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    final friendRequest =
        notification.kind == SocialNotificationKind.friendRequest;
    final competitionInvite =
        notification.kind == SocialNotificationKind.competitionInvite;
    final actionable =
        (friendRequest || competitionInvite) && notification.refId != null;
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
              onTap: onOpen,
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
                    onPressed: busy ? null : onAccept,
                  ),
                ),
                const SizedBox(width: AppSpacing.stackSm),
                Expanded(
                  child: TextButton(
                    onPressed: busy ? null : onDecline,
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
}
