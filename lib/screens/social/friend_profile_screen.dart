import 'package:flutter/material.dart';
import 'package:nori/data/app_data.dart';
import 'package:nori/models/social_people.dart';
import 'package:nori/models/social_content.dart';
import 'package:nori/screens/social/friend_actions_sheet.dart';
import 'package:nori/screens/social/friend_streak_detail_screen.dart';
import 'package:nori/screens/social/post_actions_sheet.dart';
import 'package:nori/screens/social/post_detail_screen.dart';
import 'package:nori/screens/social/social_load_state.dart';
import 'package:nori/screens/social/visit_pet_screen.dart';
import 'package:nori/screens/social/widgets/social_widgets.dart';
import 'package:nori/theme/app_theme.dart';
import 'package:nori/utils/formatting.dart';
import 'package:nori/utils/relative_time.dart';
import 'package:nori/utils/remote_errors.dart';
import 'package:nori/widgets/circular_icon_button.dart';
import 'package:nori/widgets/nori_card.dart';
import 'package:nori/widgets/nori_icon_badge.dart';
import 'package:nori/widgets/nori_screen_header.dart';
import 'package:nori/widgets/nori_scroll_scaffold.dart';
import 'package:nori/widgets/section_header.dart';
import 'package:nori/widgets/tactile_button.dart';

class FriendProfileScreen extends StatefulWidget {
  const FriendProfileScreen({super.key, required this.userId});
  final String userId;
  @override
  State<FriendProfileScreen> createState() => _FriendProfileScreenState();
}

