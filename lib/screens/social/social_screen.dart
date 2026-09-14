import 'package:flutter/material.dart';
import 'package:nori/data/app_data.dart';
import 'package:nori/models/nori_user.dart';
import 'package:nori/theme/app_theme.dart';
import 'package:nori/widgets/future_feature_banner.dart';
import 'package:nori/widgets/nori_avatar.dart';
import 'package:nori/widgets/nori_screen_header.dart';
import 'package:nori/widgets/progress_bar_pill.dart';
import 'package:nori/widgets/section_header.dart';
import 'package:nori/widgets/xp_pill.dart';

/// Replaces the old Achievements nav tab (achievements moved under Profile
/// — see [AchievementsScreen]). Vision-only per docs/FEATURES.md §10: not
/// MVP scope, so this is a design mock, not a wired feature — every action
/// shows "Coming soon" instead of doing anything real, same pattern as
/// [ProfileScreen]'s Explore card.
class SocialScreen extends StatefulWidget {
  const SocialScreen({super.key});

  @override
  State<SocialScreen> createState() => _SocialScreenState();
}

class _SocialScreenState extends State<SocialScreen> {
  NoriUser? _user;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final user = await AppData.user.getCurrentUser();
    if (!mounted) return;
    setState(() => _user = user);
  }

  void _showComingSoon() {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Coming soon')));
  }

  @override
  Widget build(BuildContext context) {
    final user = _user;

    return Scaffold(
      body: SafeArea(
        child: user == null
            ? const Center(child: CircularProgressIndicator())
            : LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth >= 800;
                  final horizontalPadding = isWide
                      ? AppSpacing.containerPaddingDesktop
                      : AppSpacing.containerPaddingMobile;

                  return SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      horizontalPadding,
                      AppSpacing.gutter,
                      horizontalPadding,
                      AppSpacing.stackLg,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 900),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            NoriScreenHeader(
                              leading: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  NoriAvatar(imageUrl: user.avatarUrl),
                                  const SizedBox(width: AppSpacing.stackSm),
                                ],
                              ),
                              title: 'Social',
                              titleStyle: AppTextStyles.headlineMd,
                              trailing: XpPill(xp: user.totalXp),
                            ),
                            const SizedBox(height: AppSpacing.stackMd),
                            const FutureFeatureBanner(
                              message:
                                  "Preview only — friends, feeds & competitions aren't built yet.",
                            ),
                            const SizedBox(height: AppSpacing.stackLg),
                            SectionHeader(
                              icon: Icons.dynamic_feed,
                              title: 'Activity Feed',
                              trailing: TextButton(
                                onPressed: _showComingSoon,
                                style: TextButton.styleFrom(foregroundColor: AppColors.mossDark),
                                child: const Text('Post proof'),
                              ),
                            ),
                            const SizedBox(height: AppSpacing.stackSm),
                            const _FeedCard(
                              name: 'Jimena',
                              habit: 'Gym Session',
                              timeAgo: '12m ago',
                              caption: 'Upper body day, done 💪 (proof photo)',
                              reactions: 4,
                            ),
                            const SizedBox(height: AppSpacing.stackSm),
                            const _FeedCard(
                              name: 'AlexH',
                              habit: 'Read 10 mins',
                              timeAgo: '1h ago',
                              caption: 'Finished another chapter of Atomic Habits.',
                              reactions: 2,
                            ),
                            const SizedBox(height: AppSpacing.stackLg),
                            SectionHeader(
                              icon: Icons.leaderboard,
                              title: 'Leaderboard',
                              trailing: TextButton(
                                onPressed: _showComingSoon,
                                style: TextButton.styleFrom(foregroundColor: AppColors.mossDark),
                                child: const Text('View all'),
                              ),
                            ),
                            const SizedBox(height: AppSpacing.stackSm),
                            const _LeaderboardPreview(),
                            const SizedBox(height: AppSpacing.stackLg),
                            SectionHeader(
                              icon: Icons.emoji_events,
                              title: 'Active Competitions',
                              trailing: TextButton(
                                onPressed: _showComingSoon,
                                style: TextButton.styleFrom(foregroundColor: AppColors.mossDark),
                                child: const Text('Start one'),
                              ),
                            ),
                            const SizedBox(height: AppSpacing.stackSm),
                            const _CompetitionCard(
                              title: '7-Day Water Streak',
                              participants: 6,
                              progress: 0.6,
                              daysLeft: 3,
                              color: AppColors.sky,
                            ),
                            const SizedBox(height: AppSpacing.stackSm),
                            const _CompetitionCard(
                              title: 'No Social Media Weekend',
                              participants: 3,
                              progress: 0.3,
                              daysLeft: 2,
                              color: AppColors.blushPink,
                            ),
                            const SizedBox(height: AppSpacing.stackLg),
                            SectionHeader(
                              icon: Icons.groups,
                              title: 'My Circles',
                              trailing: TextButton(
                                onPressed: _showComingSoon,
                                style: TextButton.styleFrom(foregroundColor: AppColors.mossDark),
                                child: const Text('New circle'),
                              ),
                            ),
                            const SizedBox(height: AppSpacing.stackSm),
                            SizedBox(
                              height: 104,
                              child: ListView(
                                scrollDirection: Axis.horizontal,
                                children: [
                                  _CircleChip(
                                    label: 'Roommates',
                                    memberCount: 3,
                                    color: AppColors.mossLight,
                                    onTap: _showComingSoon,
                                  ),
                                  const SizedBox(width: AppSpacing.stackSm),
                                  _CircleChip(
                                    label: 'Gym Buddies',
                                    memberCount: 5,
                                    color: AppColors.mustardLight,
                                    onTap: _showComingSoon,
                                  ),
                                  const SizedBox(width: AppSpacing.stackSm),
                                  _NewCircleChip(onTap: _showComingSoon),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}

class _FeedCard extends StatelessWidget {
  const _FeedCard({
    required this.name,
    required this.habit,
    required this.timeAgo,
    required this.caption,
    required this.reactions,
  });

  final String name;
  final String habit;
  final String timeAgo;
  final String caption;
  final int reactions;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.stackSm),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AppColors.ink, width: AppBorder.thin),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const NoriAvatar(size: 36),
              const SizedBox(width: AppSpacing.unit),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: AppTextStyles.labelLg.copyWith(fontWeight: FontWeight.w700)),
                    Text(
                      '$habit · $timeAgo',
                      style: AppTextStyles.labelSm.copyWith(color: AppColors.inkFaint),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.verified, size: 16, color: AppColors.mossDark),
            ],
          ),
          const SizedBox(height: AppSpacing.unit),
          Text(caption, style: AppTextStyles.bodyMd),
          const SizedBox(height: AppSpacing.unit),
          Row(
            children: [
              const Icon(Icons.favorite_border, size: 16, color: AppColors.inkFaint),
              const SizedBox(width: 4),
              Text('$reactions', style: AppTextStyles.labelSm.copyWith(color: AppColors.inkFaint)),
              const SizedBox(width: AppSpacing.stackSm),
              const Icon(Icons.chat_bubble_outline, size: 16, color: AppColors.inkFaint),
            ],
          ),
        ],
      ),
    );
  }
}

