import 'package:flutter/material.dart';
import 'package:nori/data/app_data.dart';
import 'package:nori/utils/formatting.dart';
import 'package:nori/theme/app_theme.dart';
import 'package:nori/utils/remote_errors.dart';
import 'package:nori/screens/social/social_load_state.dart';
import 'package:nori/screens/social/widgets/social_widgets.dart';
import 'package:nori/widgets/nori_card.dart';
import 'package:nori/widgets/nori_screen_header.dart';
import 'package:nori/widgets/nori_scroll_scaffold.dart';
import 'package:nori/widgets/nori_empty_state.dart';
import 'package:nori/models/competition.dart';
import 'package:nori/models/social_people.dart';
import 'package:nori/widgets/circular_icon_button.dart';
import 'package:nori/widgets/nori_choice_chip.dart';
import 'package:nori/widgets/nori_segmented_control.dart';
import 'package:nori/widgets/progress_bar_pill.dart';
import 'package:nori/widgets/tactile_button.dart';
import 'package:nori/screens/social/create_competition_screen.dart';
import 'package:nori/screens/social/competition_detail_screen.dart';
import 'package:nori/screens/social/competition_invite_screen.dart';
import 'package:nori/screens/social/competition_results_screen.dart';

class CompetitionsScreen extends StatefulWidget {
  const CompetitionsScreen({super.key, this.initialTab = 0});
  final int initialTab;
  @override
  State<CompetitionsScreen> createState() => _CompetitionsScreenState();
}

class _CompetitionsScreenState extends State<CompetitionsScreen>
    with
        RemoteLoadState<CompetitionsScreen>,
        SocialLoadState<CompetitionsScreen> {
  late int _tab = widget.initialTab.clamp(0, 2);
  List<Competition> _competitions = [];
  Map<String, SocialUser> _users = {};
  final Set<String> _busy = {};
  @override
  Future<void> loadSocial() async {
    final competitions = await AppData.social.getCompetitions();
    final users = await AppData.social.getUserDirectory();
    if (!mounted) return;
    setState(() {
      _competitions = competitions;
      _users = users;
    });
  }

  void _create() => Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const CreateCompetitionScreen()),
  );
  void _open(Competition c) => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => switch (c.status) {
        CompetitionStatus.active => CompetitionDetailScreen(
          competitionId: c.id,
        ),
        CompetitionStatus.invited => CompetitionInviteScreen(
          competitionId: c.id,
        ),
        CompetitionStatus.past => CompetitionResultsScreen(competitionId: c.id),
      },
    ),
  );
  Future<void> _respond(Competition c, bool join) async {
    if (_busy.contains(c.id)) return;
    setState(() => _busy.add(c.id));
    final success = await guardedAction(() async {
      if (join) {
        await AppData.social.acceptCompetitionInvite(c.id);
      } else {
        await AppData.social.declineCompetitionInvite(c.id);
      }
    });
    if (!mounted) return;
    setState(() => _busy.remove(c.id));
    if (success) {
      showSocialToast(
        context,
        join ? 'Competition joined' : 'Invitation declined',
      );
      if (join) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CompetitionDetailScreen(competitionId: c.id),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: buildLoaded((context) {
        final status = CompetitionStatus.values[_tab];
        final shown = _competitions.where((c) => c.status == status).toList();
        return NoriScrollScaffold(
          maxWidth: 800,
          children: [
            NoriScreenHeader(
              leading: NoriScreenHeader.backButton(context),
              title: 'Competitions',
              titleStyle: AppTextStyles.headlineLgMobile,
              trailing: CircularIconButton(
                icon: Icons.add,
                tooltip: 'Create competition',
                onPressed: _create,
              ),
            ),
            const SizedBox(height: AppSpacing.stackMd),
            NoriSegmentedControl(
              labels: [
                'Active (${_competitions.where((c) => c.status == CompetitionStatus.active).length})',
                'Invites (${_competitions.where((c) => c.status == CompetitionStatus.invited).length})',
                'Past',
              ],
              selectedIndex: _tab,
              onChanged: (i) => setState(() => _tab = i),
            ),
            const SizedBox(height: AppSpacing.stackMd),
            if (shown.isEmpty)
              NoriEmptyState(
                icon: Icons.emoji_events_outlined,
                title: [
                  'No active competitions',
                  'No invitations yet',
                  'No past competitions',
                ][_tab],
                message: [
                  'Start a habit challenge with your friends.',
                  'Your competition invitations will appear here.',
                  'Finished challenges will appear here.',
                ][_tab],
                actionLabel: 'Start a competition',
                onAction: _create,
              ),
            for (final c in shown) ...[
              _CompetitionCard(
                competition: c,
                users: _users,
                busy: _busy.contains(c.id),
                onTap: () => _open(c),
                onJoin: () => _respond(c, true),
                onDecline: () => _respond(c, false),
              ),
              const SizedBox(height: AppSpacing.stackSm),
            ],
          ],
        );
      }),
    ),
  );
}

