import 'package:flutter/material.dart';
import 'package:nori/data/app_data.dart';
import 'package:nori/models/achievement.dart';
import 'package:nori/models/nori_user.dart';
import 'package:nori/theme/app_theme.dart';
import 'package:nori/widgets/nori_avatar.dart';
import 'package:nori/widgets/progress_bar_pill.dart';
import 'package:nori/widgets/xp_pill.dart';

class AchievementsScreen extends StatefulWidget {
  const AchievementsScreen({super.key});

  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen> {
  NoriUser? _user;
  Map<String, List<Achievement>>? _achievementsByCategory;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final user = await AppData.user.getCurrentUser();
    final achievements = await AppData.achievements.getAchievementsByCategory();
    if (!mounted) return;
    setState(() {
      _user = user;
      _achievementsByCategory = achievements;
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = _user;
    final achievementsByCategory = _achievementsByCategory;

    return Scaffold(
      body: SafeArea(
        child: user == null || achievementsByCategory == null
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
                        constraints: const BoxConstraints(maxWidth: 1200),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _AchievementsHeader(user: user),
                            const SizedBox(height: AppSpacing.stackLg),
                            Text(
                              'Your Trophies',
                              textAlign: isWide
                                  ? TextAlign.center
                                  : TextAlign.start,
                              style: isWide
                                  ? AppTextStyles.headlineLg
                                  : AppTextStyles.headlineLgMobile,
                            ),
                            const SizedBox(height: AppSpacing.stackSm),
                            Text(
                              'Track your progress and show off your consistency. Every habit brings you closer to your next milestone.',
                              textAlign: isWide
                                  ? TextAlign.center
                                  : TextAlign.start,
                              style: AppTextStyles.bodyLg.copyWith(
                                color: AppColors.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.stackLg),
                            for (final entry
                                in achievementsByCategory.entries) ...[
                              _AchievementCategory(
                                category: entry.key,
                                achievements: entry.value,
                                isWide: isWide,
                              ),
                              if (entry.key != achievementsByCategory.keys.last)
                                const SizedBox(height: AppSpacing.stackLg),
                            ],
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

class _AchievementsHeader extends StatelessWidget {
  const _AchievementsHeader({required this.user});

  final NoriUser user;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        NoriAvatar(imageUrl: user.avatarUrl),
        const SizedBox(width: AppSpacing.stackSm),
        Expanded(
          child: Text(
            'Nori',
            style: AppTextStyles.headlineMd.copyWith(color: AppColors.primary),
          ),
        ),
        XpPill(xp: user.totalXp),
      ],
    );
  }
}

class _AchievementCategory extends StatelessWidget {
  const _AchievementCategory({
    required this.category,
    required this.achievements,
    required this.isWide,
  });

  final String category;
  final List<Achievement> achievements;
  final bool isWide;

  IconData get _categoryIcon => switch (category) {
    'Consistency' => Icons.bolt,
    'Health' => Icons.favorite,
    _ => Icons.emoji_events,
  };

  Color get _categoryColor => switch (category) {
    'Health' => AppColors.secondary,
    _ => AppColors.primary,
  };

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(_categoryIcon, color: _categoryColor),
            const SizedBox(width: AppSpacing.unit),
            Text(category, style: AppTextStyles.headlineMd),
          ],
        ),
        const SizedBox(height: AppSpacing.stackSm),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: isWide ? 4 : 2,
          crossAxisSpacing: AppSpacing.gutter,
          mainAxisSpacing: AppSpacing.gutter,
          childAspectRatio: isWide ? 0.95 : 0.6,
          children: [
            for (final achievement in achievements)
              _AchievementCard(achievement: achievement),
          ],
        ),
      ],
    );
  }
}

class _AchievementCard extends StatelessWidget {
  const _AchievementCard({required this.achievement});

  final Achievement achievement;

  String get _statusLabel => switch (achievement.status) {
    AchievementStatus.unlocked => 'Completed',
    AchievementStatus.inProgress => 'Progress',
    AchievementStatus.locked => 'Locked',
  };

  @override
  Widget build(BuildContext context) {
    final isLocked = achievement.status == AchievementStatus.locked;
    final accentColor = isLocked ? AppColors.outline : achievement.color;

    return Opacity(
      opacity: isLocked ? 0.68 : 1,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.stackSm),
        decoration: BoxDecoration(
          color: isLocked
              ? AppColors.surfaceContainerLow
              : AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(
            color: isLocked
                ? AppColors.outlineVariant
                : AppColors.surfaceContainerHigh,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.05),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: accentColor.withValues(alpha: 0.16),
                  ),
                  child: Icon(achievement.icon, size: 34, color: accentColor),
                ),
                if (isLocked)
                  Positioned(
                    right: -2,
                    bottom: -2,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: AppColors.surface,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.lock,
                        size: 16,
                        color: AppColors.outline,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.stackSm),
            Text(
              achievement.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: AppTextStyles.labelLg,
            ),
            const SizedBox(height: 2),
            Text(
              achievement.subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: AppTextStyles.labelSm.copyWith(
                color: isLocked
                    ? AppColors.outline
                    : AppColors.onSurfaceVariant,
              ),
            ),
            const Spacer(),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _statusLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.labelSm.copyWith(color: accentColor),
                  ),
                ),
                Text(
                  '${achievement.progressCurrent}/${achievement.progressTarget}',
                  style: AppTextStyles.labelSm.copyWith(color: accentColor),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ProgressBarPill(
              progress: achievement.progress,
              color: accentColor,
              height: 10,
            ),
          ],
        ),
      ),
    );
  }
}