class _FriendProfileScreenState extends State<FriendProfileScreen>
    with
        RemoteLoadState<FriendProfileScreen>,
        SocialLoadState<FriendProfileScreen> {
  SocialUser? _user;
  FriendStreak? _streak;
  List<SocialPost> _posts = [];
  bool _isFriend = false, _requested = false, _incoming = false;
  final Set<String> _busy = {};
  bool _nudged = false;

  @override
  Future<void> loadSocial() async {
    final user = await AppData.social.getUser(widget.userId);
    final friends = await AppData.social.getFriends();
    final streak = await AppData.social.getFriendStreak(widget.userId);
    final posts = await AppData.social.getPosts();
    final requests = await AppData.social.getFriendRequests();
    if (!mounted) return;
    setState(() {
      _user = user;
      _isFriend = friends.any((f) => f.id == user.id);
      _streak = streak;
      _posts = posts.where((p) => p.authorId == user.id).take(3).toList();
      _requested = requests.any(
        (r) =>
            r.user.id == user.id &&
            r.direction == FriendRequestDirection.outgoing,
      );
      _incoming = requests.any(
        (r) =>
            r.user.id == user.id &&
            r.direction == FriendRequestDirection.incoming,
      );
    });
  }

  void _push(Widget screen) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => screen));

  Future<void> _act(
    String key,
    Future<void> Function() action,
    String message,
  ) async {
    if (_busy.contains(key)) return;
    setState(() => _busy.add(key));
    final success = await guardedAction(action);
    if (!mounted) return;
    setState(() {
      _busy.remove(key);
      if (success && key == 'nudge') _nudged = true;
    });
    if (success) showSocialToast(context, message);
  }

  Widget _stat(String value, String label) => Expanded(
    child: Column(
      children: [
        Text(value, style: AppTextStyles.headlineLgMobile),
        Text(label, style: AppTextStyles.labelSm, textAlign: TextAlign.center),
      ],
    ),
  );

  Widget _pill(String label, {IconData? icon}) => NoriCard(
    radius: AppRadius.full,
    borderWidth: AppBorder.thin,
    color: AppColors.linenAlt,
    padding: const EdgeInsets.all(AppSpacing.unit),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 16, color: AppColors.ink),
          const SizedBox(width: AppSpacing.unit),
        ],
        Text(label, style: AppTextStyles.labelSm),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: buildLoaded((context) {
        final user = _user!;
        final streak = _streak;
        return NoriScrollScaffold(
          maxWidth: 800,
          children: [
            NoriScreenHeader(
              leading: NoriScreenHeader.backButton(context),
              title: 'Friend profile',
              titleStyle: AppTextStyles.headlineLgMobile,
              trailing: user.isMe
                  ? null
                  : CircularIconButton(
                      icon: Icons.more_horiz,
                      tooltip: 'Friend actions',
                      onPressed: () =>
                          showFriendActionsSheet(context, user: user),
                    ),
            ),
            const SizedBox(height: AppSpacing.stackMd),
            NoriCard(
              child: Column(
                children: [
                  SocialAvatar(user: user, size: AppSpacing.stackLg * 2),
                  const SizedBox(height: AppSpacing.unit),
                  _pill('Level ${user.level}', icon: Icons.star_outline),
                  const SizedBox(height: AppSpacing.stackSm),
                  Text(
                    user.name,
                    style: AppTextStyles.headlineLgMobile,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.unit),
                  Text(
                    '${user.handle}${_isFriend && user.friendSince != null ? ' • Friend since ${relativeTimeLabel(user.friendSince!)}' : ''}',
                    style: AppTextStyles.bodyMd.copyWith(
                      color: AppColors.inkMuted,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.stackMd),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _stat('${user.currentStreak}', 'Day streak'),
                      _stat('${user.proofCount}', 'Proofs'),
                      _stat(formatThousands(user.totalXp), 'Total XP'),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.stackMd),
            if (_isFriend) ...[
              Row(
                children: [
                  Expanded(
                    child: TactileButton(
                      label: _nudged ? 'Nudged' : 'Nudge',
                      onPressed: _busy.contains('nudge') || _nudged
                          ? null
                          : () => _act(
                              'nudge',
                              () => AppData.social.nudge(user.id),
                              'Nudge sent to ${user.firstName}',
                            ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.stackSm),
                  Expanded(
                    child: TactileButton(
                      label: 'High-five',
                      backgroundColor: AppColors.mossLight,
                      onPressed: _busy.contains('highFive')
                          ? null
                          : () => _act(
                              'highFive',
                              () => AppData.social.sendHighFive(user.id),
                              'High-five sent to ${user.firstName}',
                            ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.stackLg),
              NoriCard(
                color: AppColors.mossLight,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: AppSpacing.unit,
                      runSpacing: AppSpacing.unit,
                      children: [
                        Text(
                          user.petName,
                          style: AppTextStyles.headlineLgMobile,
                        ),
                        _pill('Stage ${user.petStage}'),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.stackMd),
                    const Center(
                      child: NoriIconBadge(
                        icon: Icons.pets,
                        background: AppColors.linenAlt,
                        size: AppSpacing.stackLg * 3,
                        iconSize: AppSpacing.stackLg * 2,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.stackMd),
                    Text(
                      '${user.petName} is happy to see you.',
                      style: AppTextStyles.bodyMd,
                    ),
                    if (user.statusLine.isNotEmpty)
                      Text(user.statusLine, style: AppTextStyles.labelSm),
                    const SizedBox(height: AppSpacing.stackMd),
                    TactileButton(
                      label: 'Visit room',
                      icon: Icons.cottage,
                      onPressed: () => _push(VisitPetScreen(userId: user.id)),
                    ),
                  ],
                ),
              ),
              if (streak != null) ...[
                const SizedBox(height: AppSpacing.stackMd),
                NoriCard(
                  color: AppColors.mustardLight,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Icon(
                        Icons.local_fire_department,
                        color: AppColors.mustardDark,
                        size: AppSpacing.stackLg,
                      ),
                      const SizedBox(height: AppSpacing.unit),
                      Text(
                        '${streak.current}-day streak together',
                        style: AppTextStyles.headlineLgMobile,
                      ),
                      if (streak.nextBadgeLabel.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.unit),
                        Text(
                          '${streak.daysToBadge} days until “${streak.nextBadgeLabel}”',
                          style: AppTextStyles.bodyMd,
                        ),
                      ],
                      Align(
                        alignment: Alignment.centerRight,
                        child: SectionLink(
                          label: 'Details',
                          onTap: () => _push(
                            FriendStreakDetailScreen(friendId: user.id),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ] else if (!user.isMe)
              TactileButton(
                label: _requested
                    ? 'Requested'
                    : _incoming
                    ? 'Accept request'
                    : 'Add friend',
                icon: Icons.person_add,
                onPressed: _requested || _busy.contains('request')
                    ? null
                    : () => _act(
                        'request',
                        () => _incoming
                            ? AppData.social.acceptFriendRequest(user.id)
                            : AppData.social.sendFriendRequest(user.id),
                        _incoming
                            ? '${user.firstName} is now your friend'
                            : 'Request sent to ${user.firstName}',
                      ),
              ),
            const SizedBox(height: AppSpacing.stackLg),
            const SectionHeader(
              title: 'Recent posts',
              trailing: SizedBox.shrink(),
            ),
            const SizedBox(height: AppSpacing.stackSm),
            if (_posts.isEmpty)
              Text(
                'No recent proofs shared yet.',
                style: AppTextStyles.bodyMd.copyWith(color: AppColors.inkFaint),
              )
            else
              for (final post in _posts) ...[
                PostCard(
                  post: post,
                  author: user,
                  compact: true,
                  onTap: () => _push(PostDetailScreen(postId: post.id)),
                  onAuthorTap: user.isMe
                      ? null
                      : () => _push(FriendProfileScreen(userId: user.id)),
                  onMenu: () =>
                      showPostActionsSheet(context, post: post, author: user),
                  onReactionToggle: (reaction) => _act(
                    'reaction-${post.id}',
                    () => AppData.social.toggleReaction(post.id, reaction),
                    'Reaction updated',
                  ),
                ),
                const SizedBox(height: AppSpacing.stackSm),
              ],
          ],
        );
      }),
    ),
  );
}
