import 'package:flutter/material.dart';
import 'package:nori/data/app_data.dart';
import 'package:nori/models/competition.dart';
import 'package:nori/models/social_content.dart';
import 'package:nori/models/social_people.dart';
import 'package:nori/screens/social/circle_editor_screen.dart';
import 'package:nori/screens/social/competition_detail_screen.dart';
import 'package:nori/screens/social/competition_invite_screen.dart';
import 'package:nori/screens/social/competition_results_screen.dart';
import 'package:nori/screens/social/create_competition_screen.dart';
import 'package:nori/screens/social/feed_screen.dart';
import 'package:nori/screens/social/friend_profile_screen.dart';
import 'package:nori/screens/social/leaderboard_screen.dart';
import 'package:nori/screens/social/post_actions_sheet.dart';
import 'package:nori/screens/social/post_detail_screen.dart';
import 'package:nori/screens/social/social_load_state.dart';
import 'package:nori/screens/social/widgets/social_widgets.dart';
import 'package:nori/theme/app_theme.dart';
import 'package:nori/utils/remote_errors.dart';
import 'package:nori/widgets/circular_icon_button.dart';
import 'package:nori/widgets/nori_bottom_sheet.dart';
import 'package:nori/widgets/nori_card.dart';
import 'package:nori/widgets/nori_empty_state.dart';
import 'package:nori/widgets/nori_icon_badge.dart';
import 'package:nori/widgets/nori_screen_header.dart';
import 'package:nori/widgets/nori_scroll_scaffold.dart';
import 'package:nori/widgets/progress_bar_pill.dart';
import 'package:nori/widgets/section_header.dart';
import 'package:nori/widgets/tactile_button.dart';
import 'package:nori/widgets/xp_pill.dart';

class CircleDetailScreen extends StatefulWidget {
  const CircleDetailScreen({super.key, required this.circleId});
  final String circleId;

  @override
  State<CircleDetailScreen> createState() => _CircleDetailScreenState();
}

