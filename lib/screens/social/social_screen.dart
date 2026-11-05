import 'package:flutter/material.dart';
import 'package:nori/data/app_data.dart';
import 'package:nori/models/competition.dart';
import 'package:nori/models/nori_user.dart';
import 'package:nori/models/social_content.dart';
import 'package:nori/models/social_people.dart';
import 'package:nori/screens/social/add_friend_screen.dart';
import 'package:nori/screens/social/circle_detail_screen.dart';
import 'package:nori/screens/social/circle_editor_screen.dart';
import 'package:nori/screens/social/circles_screen.dart';
import 'package:nori/screens/social/competition_detail_screen.dart';
import 'package:nori/screens/social/competition_invite_screen.dart';
import 'package:nori/screens/social/competition_results_screen.dart';
import 'package:nori/screens/social/competitions_screen.dart';
import 'package:nori/screens/social/create_competition_screen.dart';
import 'package:nori/screens/social/feed_screen.dart';
import 'package:nori/screens/social/friend_profile_screen.dart';
import 'package:nori/screens/social/friend_streak_detail_screen.dart';
import 'package:nori/screens/social/friend_streaks_screen.dart';
import 'package:nori/screens/social/friends_screen.dart';
import 'package:nori/screens/social/invite_friends_screen.dart';
import 'package:nori/screens/social/leaderboard_screen.dart';
import 'package:nori/screens/social/post_actions_sheet.dart';
import 'package:nori/screens/social/post_detail_screen.dart';
import 'package:nori/screens/social/post_proof_screen.dart';
import 'package:nori/screens/social/social_intro_view.dart';
import 'package:nori/screens/social/social_load_state.dart';
import 'package:nori/screens/social/social_notifications_screen.dart';
import 'package:nori/screens/social/social_privacy_screen.dart';
import 'package:nori/screens/social/widgets/social_widgets.dart';
import 'package:nori/theme/app_theme.dart';
import 'package:nori/utils/formatting.dart';
import 'package:nori/utils/remote_errors.dart';
import 'package:nori/widgets/circular_icon_button.dart';
import 'package:nori/widgets/nori_avatar.dart';
import 'package:nori/widgets/nori_card.dart';
import 'package:nori/widgets/nori_choice_chip.dart';
import 'package:nori/widgets/nori_empty_state.dart';
import 'package:nori/widgets/nori_icon_badge.dart';
import 'package:nori/widgets/nori_screen_header.dart';
import 'package:nori/widgets/nori_scroll_scaffold.dart';
import 'package:nori/widgets/progress_bar_pill.dart';
import 'package:nori/widgets/section_header.dart';
import 'package:nori/widgets/streak_chip.dart';
import 'package:nori/widgets/tactile_button.dart';
import 'package:nori/widgets/xp_pill.dart';

class SocialScreen extends StatefulWidget {
  const SocialScreen({super.key, required this.active});

  /// See [HomeScreen.active] — same [IndexedStack] staleness fix. Without it
  /// the header kept the XP from the first visit after claims on other tabs.
  final bool active;

  @override
  State<SocialScreen> createState() => _SocialScreenState();
}

