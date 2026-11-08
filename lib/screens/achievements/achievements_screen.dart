import 'package:flutter/material.dart';
import 'package:nori/data/app_data.dart';
import 'package:nori/models/achievement.dart';
import 'package:nori/models/nori_user.dart';
import 'package:nori/navigation/reloadable.dart';
import 'package:nori/theme/app_theme.dart';
import 'package:nori/utils/remote_errors.dart';
import 'package:nori/widgets/load_error_view.dart';
import 'package:nori/widgets/nori_card.dart';
import 'package:nori/widgets/nori_icon_badge.dart';
import 'package:nori/widgets/nori_screen_header.dart';
import 'package:nori/widgets/nori_scroll_scaffold.dart';
import 'package:nori/widgets/progress_bar_pill.dart';
import 'package:nori/widgets/xp_pill.dart';

class AchievementsScreen extends StatefulWidget {
  const AchievementsScreen({super.key});

  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen>
    with RemoteLoadState<AchievementsScreen>
    implements Reloadable {
  NoriUser? _user;
  Map<String, List<Achievement>>? _achievementsByCategory;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  Future<void> reload() => _loadData();

  Future<void> _loadData() => guardedLoad(_fetchData, hasData: _user != null);

  Future<void> _fetchData() async {
    final (user, achievements) = await (
      AppData.user.getCurrentUser(),
      AppData.achievements.getAchievementsByCategory(),
    ).wait;
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
    final error = loadError;

    return Scaffold(
      body: SafeArea(
        child: user == null || achievementsByCategory == null
            ? error != null
                  ? LoadErrorView(error: error, onRetry: _loadData)
                  : const Center(child: CircularProgressIndicator())
            : NoriScrollScaffold(
                maxWidth: 1200,
                children: [
                  _AchievementsHeader(user: user),
                  const SizedBox(height: AppSpacing.stackLg),
                  Text('Your trophies', style: AppTextStyles.headlineLgMobile),
                  const SizedBox(height: AppSpacing.stackSm),
                  Text(
                    'Track your progress and show off your consistency. Every habit brings you closer to your next milestone.',
                    style: AppTextStyles.bodyLg.copyWith(
                      color: AppColors.inkMuted,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.stackLg),
                  for (final entry in achievementsByCategory.entries) ...[
                    _AchievementCategory(
                      category: entry.key,
                      achievements: entry.value,
                    ),
                    if (entry.key != achievementsByCategory.keys.last)
                      const SizedBox(height: AppSpacing.stackLg),
                  ],
                ],
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
    return NoriScreenHeader(
      leading: NoriScreenHeader.backButton(context),
      title: 'Achievements',
      titleStyle: AppTextStyles.headlineLgMobile,
      trailing: XpPill(xp: user.totalXp),
    );
  }
}

class _AchievementCategory extends StatelessWidget {
  const _AchievementCategory({
    required this.category,
    required this.achievements,
  });

  final String category;
  final List<Achievement> achievements;

  IconData get _categoryIcon => switch (category) {
    'Consistency' => Icons.bolt,
    'Milestones' => Icons.military_tech,
    'Habits' => Icons.checklist,
    'Pet Care' => Icons.pets,
    'Social' => Icons.groups,
    _ => Icons.emoji_events,
  };

  Color get _categoryColor => switch (category) {
    'Milestones' => AppColors.mustardDark,
    'Pet Care' => AppColors.terracottaDark,
    'Social' => AppColors.mossDark,
    _ => AppColors.moss,
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
          crossAxisCount: 2,
          crossAxisSpacing: AppSpacing.gutter,
          mainAxisSpacing: AppSpacing.gutter,
          childAspectRatio: 0.68,
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
    AchievementStatus.comingSoon => 'Coming soon',
  };

  @override
  Widget build(BuildContext context) {
    final isLocked = achievement.status == AchievementStatus.locked;
    final isComingSoon = achievement.status == AchievementStatus.comingSoon;
    final isDimmed = isLocked || isComingSoon;
    final accentColor = isDimmed ? AppColors.ink : achievement.color;

    return Opacity(
      opacity: isDimmed ? 0.68 : 1,
      child: NoriCard(
        padding: const EdgeInsets.all(AppSpacing.stackSm),
        color: isDimmed ? AppColors.linenAlt : AppColors.white,
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                if (achievement.imageAsset != null)
                  Image.asset(
                    achievement.imageAsset!,
                    width: 104,
                    height: 104,
                    fit: BoxFit.contain,
                  )
                else
                  NoriIconBadge(
                    icon: achievement.icon,
                    background: accentColor.withValues(alpha: 0.16),
                    size: 104,
                    circle: true,
                    iconSize: 50,
                    iconColor: accentColor,
                  ),
                if (isDimmed)
                  Positioned(
                    right: -2,
                    bottom: -2,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: AppColors.linen,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.ink,
                          width: AppBorder.thin,
                        ),
                      ),
                      child: Icon(
                        isComingSoon ? Icons.hourglass_empty : Icons.lock,
                        size: 16,
                        color: AppColors.ink,
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
                color: isDimmed ? AppColors.ink : AppColors.inkMuted,
              ),
            ),
            const SizedBox(height: AppSpacing.stackSm),
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
                if (achievement.progressTarget > 0)
                  Text(
                    // Capped so a done "add 1 friend" reads 1/1, not 6/1.
                    '${achievement.progressCurrent.clamp(0, achievement.progressTarget)}/${achievement.progressTarget}',
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