class _CircleDetailScreenState extends State<CircleDetailScreen>
    with
        RemoteLoadState<CircleDetailScreen>,
        SocialLoadState<CircleDetailScreen> {
  SocialCircle? _circle;
  Map<String, SocialUser> _people = {};
  List<LeaderboardEntry> _leaders = [];
  List<SocialPost> _posts = [];
  List<Competition> _competitions = [];
  bool _nudging = false;
  bool _leaving = false;

  @override
  Future<void> loadSocial() async {
    final circles = await AppData.social.getCircles();
    SocialCircle? circle;
    for (final item in circles) {
      if (item.id == widget.circleId) circle = item;
    }
    if (circle == null) {
      if (mounted) setState(() => _circle = null);
      return;
    }
    final people = await AppData.social.getUserDirectory();
    final leaders = await AppData.social.getLeaderboard(
      circleId: widget.circleId,
    );
    final posts = await AppData.social.getPosts(circleId: widget.circleId);
    final competitions = await AppData.social.getCompetitions();
    if (!mounted) return;
    setState(() {
      _circle = circle;
      _people = people;
      _leaders = leaders.take(3).toList();
      _posts = posts.take(3).toList();
      _competitions = competitions
          .where((c) => c.circleId == widget.circleId)
          .toList();
    });
  }

  void _open(Widget screen) =>
      Navigator.push(context, MaterialPageRoute<void>(builder: (_) => screen));

  void _profile(SocialUser user) {
    if (!user.isMe) _open(FriendProfileScreen(userId: user.id));
  }

  Future<void> _nudge() async {
    if (_nudging) return;
    setState(() => _nudging = true);
    var count = 0;
    final success = await guardedAction(() async {
      count = await AppData.social.nudgeCircle(widget.circleId);
    });
    if (!mounted) return;
    setState(() => _nudging = false);
    if (success) showSocialToast(context, 'Nudged $count friends');
  }

  Future<void> _leave() async {
    if (_leaving) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          side: const BorderSide(color: AppColors.ink, width: AppBorder.thin),
        ),
        title: Text(
          'Leave ${_circle!.name}?',
          style: AppTextStyles.headlineLgMobile,
        ),
        content: Text(
          'This circle will be removed from your circles.',
          style: AppTextStyles.bodyMd,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text('Cancel', style: AppTextStyles.labelLg),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text('Leave circle', style: AppTextStyles.labelLg),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _leaving = true);
    final success = await guardedAction(
      () => AppData.social.leaveCircle(widget.circleId),
    );
    if (!mounted) return;
    setState(() => _leaving = false);
    if (success) {
      showSocialToast(context, 'Left circle');
      Navigator.pop(context);
    }
  }

  void _openCompetition(Competition c) => _open(switch (c.status) {
    CompetitionStatus.active => CompetitionDetailScreen(competitionId: c.id),
    CompetitionStatus.invited => CompetitionInviteScreen(competitionId: c.id),
    CompetitionStatus.past => CompetitionResultsScreen(competitionId: c.id),
  });

  Widget _empty(String title, String message, IconData icon) =>
      NoriEmptyState(icon: icon, title: title, message: message);

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: buildLoaded((context) {
        final circle = _circle;
        final members = circle == null
            ? <SocialUser>[]
            : [for (final id in circle.memberIds) ?_people[id]];
        return NoriScrollScaffold(
          maxWidth: 800,
          children: [
            NoriScreenHeader(
              leading: NoriScreenHeader.backButton(context),
              title: circle?.name ?? 'Circle',
              titleStyle: AppTextStyles.headlineLgMobile,
              trailing: circle == null
                  ? null
                  : CircularIconButton(
                      icon: Icons.edit_outlined,
                      tooltip: 'Edit circle',
                      onPressed: () =>
                          _open(CircleEditorScreen(circleId: circle.id)),
                    ),
            ),
            const SizedBox(height: AppSpacing.stackMd),
            if (circle == null)
              _empty(
                'Circle unavailable',
                'This circle is no longer in your circles.',
                Icons.groups_outlined,
              )
            else ...[
              NoriCard(
                color: circle.color,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        NoriIconBadge(
                          icon: circle.icon,
                          background: AppColors.white,
                          size: 56,
                          iconSize: 28,
                        ),
                        const SizedBox(width: AppSpacing.stackSm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${(circle.completionRate * 100).round()}% completion',
                                style: AppTextStyles.headlineLgMobile,
                              ),
                              Text(
                                'Your circle this week',
                                style: AppTextStyles.bodyMd,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.gutter),
                    ProgressBarPill(
                      progress: circle.completionRate,
                      semanticLabel: 'Circle completion',
                    ),
                    if (circle.activityLine.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.unit),
                      Text(circle.activityLine, style: AppTextStyles.bodyMd),
                    ],
                    const SizedBox(height: AppSpacing.stackMd),
                    TactileButton(
                      label: _nudging ? 'Nudging...' : 'Nudge all',
                      icon: Icons.notifications_active_outlined,
                      onPressed: _nudging || circle.friendCount == 0
                          ? null
                          : _nudge,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.stackLg),
              SectionHeader(
                icon: Icons.groups_outlined,
                title: 'Members',
                trailing: Text(
                  '${members.length}',
                  style: AppTextStyles.labelLg,
                ),
              ),
              const SizedBox(height: AppSpacing.stackSm),
              if (members.isEmpty)
                _empty(
                  'No members yet',
                  'Add friends from Edit circle.',
                  Icons.groups_outlined,
                )
              else
                for (final member in members) ...[
                  PersonRow(
                    user: member,
                    subtitle: member.isMe ? 'You' : member.statusLine,
                    highlighted: member.isMe,
                    onTap: member.isMe ? null : () => _profile(member),
                  ),
                  const SizedBox(height: AppSpacing.stackSm),
                ],
              const SizedBox(height: AppSpacing.stackLg),
              SectionHeader(
                icon: Icons.leaderboard_outlined,
                title: 'Circle leaderboard',
                trailing: const SizedBox.shrink(),
              ),
              const SizedBox(height: AppSpacing.stackSm),
              if (_leaders.isEmpty)
                _empty(
                  'No rankings yet',
                  'Circle activity will appear here.',
                  Icons.leaderboard_outlined,
                )
              else
                for (final entry in _leaders) ...[
                  PersonRow(
                    user: entry.user,
                    subtitle: '#${entry.rank} this week',
                    highlighted: entry.user.isMe,
                    trailing: XpPill(xp: entry.xp, compact: true),
                    onTap: entry.user.isMe ? null : () => _profile(entry.user),
                  ),
                  const SizedBox(height: AppSpacing.stackSm),
                ],
              Align(
                alignment: Alignment.centerRight,
                child: SectionLink(
                  label: 'Full leaderboard',
                  onTap: () =>
                      _open(LeaderboardScreen(initialCircleId: circle.id)),
                ),
              ),
              const SizedBox(height: AppSpacing.stackLg),
              SectionHeader(
                icon: Icons.dynamic_feed_outlined,
                title: 'Circle feed',
                trailing: SectionLink(
                  label: 'See all',
                  onTap: () => _open(FeedScreen(initialCircleId: circle.id)),
                ),
              ),
              const SizedBox(height: AppSpacing.stackSm),
              if (_posts.isEmpty)
                Text(
                  'No proofs shared in this circle yet.',
                  style: AppTextStyles.bodyMd.copyWith(
                    color: AppColors.inkFaint,
                  ),
                )
              else
                for (final post in _posts)
                  if (_people[post.authorId] case final author?) ...[
                    PostCard(
                      post: post,
                      author: author,
                      compact: true,
                      contextLabel: circle.name,
                      onTap: () => _open(PostDetailScreen(postId: post.id)),
                      onAuthorTap: author.isMe ? null : () => _profile(author),
                      onMenu: () => showPostActionsSheet(
                        context,
                        post: post,
                        author: author,
                      ),
                      onReactionToggle: (reaction) => guardedAction(() async {
                        await AppData.social.toggleReaction(post.id, reaction);
                      }),
                    ),
                    const SizedBox(height: AppSpacing.stackSm),
                  ],
              const SizedBox(height: AppSpacing.stackLg),
              SectionHeader(
                icon: Icons.emoji_events_outlined,
                title: 'Competitions',
                trailing: SectionLink(
                  label: 'Start one',
                  onTap: () =>
                      _open(CreateCompetitionScreen(presetCircleId: circle.id)),
                ),
              ),
              const SizedBox(height: AppSpacing.stackSm),
              if (_competitions.isEmpty)
                NoriEmptyState(
                  icon: Icons.emoji_events_outlined,
                  title: 'No competitions yet',
                  message: 'Give your circle a shared habit goal.',
                  actionLabel: 'Start one',
                  onAction: () =>
                      _open(CreateCompetitionScreen(presetCircleId: circle.id)),
                )
              else
                for (final competition in _competitions) ...[
                  _CircleCompetitionCard(
                    competition: competition,
                    onTap: () => _openCompetition(competition),
                  ),
                  const SizedBox(height: AppSpacing.stackSm),
                ],
              const SizedBox(height: AppSpacing.stackLg),
              NoriSheetAction(
                icon: Icons.logout,
                label: _leaving ? 'Leaving...' : 'Leave circle',
                destructive: true,
                onTap: _leave,
              ),
            ],
          ],
        );
      }),
    ),
  );
}

class _CircleCompetitionCard extends StatelessWidget {
  const _CircleCompetitionCard({
    required this.competition,
    required this.onTap,
  });
  final Competition competition;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: NoriCard(
        color: competition.color,
        padding: const EdgeInsets.all(AppSpacing.gutter),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                NoriIconBadge(
                  icon: competition.icon,
                  background: AppColors.white,
                  size: 40,
                  iconSize: 20,
                ),
                const SizedBox(width: AppSpacing.stackSm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(competition.title, style: AppTextStyles.labelLg),
                      Text(
                        competition.status == CompetitionStatus.invited
                            ? 'Invitation · ${competition.timeLeftLabel}'
                            : competition.timeLeftLabel,
                        style: AppTextStyles.labelSm,
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: AppColors.ink),
              ],
            ),
            const SizedBox(height: AppSpacing.stackSm),
            ProgressBarPill(
              progress: competition.myFraction,
              semanticLabel: 'Your competition progress',
            ),
            const SizedBox(height: AppSpacing.unit),
            Text(
              '${competition.myProgress}/${competition.targetCount} · ${competition.participantIds.length} participants',
              style: AppTextStyles.labelSm,
            ),
          ],
        ),
      ),
    ),
  );
}