class _SocialScreenState extends State<SocialScreen>
    with RemoteLoadState<SocialScreen>, SocialLoadState<SocialScreen> {
  late NoriUser _user;
  List<SocialUser> _friends = [];
  List<FriendRequest> _requests = [];
  Map<String, SocialUser> _directory = {};
  List<SocialPost> _posts = [];
  List<FriendStreak> _streaks = [];
  List<LeaderboardEntry> _leaderboard = [];
  List<Competition> _competitions = [];
  List<SocialCircle> _circles = [];
  int _unread = 0;
  final Set<String> _nudged = {};
  final Set<String> _nudging = {};
  bool _resetting = false;

  @override
  void didUpdateWidget(covariant SocialScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.active && widget.active) reload();
  }

  @override
  Future<void> loadSocial() async {
    final (identity, activity) = await (
      (
        AppData.user.getCurrentUser(),
        AppData.social.getFriends(),
        AppData.social.getFriendRequests(),
        AppData.social.getUserDirectory(),
        AppData.social.getPosts(),
        AppData.social.getFriendStreaks(),
      ).wait,
      (
        AppData.social.getLeaderboard(),
        AppData.social.getCompetitions(),
        AppData.social.getCircles(),
        AppData.social.getUnreadNotificationCount(),
      ).wait,
    ).wait;
    if (!mounted) return;
    setState(() {
      _user = identity.$1;
      _friends = identity.$2;
      _requests = identity.$3;
      _directory = identity.$4;
      _posts = [...identity.$5]
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      _streaks = [...identity.$6]
        ..sort((a, b) => b.current.compareTo(a.current));
      _leaderboard = activity.$1;
      _competitions = activity.$2;
      _circles = activity.$3;
      _unread = activity.$4;
    });
  }

  void _open(Widget screen) {
    Navigator.push(context, MaterialPageRoute<void>(builder: (_) => screen));
  }

  void _openProfile(SocialUser user) {
    if (!user.isMe) _open(FriendProfileScreen(userId: user.id));
  }

  Future<void> _nudge(SocialUser friend) async {
    if (_nudged.contains(friend.id) || _nudging.contains(friend.id)) return;
    setState(() => _nudging.add(friend.id));
    final success = await guardedAction(() => AppData.social.nudge(friend.id));
    if (!mounted) return;
    setState(() {
      _nudging.remove(friend.id);
      if (success) _nudged.add(friend.id);
    });
    if (success) showSocialToast(context, 'Nudge sent to ${friend.firstName}');
  }

  Future<void> _selectMenu(_HubAction action) async {
    switch (action) {
      case _HubAction.invite:
        _open(const InviteFriendsScreen());
      case _HubAction.streaks:
        _open(const FriendStreaksScreen());
      case _HubAction.privacy:
        _open(const SocialPrivacyScreen());
      case _HubAction.preview:
        if (_resetting) return;
        setState(() => _resetting = true);
        // Mock-only preview control; remove when social data has a backend.
        final success = await guardedAction(
          () => AppData.social.resetDemo(
            empty: _friends.isNotEmpty || _requests.isNotEmpty,
          ),
        );
        if (!mounted) return;
        setState(() {
          _resetting = false;
          if (success) _nudged.clear();
        });
        if (success) showSocialToast(context, 'Social preview updated');
    }
  }

  Widget _header() => NoriScreenHeader(
    leading: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        NoriAvatar(imageUrl: _user.avatarUrl),
        const SizedBox(width: AppSpacing.unit),
      ],
    ),
    title: 'Social',
    titleStyle: AppTextStyles.headlineMd,
    trailing: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        XpPill(xp: _user.totalXp, compact: true),
        const SizedBox(width: AppSpacing.unit),
        CircularIconButton(
          icon: Icons.notifications_none,
          tooltip: _unread > 0
              ? 'Notifications, $_unread unread'
              : 'Notifications',
          showDot: _unread > 0,
          onPressed: () => _open(const SocialNotificationsScreen()),
        ),
        PopupMenuButton<_HubAction>(
          tooltip: 'Social options',
          enabled: !_resetting,
          icon: const Icon(Icons.more_vert, color: AppColors.ink),
          color: AppColors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            side: const BorderSide(color: AppColors.ink, width: AppBorder.thin),
          ),
          onSelected: _selectMenu,
          itemBuilder: (_) => [
            _menuItem(_HubAction.invite, Icons.link, 'Invite friends'),
            _menuItem(
              _HubAction.streaks,
              Icons.local_fire_department,
              'Friend streaks',
            ),
            _menuItem(
              _HubAction.privacy,
              Icons.lock_outline,
              'Privacy settings',
            ),
            const PopupMenuDivider(),
            _menuItem(
              _HubAction.preview,
              Icons.restart_alt,
              _friends.isEmpty && _requests.isEmpty
                  ? 'Preview: restore demo data'
                  : 'Preview: no friends yet',
            ),
          ],
        ),
      ],
    ),
  );

  PopupMenuItem<_HubAction> _menuItem(
    _HubAction action,
    IconData icon,
    String label,
  ) => PopupMenuItem(
    value: action,
    child: Row(
      children: [
        Icon(icon, color: AppColors.ink),
        const SizedBox(width: AppSpacing.unit),
        Flexible(child: Text(label, style: AppTextStyles.labelLg)),
      ],
    ),
  );

  Widget _section(
    String title,
    IconData icon,
    Widget destination, {
    String link = 'See all',
  }) => Padding(
    padding: const EdgeInsets.only(
      top: AppSpacing.stackLg,
      bottom: AppSpacing.stackSm,
    ),
    child: SectionHeader(
      title: title,
      icon: icon,
      trailing: SectionLink(label: link, onTap: () => _open(destination)),
    ),
  );

  Widget _quickActions() {
    final pending = _requests
        .where(
          (request) => request.direction == FriendRequestDirection.incoming,
        )
        .length;
    return SingleChildScrollView(
      clipBehavior: Clip.none,
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              NoriChoiceChip(
                label: 'Friends (${_friends.length})',
                selected: false,
                icon: Icons.people_outline,
                onTap: () => _open(const FriendsScreen()),
              ),
              if (pending > 0)
                Positioned(
                  top: -AppSpacing.unit,
                  right: 0,
                  child: NoriCard(
                    color: AppColors.mustard,
                    radius: AppRadius.full,
                    borderWidth: AppBorder.thin,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.unit,
                    ),
                    child: Text('$pending', style: AppTextStyles.labelSm),
                  ),
                ),
            ],
          ),
          const SizedBox(width: AppSpacing.unit),
          NoriChoiceChip(
            label: 'Add',
            selected: false,
            icon: Icons.person_add_outlined,
            onTap: () => _open(const AddFriendScreen()),
          ),
          const SizedBox(width: AppSpacing.unit),
          NoriChoiceChip(
            label: 'Post proof',
            selected: false,
            icon: Icons.add_a_photo_outlined,
            onTap: () => _open(const PostProofScreen()),
          ),
        ],
      ),
    );
  }

  Widget _highlight({required Color color, required List<Widget> children}) =>
      SizedBox(
        width: 280,
        child: NoriCard(
          color: color,
          padding: const EdgeInsets.all(AppSpacing.gutter),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        ),
      );

  Widget _highlights(List<Competition> active) {
    final streak = _streaks.isEmpty ? null : _streaks.first;
    final friend = streak == null ? null : _directory[streak.friendId];
    final myEntries = _leaderboard.where((entry) => entry.user.isMe);
    final mine = myEntries.isEmpty ? null : myEntries.first;
    final leaders = _leaderboard.where((entry) => entry.rank == 1);
    final leader = leaders.isEmpty ? null : leaders.first;
    return SizedBox(
      height: 190,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          if (streak != null && friend != null) ...[
            _highlight(
              color: AppColors.mossLight,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Best friend streak',
                        style: AppTextStyles.labelLg,
                      ),
                    ),
                    StreakChip(streak: streak.current),
                  ],
                ),
                const SizedBox(height: AppSpacing.unit),
                InkWell(
                  onTap: () => _openProfile(friend),
                  child: Row(
                    children: [
                      SocialAvatar(user: friend, size: 48),
                      const SizedBox(width: AppSpacing.stackSm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              friend.shortName,
                              style: AppTextStyles.headlineLgMobile,
                            ),
                            Text(
                              friend.statusLine,
                              style: AppTextStyles.bodyMd,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.unit),
                Row(
                  children: [
                    Expanded(
                      child: TactileButton(
                        label: _nudged.contains(friend.id) ? 'Nudged' : 'Nudge',
                        backgroundColor: AppColors.white,
                        onPressed:
                            _nudged.contains(friend.id) ||
                                _nudging.contains(friend.id)
                            ? null
                            : () => _nudge(friend),
                      ),
                    ),
                    TextButton(
                      onPressed: () =>
                          _open(FriendStreakDetailScreen(friendId: friend.id)),
                      child: Text('Details', style: AppTextStyles.labelLg),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(width: AppSpacing.stackSm),
          ],
          _highlight(
            color: AppColors.mustardLight,
            children: [
              Text('Leaderboard', style: AppTextStyles.labelLg),
              const SizedBox(height: AppSpacing.stackSm),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    mine == null ? 'Join in' : '#${mine.rank}',
                    style: AppTextStyles.headlineLg,
                  ),
                  const SizedBox(width: AppSpacing.unit),
                  Text('this week', style: AppTextStyles.bodyMd),
                ],
              ),
              Text(
                mine == null
                    ? 'Build habits with friends to find your place.'
                    : mine.rank == 1
                    ? "${formatThousands(mine.xp)} XP · You're #1"
                    : '${formatThousands(mine.xp)} XP${leader == null ? '' : ' · ${formatThousands((leader.xp - mine.xp).clamp(0, leader.xp))} behind #1 ${leader.user.firstName}'}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.bodyMd,
              ),
              SectionLink(
                label: 'View standings',
                onTap: () => _open(const LeaderboardScreen()),
              ),
            ],
          ),
          const SizedBox(width: AppSpacing.stackSm),
          _highlight(
            color: AppColors.sky,
            children: [
              Text('Competitions', style: AppTextStyles.labelLg),
              const SizedBox(height: AppSpacing.stackSm),
              Text(
                '${active.length} in progress',
                style: AppTextStyles.headlineLgMobile,
              ),
              const SizedBox(height: AppSpacing.stackSm),
              Text(
                active.isEmpty
                    ? 'Start a little friendly competition.'
                    : '${active.first.title} · ${active.first.timeLeftLabel}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.bodyMd,
              ),
              SectionLink(
                label: 'Check ranks',
                onTap: () => _open(const CompetitionsScreen()),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String? _postContext(SocialPost post) {
    for (final competition in _competitions) {
      if (competition.id == post.competitionId) return competition.title;
    }
    for (final circle in _circles) {
      if (circle.id == post.circleId) return circle.name;
    }
    return null;
  }

  Widget _post(SocialPost post) {
    final author = _directory[post.authorId]!;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.stackSm),
      child: PostCard(
        post: post,
        author: author,
        compact: true,
        contextLabel: _postContext(post),
        onTap: () => _open(PostDetailScreen(postId: post.id)),
        onAuthorTap: author.isMe ? null : () => _openProfile(author),
        onMenu: () => showPostActionsSheet(context, post: post, author: author),
        onReactionToggle: (reaction) => guardedAction(
          () => AppData.social.toggleReaction(post.id, reaction),
        ),
      ),
    );
  }

  Widget _streakStrip() => SizedBox(
    height: 180,
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      itemCount: _streaks.length,
      separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.stackSm),
      itemBuilder: (context, index) {
        final streak = _streaks[index];
        final friend = _directory[streak.friendId];
        if (friend == null) return const SizedBox.shrink();
        return SizedBox(
          width: 128,
          child: NoriCard(
            padding: const EdgeInsets.all(AppSpacing.stackSm),
            child: SingleChildScrollView(
              child: Column(
                children: [
                  InkWell(
                    onTap: () => _openProfile(friend),
                    child: Column(
                      children: [
                        SocialAvatar(user: friend),
                        const SizedBox(height: AppSpacing.unit),
                        Text(friend.firstName, style: AppTextStyles.labelLg),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.unit),
                  InkWell(
                    onTap: () =>
                        _open(FriendStreakDetailScreen(friendId: friend.id)),
                    child: StreakChip(streak: streak.current),
                  ),
                  if (streak.days.isNotEmpty && streak.atRisk) ...[
                    const SizedBox(height: AppSpacing.unit),
                    NoriCard(
                      color: AppColors.terracotta,
                      radius: AppRadius.full,
                      borderWidth: AppBorder.thin,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.unit,
                      ),
                      child: Text(
                        'At risk',
                        style: AppTextStyles.labelSm.copyWith(
                          color: AppColors.ink,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    ),
  );

  void _openCompetition(Competition competition) =>
      _open(switch (competition.status) {
        CompetitionStatus.active => CompetitionDetailScreen(
          competitionId: competition.id,
        ),
        CompetitionStatus.invited => CompetitionInviteScreen(
          competitionId: competition.id,
        ),
        CompetitionStatus.past => CompetitionResultsScreen(
          competitionId: competition.id,
        ),
      });

  Widget _competitionCard(Competition competition) {
    final leaderId = competition.standings.firstOrNull;
    final leader = _directory[leaderId];
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.stackSm),
      child: InkWell(
        onTap: () => _openCompetition(competition),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: NoriCard(
          color: competition.color,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  NoriIconBadge(
                    icon: competition.icon,
                    background: competition.color,
                    size: 48,
                    iconSize: 24,
                  ),
                  const SizedBox(width: AppSpacing.stackSm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(competition.title, style: AppTextStyles.labelLg),
                        Text(
                          competition.timeLeftLabel,
                          style: AppTextStyles.labelSm,
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: AppColors.ink),
                ],
              ),
              const SizedBox(height: AppSpacing.stackSm),
              Text(
                'Your progress: ${competition.myProgress}/${competition.targetCount}',
                style: AppTextStyles.labelSm,
              ),
              const SizedBox(height: AppSpacing.unit),
              ProgressBarPill(
                progress: competition.myFraction,
                semanticLabel: '${competition.title}, your progress',
              ),
              const SizedBox(height: AppSpacing.unit),
              Text(
                leaderId == null
                    ? 'No entries yet'
                    : 'Leader: ${leader?.isMe == true ? 'You' : leader?.shortName ?? 'Friend'} (${competition.progress[leaderId] ?? 0}/${competition.targetCount})',
                style: AppTextStyles.labelSm,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _circleStrip() => SizedBox(
    height: 76,
    child: ListView(
      scrollDirection: Axis.horizontal,
      children: [
        for (final circle in _circles) ...[
          SizedBox(
            width: 188,
            child: InkWell(
              onTap: () => _open(CircleDetailScreen(circleId: circle.id)),
              borderRadius: BorderRadius.circular(AppRadius.sm),
              child: NoriCard(
                color: circle.color,
                padding: const EdgeInsets.all(AppSpacing.stackSm),
                child: Row(
                  children: [
                    NoriIconBadge(
                      icon: circle.icon,
                      background: AppColors.white,
                      size: 40,
                      iconSize: 20,
                    ),
                    const SizedBox(width: AppSpacing.stackSm),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            circle.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.labelLg,
                          ),
                          Text(
                            '${circle.friendCount} friends',
                            style: AppTextStyles.labelSm,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.stackSm),
        ],
        SizedBox(
          width: 148,
          child: InkWell(
            onTap: () => _open(const CircleEditorScreen()),
            borderRadius: BorderRadius.circular(AppRadius.sm),
            child: NoriCard(
              color: AppColors.linenAlt,
              borderColor: AppColors.inkFaint,
              borderWidth: AppBorder.thin,
              padding: const EdgeInsets.all(AppSpacing.stackSm),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.add_circle_outline,
                    color: AppColors.inkFaint,
                  ),
                  const SizedBox(width: AppSpacing.unit),
                  Text(
                    'New circle',
                    style: AppTextStyles.labelLg.copyWith(
                      color: AppColors.inkFaint,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    ),
  );

  List<Widget> _dashboard() {
    final active =
        _competitions
            .where(
              (competition) => competition.status == CompetitionStatus.active,
            )
            .toList()
          ..sort((a, b) => a.endsAt.compareTo(b.endsAt));
    final posts = _posts
        .where((post) => _directory.containsKey(post.authorId))
        .take(2)
        .toList();
    return [
      _quickActions(),
      const SizedBox(height: AppSpacing.stackMd),
      _highlights(active),
      _section('Recent Proofs', Icons.rss_feed, const FeedScreen()),
      if (posts.isEmpty)
        NoriEmptyState(
          icon: Icons.add_a_photo_outlined,
          title: 'No proofs yet',
          message: 'Share a completed habit and cheer your friends on.',
          actionLabel: 'Post proof',
          onAction: () => _open(const PostProofScreen()),
        )
      else
        ...posts.map(_post),
      if (_streaks.isNotEmpty) ...[
        _section(
          'Friend streaks',
          Icons.local_fire_department,
          const FriendStreaksScreen(),
        ),
        _streakStrip(),
      ],
      _section(
        'Active Competitions',
        Icons.emoji_events_outlined,
        const CompetitionsScreen(),
      ),
      if (active.isEmpty)
        NoriEmptyState(
          icon: Icons.emoji_events_outlined,
          title: 'No active competitions',
          message: 'Pick a habit to work on together.',
          actionLabel: 'Start one',
          onAction: () => _open(const CreateCompetitionScreen()),
        )
      else
        ...active.take(2).map(_competitionCard),
      _section(
        'My Circles',
        Icons.groups_outlined,
        const CirclesScreen(),
        link: 'Manage',
      ),
      if (_circles.isEmpty)
        NoriEmptyState(
          icon: Icons.groups_outlined,
          title: 'No circles yet',
          message: 'Make a small group for your shared habits.',
          actionLabel: 'Create a circle',
          onAction: () => _open(const CircleEditorScreen()),
        ),
      _circleStrip(),
    ];
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.linen,
    body: SafeArea(
      child: buildLoaded(
        (context) => NoriScrollScaffold(
          maxWidth: 800,
          children: [
            _header(),
            const SizedBox(height: AppSpacing.stackMd),
            if (_friends.isEmpty && _requests.isEmpty)
              SocialIntroView(
                onFindFriends: () => _open(const AddFriendScreen()),
                onInvite: () => _open(const InviteFriendsScreen()),
              )
            else
              ..._dashboard(),
          ],
        ),
      ),
    ),
  );
}

enum _HubAction { invite, streaks, privacy, preview }