class _CompetitionCard extends StatelessWidget {
  const _CompetitionCard({
    required this.competition,
    required this.users,
    required this.busy,
    required this.onTap,
    required this.onJoin,
    required this.onDecline,
  });
  final Competition competition;
  final Map<String, SocialUser> users;
  final bool busy;
  final VoidCallback onTap, onJoin, onDecline;
  @override
  Widget build(BuildContext context) {
    final c = competition;
    final leader = c.standings.firstOrNull;
    final place = c.standings.indexOf('me') + 1;
    return Semantics(
      button: true,
      label: c.title,
      child: GestureDetector(
        onTap: onTap,
        child: NoriCard(
          color: c.color,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: AppSpacing.unit,
                runSpacing: AppSpacing.unit,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  NoriChoiceChip(
                    label: c.timeLeftLabel,
                    icon: Icons.timer_outlined,
                    selected: false,
                    onTap: onTap,
                  ),
                  Text(
                    '${c.participantIds.length} participants',
                    style: AppTextStyles.labelSm,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.stackSm),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (c.coverAsset != null) ...[
                    CoverBadge(
                      icon: c.icon,
                      background: AppColors.white,
                      size: 56,
                      iconSize: 28,
                      asset: c.coverAsset,
                    ),
                    const SizedBox(width: AppSpacing.stackSm),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(c.title, style: AppTextStyles.headlineLgMobile),
                        Text(c.description, style: AppTextStyles.bodyMd),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.stackSm),
              Text(
                '${c.myProgress}/${c.targetCount} · ${(c.myFraction * 100).floor()}%',
                style: AppTextStyles.labelLg,
              ),
              const SizedBox(height: AppSpacing.unit),
              ProgressBarPill(
                progress: c.myFraction,
                semanticLabel: 'Your progress',
              ),
              const SizedBox(height: AppSpacing.stackSm),
              if (leader != null)
                Text(
                  'Leader: ${users[leader]?.isMe == true ? 'You' : users[leader]?.shortName ?? 'Participant'} (${c.progress[leader] ?? 0}/${c.targetCount})',
                  style: AppTextStyles.labelLg,
                ),
              if (c.proofRequired) ...[
                const SizedBox(height: AppSpacing.unit),
                Align(
                  alignment: Alignment.centerLeft,
                  child: NoriChoiceChip(
                    label: 'Proof required',
                    icon: Icons.photo_camera_outlined,
                    selected: false,
                    onTap: onTap,
                  ),
                ),
              ],
              if (c.status == CompetitionStatus.invited) ...[
                const SizedBox(height: AppSpacing.stackSm),
                Text(
                  'Invited by ${users[c.invitedById ?? c.hostId]?.firstName ?? 'a friend'}',
                  style: AppTextStyles.labelLg,
                ),
                const SizedBox(height: AppSpacing.stackSm),
                TactileButton(
                  label: busy ? 'Please wait...' : 'Join competition',
                  onPressed: busy ? null : onJoin,
                ),
                TextButton(
                  onPressed: busy ? null : onDecline,
                  child: const Text('Decline'),
                ),
              ] else if (c.status == CompetitionStatus.past) ...[
                const SizedBox(height: AppSpacing.stackSm),
                Row(
                  children: [
                    const Icon(
                      Icons.emoji_events,
                      color: AppColors.mustardDark,
                    ),
                    const SizedBox(width: AppSpacing.unit),
                    Expanded(
                      child: Text(
                        place == 1
                            ? 'You won'
                            : place > 0
                            ? 'You finished ${ordinal(place)}'
                            : 'Final results',
                        style: AppTextStyles.labelLg,
                      ),
                    ),
                  ],
                ),
              ],
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: onTap,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        c.status == CompetitionStatus.past
                            ? 'View results'
                            : 'View standings',
                      ),
                      const SizedBox(width: AppSpacing.unit),
                      const Icon(Icons.arrow_forward, size: 16),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
