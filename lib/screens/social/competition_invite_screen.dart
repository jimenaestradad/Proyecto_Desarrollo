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
import 'package:nori/models/social_people.dart';
import 'package:nori/widgets/nori_choice_chip.dart';
import 'package:nori/widgets/tactile_button.dart';
import 'package:nori/widgets/xp_pill.dart';
import 'package:nori/screens/social/friend_profile_screen.dart';
import 'package:nori/screens/social/competition_detail_screen.dart';
import 'package:nori/screens/social/competition_results_screen.dart';

class CompetitionInviteScreen extends StatefulWidget {
  const CompetitionInviteScreen({super.key, required this.competitionId});
  final String competitionId;
  @override
  State<CompetitionInviteScreen> createState() =>
      _CompetitionInviteScreenState();
}

class _CompetitionInviteScreenState extends State<CompetitionInviteScreen>
    with
        RemoteLoadState<CompetitionInviteScreen>,
        SocialLoadState<CompetitionInviteScreen> {
  Competition? _competition;
  Map<String, SocialUser> _users = {};
  bool _busy = false;
  @override
  Future<void> loadSocial() async {
    final competitions = await AppData.social.getCompetitions();
    final users = await AppData.social.getUserDirectory();
    if (!mounted) return;
    setState(() {
      _competition = competitions
          .where((c) => c.id == widget.competitionId)
          .firstOrNull;
      _users = users;
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

  Future<void> _respond(bool join) async {
    if (_busy || _competition?.status != CompetitionStatus.invited) return;
    setState(() => _busy = true);
    final success = await guardedAction(() async {
      if (join) {
        await AppData.social.acceptCompetitionInvite(widget.competitionId);
      } else {
        await AppData.social.declineCompetitionInvite(widget.competitionId);
      }
    });
    if (!mounted) return;
    setState(() => _busy = false);
    if (success) {
      showSocialToast(
        context,
        join ? 'Competition joined' : 'Invitation declined',
      );
      if (join) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) =>
                CompetitionDetailScreen(competitionId: widget.competitionId),
          ),
        );
      } else {
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: buildLoaded((context) {
        final c = _competition;
        final host = _users[c?.invitedById ?? c?.hostId];
        final participants = c == null
            ? <SocialUser>[]
            : c.participantIds
                  .map((id) => _users[id])
                  .whereType<SocialUser>()
                  .toList();
        return NoriScrollScaffold(
          maxWidth: 800,
          children: [
            NoriScreenHeader(
              leading: NoriScreenHeader.backButton(context),
              title: 'Invitation',
              titleStyle: AppTextStyles.headlineLgMobile,
            ),
            const SizedBox(height: AppSpacing.stackMd),
            if (c == null)
              const NoriEmptyState(
                icon: Icons.mail_outline,
                title: 'Invitation unavailable',
                message: 'This invitation is no longer available.',
              )
            else ...[
              if (host != null) ...[
                PersonRow(
                  user: host,
                  subtitle: '${host.firstName} invited you',
                  onTap: host.isMe ? null : () => _profile(host),
                ),
                const SizedBox(height: AppSpacing.stackSm),
              ],
              NoriCard(
                color: c.color,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(c.icon, size: 48, color: AppColors.ink),
                    const SizedBox(height: AppSpacing.stackSm),
                    Text(c.title, style: AppTextStyles.headlineLgMobile),
                    const SizedBox(height: AppSpacing.unit),
                    Text(c.description, style: AppTextStyles.bodyMd),
                    const SizedBox(height: AppSpacing.stackSm),
                    Wrap(
                      spacing: AppSpacing.unit,
                      runSpacing: AppSpacing.unit,
                      children: [
                        NoriChoiceChip(
                          label: c.type.label,
                          icon: c.type.icon,
                          selected: false,
                          onTap: () => showSocialToast(context, c.type.blurb),
                        ),
                        NoriChoiceChip(
                          label: c.habitName,
                          icon: c.icon,
                          selected: false,
                          onTap: () => showSocialToast(
                            context,
                            'Target: ${c.targetCount}',
                          ),
                        ),
                        NoriChoiceChip(
                          label: '${c.durationDays} days',
                          icon: Icons.date_range,
                          selected: false,
                          onTap: () => showSocialToast(
                            context,
                            'Ends ${MaterialLocalizations.of(context).formatMediumDate(c.endsAt)}',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.stackMd),
                    Text('Competition prize', style: AppTextStyles.labelLg),
                    const SizedBox(height: AppSpacing.unit),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: XpPill(xp: c.prizeXp),
                    ),
                    const SizedBox(height: AppSpacing.stackSm),
                    Text(
                      'Starts ${MaterialLocalizations.of(context).formatMediumDate(c.startsAt)}',
                      style: AppTextStyles.bodyMd,
                    ),
                  ],
                ),
              ),
              if (c.proofRequired) ...[
                const SizedBox(height: AppSpacing.stackSm),
                NoriCard(
                  color: AppColors.mustardLight,
                  child: Row(
                    children: [
                      const Icon(
                        Icons.photo_camera_outlined,
                        color: AppColors.ink,
                      ),
                      const SizedBox(width: AppSpacing.unit),
                      Expanded(
                        child: Text(
                          'Proof photo required to count',
                          style: AppTextStyles.labelLg,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.stackMd),
              Text(
                'Joining the challenge',
                style: AppTextStyles.headlineLgMobile,
              ),
              const SizedBox(height: AppSpacing.stackSm),
              if (participants.isEmpty)
                const NoriEmptyState(
                  icon: Icons.people_outline,
                  title: 'Be the first to join',
                  message: 'Start the challenge with your host.',
                )
              else ...[
                SizedBox(
                  height: 48,
                  child: Stack(
                    children: [
                      for (var i = 0; i < participants.take(5).length; i++)
                        Positioned(
                          left: i * AppSpacing.stackMd,
                          child: GestureDetector(
                            onTap: participants[i].isMe
                                ? null
                                : () => _profile(participants[i]),
                            child: Semantics(
                              label: participants[i].name,
                              button: !participants[i].isMe,
                              child: SocialAvatar(
                                user: participants[i],
                                size: 44,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.unit),
                Text(
                  participants
                      .map((u) => u.isMe ? 'You' : u.shortName)
                      .join(', '),
                  style: AppTextStyles.bodyMd,
                ),
              ],
              const SizedBox(height: AppSpacing.stackMd),
              if (c.status == CompetitionStatus.invited) ...[
                TactileButton(
                  label: _busy ? 'Please wait...' : 'Join competition',
                  icon: Icons.check,
                  onPressed: _busy ? null : () => _respond(true),
                ),
                const SizedBox(height: AppSpacing.stackSm),
                OutlinedButton(
                  onPressed: _busy ? null : () => _respond(false),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.ink,
                    side: const BorderSide(
                      color: AppColors.ink,
                      width: AppBorder.standard,
                    ),
                    textStyle: AppTextStyles.labelLg,
                    padding: const EdgeInsets.all(AppSpacing.gutter),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.full),
                    ),
                  ),
                  child: const Text('Decline'),
                ),
              ] else
                TactileButton(
                  label: c.status == CompetitionStatus.past
                      ? 'See results'
                      : 'View competition',
                  onPressed: _busy
                      ? null
                      : () => Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (_) => c.status == CompetitionStatus.past
                                ? CompetitionResultsScreen(competitionId: c.id)
                                : CompetitionDetailScreen(competitionId: c.id),
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