class _LeaderboardPreview extends StatelessWidget {
  const _LeaderboardPreview();

  static const _rows = [
    (rank: 1, name: 'SarahJ', xp: '15.4k', highlighted: false),
    (rank: 2, name: 'You', xp: '15.4k', highlighted: true),
    (rank: 3, name: 'MikeD', xp: '12.1k', highlighted: false),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.stackSm),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AppColors.ink, width: AppBorder.thin),
      ),
      child: Column(
        children: [
          for (final row in _rows) ...[
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.unit,
                vertical: AppSpacing.unit,
              ),
              decoration: BoxDecoration(
                color: row.highlighted ? AppColors.mossLight : Colors.transparent,
                borderRadius: BorderRadius.circular(AppRadius.sm * 0.6),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 22,
                    child: Text(
                      '${row.rank}',
                      style: AppTextStyles.labelLg.copyWith(color: AppColors.ink),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.unit),
                  const NoriAvatar(size: 32),
                  const SizedBox(width: AppSpacing.unit),
                  Expanded(child: Text(row.name, style: AppTextStyles.labelLg)),
                  Text('${row.xp} XP', style: AppTextStyles.labelSm.copyWith(color: AppColors.inkMuted)),
                ],
              ),
            ),
            if (row != _rows.last) const SizedBox(height: 4),
          ],
        ],
      ),
    );
  }
}

class _CompetitionCard extends StatelessWidget {
  const _CompetitionCard({
    required this.title,
    required this.participants,
    required this.progress,
    required this.daysLeft,
    required this.color,
  });

  final String title;
  final int participants;
  final double progress;
  final int daysLeft;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.stackSm),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AppColors.ink, width: AppBorder.thin),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(title, style: AppTextStyles.labelLg.copyWith(fontWeight: FontWeight.w700)),
              ),
              Text(
                '$daysLeft d left',
                style: AppTextStyles.labelSm.copyWith(color: AppColors.inkMuted),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '$participants friends competing',
            style: AppTextStyles.labelSm.copyWith(color: AppColors.inkMuted),
          ),
          const SizedBox(height: AppSpacing.unit),
          ProgressBarPill(progress: progress, color: AppColors.mossDark),
        ],
      ),
    );
  }
}

class _CircleChip extends StatelessWidget {
  const _CircleChip({
    required this.label,
    required this.memberCount,
    required this.color,
    required this.onTap,
  });

  final String label;
  final int memberCount;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Container(
        width: 96,
        padding: const EdgeInsets.all(AppSpacing.unit),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(color: AppColors.ink, width: AppBorder.thin),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.groups, color: AppColors.ink),
            const SizedBox(height: 6),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: AppTextStyles.labelSm.copyWith(fontWeight: FontWeight.w700),
            ),
            Text(
              '$memberCount friends',
              style: AppTextStyles.labelSm.copyWith(color: AppColors.inkMuted, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }
}

class _NewCircleChip extends StatelessWidget {
  const _NewCircleChip({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Container(
        width: 96,
        decoration: BoxDecoration(
          color: AppColors.linenAlt,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(color: AppColors.inkFaint, width: AppBorder.thin),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.add, color: AppColors.inkFaint),
            const SizedBox(height: 6),
            Text('New Circle', style: AppTextStyles.labelSm, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
