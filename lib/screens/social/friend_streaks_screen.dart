import 'package:flutter/material.dart';
import 'package:nori/data/app_data.dart';
import 'package:nori/models/social_people.dart';
import 'package:nori/screens/social/friend_streak_detail_screen.dart';
import 'package:nori/screens/social/friends_screen.dart';
import 'package:nori/screens/social/social_load_state.dart';
import 'package:nori/screens/social/widgets/social_widgets.dart';
import 'package:nori/theme/app_theme.dart';
import 'package:nori/utils/remote_errors.dart';
import 'package:nori/widgets/nori_card.dart';
import 'package:nori/widgets/nori_empty_state.dart';
import 'package:nori/widgets/nori_screen_header.dart';
import 'package:nori/widgets/nori_scroll_scaffold.dart';
import 'package:nori/widgets/streak_chip.dart';

class FriendStreaksScreen extends StatefulWidget {
  const FriendStreaksScreen({super.key});

  @override
  State<FriendStreaksScreen> createState() => _FriendStreaksScreenState();
}

class _FriendStreaksScreenState extends State<FriendStreaksScreen>
    with
        RemoteLoadState<FriendStreaksScreen>,
        SocialLoadState<FriendStreaksScreen> {
  List<FriendStreak> _streaks = [];
  Map<String, SocialUser> _people = {};
  final Set<String> _nudging = {};
  final Set<String> _nudged = {};

  @override
  Future<void> loadSocial() async {
    final streaks = await AppData.social.getFriendStreaks();
    final people = await AppData.social.getUserDirectory();
    if (!mounted) return;
    setState(() {
      _streaks = streaks.where((s) => people.containsKey(s.friendId)).toList();
      _people = people;
    });
  }

  Future<void> _nudge(SocialUser friend) async {
    if (_nudging.contains(friend.id) || _nudged.contains(friend.id)) return;
    setState(() => _nudging.add(friend.id));
    final success = await guardedAction(() => AppData.social.nudge(friend.id));
    if (!mounted) return;
    setState(() {
      _nudging.remove(friend.id);
      if (success) _nudged.add(friend.id);
    });
    if (success) showSocialToast(context, 'Nudge sent to ${friend.firstName}');
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: buildLoaded(
        (context) => NoriScrollScaffold(
          maxWidth: 800,
          children: [
            NoriScreenHeader(
              leading: NoriScreenHeader.backButton(context),
              title: 'Friend streaks',
              titleStyle: AppTextStyles.headlineLgMobile,
            ),
            const SizedBox(height: AppSpacing.stackMd),
            // Mock rule: both friends complete at least one habit each day.
            Text(
              'You both complete at least one habit a day.',
              style: AppTextStyles.bodyMd,
            ),
            const SizedBox(height: AppSpacing.unit),
            Text(
              'Preview rule for friend streaks.',
              style: AppTextStyles.labelSm,
            ),
            const SizedBox(height: AppSpacing.stackMd),
            if (_streaks.isEmpty)
              NoriEmptyState(
                icon: Icons.local_fire_department_outlined,
                title: 'No friend streaks yet',
                message: 'Build daily habits together with a friend.',
                actionLabel: 'Find friends',
                onAction: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => const FriendsScreen(),
                  ),
                ),
              )
            else
              for (final streak in _streaks) ...[
                _FriendStreakCard(
                  streak: streak,
                  friend: _people[streak.friendId]!,
                  nudging: _nudging.contains(streak.friendId),
                  nudged: _nudged.contains(streak.friendId),
                  onNudge: () => _nudge(_people[streak.friendId]!),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          FriendStreakDetailScreen(friendId: streak.friendId),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.stackSm),
              ],
          ],
        ),
      ),
    ),
  );
}

class _FriendStreakCard extends StatelessWidget {
  const _FriendStreakCard({
    required this.streak,
    required this.friend,
    required this.nudging,
    required this.nudged,
    required this.onNudge,
    required this.onTap,
  });
  final FriendStreak streak;
  final SocialUser friend;
  final bool nudging;
  final bool nudged;
  final VoidCallback onNudge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final atRisk = streak.days.isNotEmpty && streak.atRisk;
    return Semantics(
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: NoriCard(
          padding: const EdgeInsets.all(AppSpacing.gutter),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  SocialAvatar(user: friend, size: 44),
                  const SizedBox(width: AppSpacing.stackSm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(friend.shortName, style: AppTextStyles.labelLg),
                        Text(
                          'Best ${streak.best}',
                          style: AppTextStyles.labelSm,
                        ),
                      ],
                    ),
                  ),
                  StreakChip(streak: streak.current),
                  const SizedBox(width: AppSpacing.unit),
                  const Icon(Icons.chevron_right, color: AppColors.ink),
                ],
              ),
              if (atRisk) ...[
                const SizedBox(height: AppSpacing.stackSm),
                Row(
                  children: [
                    NoriCard(
                      color: AppColors.terracotta,
                      radius: AppRadius.full,
                      borderWidth: AppBorder.thin,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.stackSm,
                        vertical: AppSpacing.unit,
                      ),
                      child: Text(
                        'At risk',
                        style: AppTextStyles.labelSm.copyWith(
                          color: AppColors.ink,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.unit),
                    Expanded(
                      child: Text(
                        'Needs a habit before midnight',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.labelSm,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: nudging || nudged ? null : onNudge,
                      icon: const Icon(Icons.notifications_active_outlined),
                      label: Text(
                        nudging
                            ? 'Sending...'
                            : nudged
                            ? 'Nudged'
                            : 'Nudge',
                        style: AppTextStyles.labelLg,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
