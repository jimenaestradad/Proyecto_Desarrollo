import 'package:flutter/material.dart';
import 'package:nori/theme/app_theme.dart';
import 'package:nori/widgets/future_feature_banner.dart';
import 'package:nori/widgets/nori_avatar.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  static const _rankings = [
    _RankingEntry(rank: 4, name: 'You', level: 18, xp: '1,250'),
    _RankingEntry(rank: 5, name: 'HabitPal', level: 17, xp: '1,180'),
    _RankingEntry(rank: 6, name: 'GoalBuddy', level: 15, xp: '950'),
    _RankingEntry(rank: 7, name: 'StreakMate', level: 14, xp: '890'),
  ];

  int _selectedView = 1;

  void _showUnavailable() {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Not available yet')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.linen,
      appBar: AppBar(title: const Text('Leagues')),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final horizontalPadding = constraints.maxWidth >= 800
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
                constraints: const BoxConstraints(maxWidth: 760),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Compete with friends and habit builders worldwide.',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.bodyMd.copyWith(
                        color: AppColors.inkMuted,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.stackSm),
                    const FutureFeatureBanner(),
                    const SizedBox(height: AppSpacing.stackMd),
                    Align(
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: AppColors.linenAlt,
                          borderRadius: BorderRadius.circular(AppRadius.full),
                          border: Border.all(
                            color: AppColors.ink,
                            width: AppBorder.thin,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _ViewChoice(
                              label: 'Global',
                              selected: _selectedView == 0,
                              onTap: () => setState(() => _selectedView = 0),
                            ),
                            _ViewChoice(
                              label: 'Friends',
                              selected: _selectedView == 1,
                              onTap: () => setState(() => _selectedView = 1),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.stackMd),
                    const _Podium(),
                    const SizedBox(height: AppSpacing.stackLg),
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.gutter),
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        border: Border.all(
                          color: AppColors.ink,
                          width: AppBorder.standard,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.unit,
                            ),
                            child: Text(
                              'Friends Ranking',
                              style: AppTextStyles.headlineMd,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.stackSm),
                          for (
                            var index = 0;
                            index < _rankings.length;
                            index++
                          ) ...[
                            _RankingRow(
                              entry: _rankings[index],
                              highlighted: index == 0,
                            ),
                            if (index < _rankings.length - 1)
                              const SizedBox(height: AppSpacing.unit),
                          ],
                          const SizedBox(height: AppSpacing.unit),
                          TextButton(
                            onPressed: _showUnavailable,
                            child: const Text('Load More Friends'),
                          ),
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
    );
  }
}

class _ViewChoice extends StatelessWidget {
  const _ViewChoice({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.mossLight : Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.full),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.full),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
          child: Text(
            label,
            style: AppTextStyles.labelLg.copyWith(
              color: selected ? AppColors.mossDark : AppColors.inkMuted,
            ),
          ),
        ),
      ),
    );
  }
}

class _Podium extends StatelessWidget {
  const _Podium();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 260,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: _PodiumEntry(
              rank: 2,
              name: 'AlexH',
              level: 24,
              avatarSize: 64,
              podiumHeight: 98,
              podiumColor: AppColors.linenAlt,
            ),
          ),
          SizedBox(width: AppSpacing.unit),
          Expanded(
            child: _PodiumEntry(
              rank: 1,
              name: 'SarahJ',
              level: 28,
              avatarSize: 78,
              podiumHeight: 134,
              podiumColor: AppColors.mustard,
              xp: '15.4k XP',
            ),
          ),
          SizedBox(width: AppSpacing.unit),
          Expanded(
            child: _PodiumEntry(
              rank: 3,
              name: 'MikeD',
              level: 21,
              avatarSize: 58,
              podiumHeight: 78,
              podiumColor: Color(0xFFDB995C),
            ),
          ),
        ],
      ),
    );
  }
}

class _PodiumEntry extends StatelessWidget {
  const _PodiumEntry({
    required this.rank,
    required this.name,
    required this.level,
    required this.avatarSize,
    required this.podiumHeight,
    required this.podiumColor,
    this.xp,
  });

  final int rank;
  final String name;
  final int level;
  final double avatarSize;
  final double podiumHeight;
  final Color podiumColor;
  final String? xp;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            NoriAvatar(size: avatarSize, borderWidth: rank == 1 ? 4 : 2),
            Positioned(
              top: -10,
              right: -6,
              child: Icon(
                Icons.military_tech,
                color: rank == 1
                    ? AppColors.mustardDark
                    : rank == 2
                    ? AppColors.ink
                    : const Color(0xFF9A5B32),
                size: rank == 1 ? 28 : 22,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.unit),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
          decoration: BoxDecoration(
            color: rank == 1
                ? AppColors.mustardLight
                : AppColors.white,
            borderRadius: BorderRadius.circular(AppRadius.full),
            border: Border.all(color: AppColors.ink, width: AppBorder.thin),
          ),
          child: Text('Lvl $level', style: AppTextStyles.labelSm),
        ),
        const SizedBox(height: AppSpacing.unit),
        Container(
          height: podiumHeight,
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(6, 10, 6, 6),
          decoration: BoxDecoration(
            color: podiumColor,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppRadius.sm),
            ),
            border: Border.all(color: AppColors.ink, width: AppBorder.standard),
          ),
          child: Column(
            children: [
              Text(
                '$rank',
                style: AppTextStyles.headlineMd.copyWith(
                  color: AppColors.ink,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.labelLg.copyWith(
                  color: AppColors.ink,
                ),
              ),
              if (xp != null)
                Text(
                  xp!,
                  style: AppTextStyles.labelSm.copyWith(
                    color: AppColors.inkMuted,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RankingRow extends StatelessWidget {
  const _RankingRow({required this.entry, required this.highlighted});

  final _RankingEntry entry;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    const foreground = AppColors.ink;
    final secondaryForeground = highlighted
        ? AppColors.mossDark
        : AppColors.inkMuted;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.stackSm),
      decoration: BoxDecoration(
        color: highlighted ? AppColors.mossLight : AppColors.linenAlt,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AppColors.ink, width: AppBorder.thin),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text(
              '${entry.rank}',
              textAlign: TextAlign.center,
              style: AppTextStyles.labelLg.copyWith(color: foreground),
            ),
          ),
          const SizedBox(width: AppSpacing.stackSm),
          const NoriAvatar(size: 46),
          const SizedBox(width: AppSpacing.stackSm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.labelLg.copyWith(color: foreground),
                ),
                Text(
                  'Level ${entry.level}',
                  style: AppTextStyles.labelSm.copyWith(
                    color: secondaryForeground,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.unit),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                entry.xp,
                style: AppTextStyles.labelLg.copyWith(color: foreground),
              ),
              Text(
                'XP',
                style: AppTextStyles.labelSm.copyWith(
                  color: secondaryForeground,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RankingEntry {
  const _RankingEntry({
    required this.rank,
    required this.name,
    required this.level,
    required this.xp,
  });

  final int rank;
  final String name;
  final int level;
  final String xp;
}
