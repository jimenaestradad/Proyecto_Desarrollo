import 'package:flutter/material.dart';
import 'package:nori/data/app_data.dart';
import 'package:nori/theme/app_theme.dart';
import 'package:nori/utils/remote_errors.dart';
import 'package:nori/screens/social/social_load_state.dart';
import 'package:nori/screens/social/widgets/social_widgets.dart';
import 'package:nori/widgets/nori_card.dart';
import 'package:nori/widgets/nori_screen_header.dart';
import 'package:nori/widgets/nori_scroll_scaffold.dart';
import 'package:nori/widgets/nori_empty_state.dart';
import 'package:nori/models/competition.dart';
import 'package:nori/models/social_content.dart';
import 'package:nori/models/social_people.dart';
import 'package:nori/widgets/circular_icon_button.dart';
import 'package:nori/widgets/nori_bottom_sheet.dart';
import 'package:nori/widgets/nori_choice_chip.dart';
import 'package:nori/widgets/nori_icon_badge.dart';
import 'package:nori/widgets/nori_segmented_control.dart';
import 'package:nori/widgets/progress_bar_pill.dart';
import 'package:nori/widgets/tactile_button.dart';
import 'package:nori/screens/social/competition_results_screen.dart';
import 'package:nori/screens/social/competition_invite_screen.dart';
import 'package:nori/screens/social/friend_profile_screen.dart';
import 'package:nori/screens/social/post_detail_screen.dart';
import 'package:nori/screens/social/post_proof_screen.dart';
import 'package:nori/screens/social/post_actions_sheet.dart';

class CompetitionDetailScreen extends StatefulWidget {
  const CompetitionDetailScreen({super.key, required this.competitionId});
  final String competitionId;
  @override
  State<CompetitionDetailScreen> createState() =>
      _CompetitionDetailScreenState();
}

