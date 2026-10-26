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
import 'package:nori/widgets/reward_pill.dart';
import 'package:nori/widgets/tactile_button.dart';
import 'package:nori/screens/social/create_competition_screen.dart';
import 'package:nori/screens/social/friend_profile_screen.dart';

class CompetitionResultsScreen extends StatefulWidget {
  const CompetitionResultsScreen({super.key, required this.competitionId});
  final String competitionId;
  @override
  State<CompetitionResultsScreen> createState() =>
      _CompetitionResultsScreenState();
}

class _CompetitionResultsScreenState extends State<CompetitionResultsScreen>
    with
        RemoteLoadState<CompetitionResultsScreen>,
        SocialLoadState<CompetitionResultsScreen> {
  Competition? _competition;
  Map<String, SocialUser> _users = {};
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

  void _rematch() => Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const CreateCompetitionScreen()),
  );
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: buildLoaded((context) {
        final c = _competition;
        final standings = c?.standings ?? <String>[];
        final winnerId = standings.firstOrNull;
        final winner = _users[winnerId];
        final placement = standings.indexOf('me') + 1;
        // Mock reward rule: winner gets the prize, runner-up gets half; coins
        // are half the XP.
        final reward = c == null
            ? 0
            : placement == 1
            ? c.prizeXp
            : placement == 2
            ? (c.prizeXp * .5).round()
            : 0;
        return NoriScrollScaffold(
          maxWidth: 800,
          children: [
            NoriScreenHeader(
              leading: NoriScreenHeader.backButton(context),
              title: 'Results',
              titleStyle: AppTextStyles.headlineLgMobile,
            ),
            const SizedBox(height: AppSpacing.stackMd),
            if (c == null)
              const NoriEmptyState(
                icon: Icons.emoji_events_outlined,
                title: 'Results unavailable',
                message: 'This competition is no longer available.',
              )
            else if (standings.isEmpty)
              NoriEmptyState(
                icon: Icons.emoji_events_outlined,
                title: 'No results yet',
                message: 'Start another challenge with your friends.',
                actionLabel: 'Rematch',
                onAction: _rematch,
              )
            else ...[
              NoriCard(
                color: AppColors.mustardLight,
                borderWidth: AppBorder.thick,
                child: Column(
                  children: [
                    const Icon(
                      Icons.emoji_events,
                      size: 64,
                      color: AppColors.mustardDark,
                    ),
                    const SizedBox(height: AppSpacing.stackSm),
                    Text(
                      c.title,
                      style: AppTextStyles.headlineLgMobile,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.stackMd),
                    if (winner != null)
                      GestureDetector(
                        onTap: winner.isMe ? null : () => _profile(winner),
                        child: Column(
                          children: [
                            SocialAvatar(user: winner, size: 72),
                            const SizedBox(height: AppSpacing.stackSm),
                            Text(
                              winner.isMe ? 'You won!' : winner.name,
                              style: AppTextStyles.headlineLgMobile,
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      )
                    else
                      Text(
                        'Competition winner',
                        style: AppTextStyles.headlineLgMobile,
                      ),
                    const SizedBox(height: AppSpacing.unit),
                    Text(
                      'Won with ${c.progress[winnerId] ?? 0}/${c.targetCount}',
                      style: AppTextStyles.labelLg,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.stackMd),
              Text(
                placement == 0
                    ? 'You did not participate in this competition.'
                    : 'You finished ${_ordinal(placement)} — +$reward XP',
                style: AppTextStyles.headlineLgMobile,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.stackMd),
              Text('Final standings', style: AppTextStyles.headlineLgMobile),
              const SizedBox(height: AppSpacing.stackSm),
              for (var i = 0; i < standings.length; i++)
                if (_users[standings[i]] case final user?) ...[
                  PersonRow(
                    user: user,
                    avatarSize: 36,
                    highlighted: user.isMe,
                    subtitle: '#${i + 1}${user.isMe ? ' · You' : ''}',
                    onTap: user.isMe ? null : () => _profile(user),
                    trailing: Text(
                      '${c.progress[user.id] ?? 0}/${c.targetCount}',
                      style: AppTextStyles.labelLg,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.stackSm),
                ],
              const SizedBox(height: AppSpacing.stackSm),
              NoriCard(
                child: Row(
                  children: [
                    Expanded(
                      child: Text('Your reward', style: AppTextStyles.labelLg),
                    ),
                    RewardPill(xp: reward, coins: reward ~/ 2),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.stackMd),
              TactileButton(
                label: 'Rematch',
                icon: Icons.replay,
                onPressed: _rematch,
              ),
            ],
          ],
        );
      }),
    ),
  );
}

String _ordinal(int n) {
  if (n % 100 >= 11 && n % 100 <= 13) return '${n}th';
  return '$n${switch (n % 10) {
    1 => 'st',
    2 => 'nd',
    3 => 'rd',
    _ => 'th',
  }}';
}