class _CompetitionDetailScreenState extends State<CompetitionDetailScreen>
    with
        RemoteLoadState<CompetitionDetailScreen>,
        SocialLoadState<CompetitionDetailScreen> {
  Competition? _competition;
  Map<String, SocialUser> _users = {};
  List<SocialPost> _posts = [];
  int _tab = 0;
  bool _leaving = false;
  @override
  Future<void> loadSocial() async {
    final competitions = await AppData.social.getCompetitions();
    final users = await AppData.social.getUserDirectory();
    final posts = await AppData.social.getPosts();
    if (!mounted) return;
    setState(() {
      _competition = competitions
          .where((c) => c.id == widget.competitionId)
          .firstOrNull;
      _users = users;
      _posts = posts
          .where((p) => p.competitionId == widget.competitionId)
          .toList();
    });
  }

  void _profile(SocialUser user) {
    if (!user.isMe) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => FriendProfileScreen(userId: user.id)),
      );
    }
  }

  Future<void> _leaveMenu() => showNoriSheet<void>(
    context,
    title: 'Competition options',
    builder: (sheetContext) => NoriSheetAction(
      icon: Icons.logout,
      label: 'Leave competition',
      destructive: true,
      onTap: () {
        Navigator.pop(sheetContext);
        _leave();
      },
    ),
  );
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
          'Leave competition?',
          style: AppTextStyles.headlineLgMobile,
        ),
        content: Text(
          'Leave this challenge and return to your competitions?',
          style: AppTextStyles.bodyMd,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    setState(() => _leaving = true);
    final success = await guardedAction(() async {
      await AppData.social.leaveCompetition(widget.competitionId);
    });
    if (!mounted) return;
    setState(() => _leaving = false);
    if (success) {
      showSocialToast(context, 'Competition left');
      Navigator.pop(context);
    }
  }

  String _date(DateTime date) =>
      MaterialLocalizations.of(context).formatMediumDate(date);
  Widget _standing(Competition c, String id, int rank) {
    final user = _users[id];
    if (user == null) return const SizedBox.shrink();
    final progress = c.progress[id] ?? 0;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.stackSm),
      child: Column(
        children: [
          PersonRow(
            user: user,
            highlighted: user.isMe,
            onTap: user.isMe ? null : () => _profile(user),
            subtitle: '#$rank${user.isMe ? ' · You' : ''}',
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (rank == 1) ...[
                  const Icon(
                    Icons.workspace_premium,
                    color: AppColors.mustardDark,
                    size: 20,
                  ),
                  const SizedBox(width: AppSpacing.unit),
                ],
                Text(
                  '$progress / ${c.targetCount}',
                  style: AppTextStyles.labelLg,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.unit),
          ProgressBarPill(
            progress: c.targetCount == 0 ? 0 : progress / c.targetCount,
            semanticLabel:
                '${user.isMe ? 'Your' : "${user.firstName}’s"} progress',
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: buildLoaded((context) {
        final c = _competition;
        return NoriScrollScaffold(
          maxWidth: 800,
          children: [
            NoriScreenHeader(
              leading: NoriScreenHeader.backButton(context),
              title: 'Competition',
              titleStyle: AppTextStyles.headlineLgMobile,
              trailing:
                  c != null && c.status == CompetitionStatus.active && !_leaving
                  ? CircularIconButton(
                      icon: Icons.more_horiz,
                      tooltip: 'Competition options',
                      onPressed: _leaveMenu,
                    )
                  : null,
            ),
            const SizedBox(height: AppSpacing.stackMd),
            if (c == null)
              const NoriEmptyState(
                icon: Icons.emoji_events_outlined,
                title: 'Competition unavailable',
                message: 'This challenge is no longer in your competitions.',
              )
            else ...[
              NoriCard(
                color: c.color,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        NoriIconBadge(
                          icon: c.icon,
                          background: AppColors.white,
                          size: 48,
                          iconSize: 28,
                        ),
                        const SizedBox(width: AppSpacing.stackSm),
                        Expanded(
                          child: Text(
                            c.title,
                            style: AppTextStyles.headlineLgMobile,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.stackSm),
                    GestureDetector(
                      onTap: () {
                        final host = _users[c.hostId];
                        if (host != null) _profile(host);
                      },
                      child: Text(
                        'Hosted by ${_users[c.hostId]?.isMe == true ? 'you' : _users[c.hostId]?.shortName ?? 'a friend'} · ${c.prizeXp} XP prize',
                        style: AppTextStyles.labelLg,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.unit),
                    Text(c.description, style: AppTextStyles.bodyMd),
                    const SizedBox(height: AppSpacing.stackSm),
                    Wrap(
                      spacing: AppSpacing.unit,
                      runSpacing: AppSpacing.unit,
                      children: [
                        NoriChoiceChip(
                          label: c.timeLeftLabel,
                          icon: Icons.timer_outlined,
                          selected: false,
                          onTap: () => setState(() => _tab = 2),
                        ),
                        NoriChoiceChip(
                          label: c.type.label,
                          icon: c.type.icon,
                          selected: false,
                          onTap: () => setState(() => _tab = 2),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.stackSm),
                    Text(
                      'Your progress: ${c.myProgress}/${c.targetCount}',
                      style: AppTextStyles.labelLg,
                    ),
                    const SizedBox(height: AppSpacing.unit),
                    ProgressBarPill(
                      progress: c.myFraction,
                      semanticLabel: 'Your competition progress',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.stackMd),
              NoriSegmentedControl(
                labels: const ['Standings', 'Activity', 'Rules'],
                selectedIndex: _tab,
                onChanged: (i) => setState(() => _tab = i),
              ),
              const SizedBox(height: AppSpacing.stackMd),
              if (_tab == 0) ...[
                if (c.standings.isEmpty)
                  const NoriEmptyState(
                    icon: Icons.people_outline,
                    title: 'No standings yet',
                    message: 'Participants will appear here when they join.',
                  ),
                for (var i = 0; i < c.standings.length; i++)
                  _standing(c, c.standings[i], i + 1),
              ] else if (_tab == 1) ...[
                if (_posts.isEmpty)
                  const NoriEmptyState(
                    icon: Icons.photo_camera_outlined,
                    title: 'No proofs yet',
                    message: 'Competition proofs will appear here.',
                  ),
                for (final post in _posts)
                  if (_users[post.authorId] case final author?) ...[
                    PostCard(
                      post: post,
                      author: author,
                      compact: true,
                      contextLabel: c.title,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PostDetailScreen(postId: post.id),
                        ),
                      ),
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
              ] else ...[
                // Winning and XP rules are placeholders from the mock repository.
                NoriCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'How it works',
                        style: AppTextStyles.headlineLgMobile,
                      ),
                      const SizedBox(height: AppSpacing.stackSm),
                      for (final rule in [
                        c.type.blurb,
                        'Habit: ${c.habitName} · Target: ${c.targetCount}',
                        if (c.proofRequired) 'Proof photo required daily',
                        '${c.prizeXp} XP prize',
                        'Starts ${_date(c.startsAt)}',
                        'Ends ${_date(c.endsAt)}',
                      ])
                        Padding(
                          padding: const EdgeInsets.only(
                            bottom: AppSpacing.unit,
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.check_circle_outline,
                                size: 20,
                                color: AppColors.mossDark,
                              ),
                              const SizedBox(width: AppSpacing.unit),
                              Expanded(
                                child: Text(rule, style: AppTextStyles.bodyMd),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.stackMd),
              if (c.status == CompetitionStatus.past)
                TactileButton(
                  label: 'See results',
                  icon: Icons.emoji_events,
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          CompetitionResultsScreen(competitionId: c.id),
                    ),
                  ),
                )
              else if (c.status == CompetitionStatus.invited)
                TactileButton(
                  label: 'View invitation',
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          CompetitionInviteScreen(competitionId: c.id),
                    ),
                  ),
                )
              else
                TactileButton(
                  label: c.submittedToday
                      ? 'Submitted today'
                      : "Submit today's proof",
                  icon: c.submittedToday ? Icons.check : Icons.add_a_photo,
                  onPressed: c.submittedToday || _leaving
                      ? null
                      : () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                PostProofScreen(competitionId: c.id),
                          ),
                        ),
                ),
            ],
          ],
        );
      }),
    ),
  );
}
