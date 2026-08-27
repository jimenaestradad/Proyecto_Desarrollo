import 'package:flutter/material.dart';
import 'package:nori/data/app_data.dart';
import 'package:nori/models/achievement.dart';
import 'package:nori/models/nori_user.dart';
import 'package:nori/screens/achievements/achievements_screen.dart';
import 'package:nori/screens/leaderboard/leaderboard_screen.dart';
import 'package:nori/screens/notifications/notifications_screen.dart';
import 'package:nori/screens/premium/nori_plus_screen.dart';
import 'package:nori/screens/shop/shop_screen.dart';
import 'package:nori/theme/app_theme.dart';
import 'package:nori/widgets/future_feature_banner.dart';
import 'package:nori/widgets/nori_avatar.dart';
import 'package:nori/widgets/progress_bar_pill.dart';
import 'package:nori/widgets/tactile_button.dart';
import 'package:nori/widgets/xp_pill.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  NoriUser? _user;
  List<Achievement>? _achievementPreview;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final user = await AppData.user.getCurrentUser();
    final achievementsByCategory = await AppData.achievements
        .getAchievementsByCategory();
    final achievements = achievementsByCategory.values
        .expand((category) => category)
        .take(4)
        .toList(growable: false);

    if (!mounted) return;
    setState(() {
      _user = user;
      _achievementPreview = achievements;
    });
  }

  void _showComingSoon() {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Coming soon')));
  }

  void _openAchievements() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AchievementsScreen()),
    );
  }

  void _openNotifications() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const NotificationsScreen()),
    );
  }

  void _openShop() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ShopScreen()),
    );
  }

  void _openLeaderboard() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const LeaderboardScreen()),
    );
  }

  void _openNoriPlus() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const NoriPlusScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = _user;
    final achievementPreview = _achievementPreview;

    return Scaffold(
      body: SafeArea(
        child: user == null || achievementPreview == null
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
                        constraints: const BoxConstraints(maxWidth: 1000),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _ProfileHeader(user: user),
                            const SizedBox(height: AppSpacing.stackMd),
                            _ProfileHero(user: user, onEdit: _showComingSoon),
                            const SizedBox(height: AppSpacing.stackMd),
                            _AchievementsPreviewCard(
                              achievements: achievementPreview,
                              isWide: isWide,
                              onViewAll: _openAchievements,
                            ),
                            const SizedBox(height: AppSpacing.stackMd),
                            const _HabitStatisticsCard(),
                            const SizedBox(height: AppSpacing.stackMd),
                            _AccountCard(
                              onSettings: _showComingSoon,
                              onNotifications: _openNotifications,
                              onAppearance: _showComingSoon,
                            ),
                            const SizedBox(height: AppSpacing.stackMd),
                            _ExploreCard(
                              onShop: _openShop,
                              onLeaderboard: _openLeaderboard,
                              onNoriPlus: _openNoriPlus,
                            ),
                            const SizedBox(height: AppSpacing.stackMd),
                            TactileButton(
                              label: 'Log Out',
                              icon: Icons.logout,
                              backgroundColor: AppColors.errorContainer,
                              foregroundColor: AppColors.onErrorContainer,
                              shadowColor: AppColors.error.withValues(
                                alpha: 0.25,
                              ),
                              onPressed: () =>
                                  Navigator.pushNamedAndRemoveUntil(
                                    context,
                                    '/welcome',
                                    (route) => false,
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

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.user});

  final NoriUser user;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        NoriAvatar(imageUrl: user.avatarUrl),
        const SizedBox(width: AppSpacing.stackSm),
        Expanded(child: Text('Profile', style: AppTextStyles.headlineMd)),
        XpPill(xp: user.totalXp),
      ],
    );
  }
}

class _ProfileHero extends StatelessWidget {
  const _ProfileHero({required this.user, required this.onEdit});

  final NoriUser user;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return _ProfileCard(
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              NoriAvatar(imageUrl: user.avatarUrl, size: 120, borderWidth: 4),
              Positioned(
                right: -4,
                bottom: 2,
                child: IconButton.filled(
                  onPressed: onEdit,
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.onPrimary,
                    minimumSize: const Size.square(38),
                  ),
                  icon: const Icon(Icons.edit, size: 18),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.stackSm),
          Text(
            user.name,
            textAlign: TextAlign.center,
            style: AppTextStyles.headlineLgMobile,
          ),
          const SizedBox(height: AppSpacing.stackSm),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: AppSpacing.unit,
            runSpacing: AppSpacing.unit,
            children: [
              _ProfilePill(
                icon: Icons.military_tech,
                label: 'Level ${user.level}',
                color: AppColors.primary,
              ),
              _ProfilePill(
                icon: Icons.diamond,
                label: '${user.totalXp} XP',
                color: AppColors.secondary,
              ),
              _ProfilePill(
                icon: Icons.local_fire_department,
                label: '${user.currentStreak} Day Streak',
                color: AppColors.tertiary,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProfilePill extends StatelessWidget {
  const _ProfilePill({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.stackSm,
        vertical: AppSpacing.unit,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 6),
          Text(label, style: AppTextStyles.labelLg.copyWith(color: color)),
        ],
      ),
    );
  }
}

class _AchievementsPreviewCard extends StatelessWidget {
  const _AchievementsPreviewCard({
    required this.achievements,
    required this.isWide,
    required this.onViewAll,
  });

  final List<Achievement> achievements;
  final bool isWide;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    return _ProfileCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('My Achievements', style: AppTextStyles.headlineMd),
              ),
              TextButton(onPressed: onViewAll, child: const Text('View All')),
            ],
          ),
          const SizedBox(height: AppSpacing.stackSm),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: isWide ? 4 : 2,
            crossAxisSpacing: AppSpacing.gutter,
            mainAxisSpacing: AppSpacing.gutter,
            childAspectRatio: isWide ? 1.5 : 0.9,
            children: [
              for (final achievement in achievements)
                _AchievementPreview(achievement: achievement),
            ],
          ),
        ],
      ),
    );
  }
}

class _AchievementPreview extends StatelessWidget {
  const _AchievementPreview({required this.achievement});

  final Achievement achievement;

  @override
  Widget build(BuildContext context) {
    final isLocked = achievement.status == AchievementStatus.locked;
    final color = isLocked ? AppColors.outline : achievement.color;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.unit),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.16),
            ),
            child: Icon(
              isLocked ? Icons.lock : achievement.icon,
              color: color,
              size: 28,
            ),
          ),
          const SizedBox(height: AppSpacing.unit),
          Text(
            achievement.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: AppTextStyles.labelLg,
          ),
        ],
      ),
    );
  }
}

class _HabitStatisticsCard extends StatelessWidget {
  const _HabitStatisticsCard();

  @override
  Widget build(BuildContext context) {
    return _ProfileCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Habit Statistics', style: AppTextStyles.headlineMd),
          const SizedBox(height: AppSpacing.stackMd),
          const _StatisticRow(
            label: 'Weekly Completion',
            value: '85%',
            progress: 0.85,
            color: AppColors.primary,
          ),
          const SizedBox(height: AppSpacing.stackMd),
          const _StatisticRow(
            label: 'Daily Quests',
            value: '80%',
            progress: 0.8,
            color: AppColors.secondary,
          ),
        ],
      ),
    );
  }
}

class _StatisticRow extends StatelessWidget {
  const _StatisticRow({
    required this.label,
    required this.value,
    required this.progress,
    required this.color,
  });

  final String label;
  final String value;
  final double progress;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: Text(label, style: AppTextStyles.labelLg)),
            Text(value, style: AppTextStyles.labelLg.copyWith(color: color)),
          ],
        ),
        const SizedBox(height: AppSpacing.unit),
        ProgressBarPill(progress: progress, height: 14, color: color),
      ],
    );
  }
}

class _AccountCard extends StatelessWidget {
  const _AccountCard({
    required this.onSettings,
    required this.onNotifications,
    required this.onAppearance,
  });

  final VoidCallback onSettings;
  final VoidCallback onNotifications;
  final VoidCallback onAppearance;

  @override
  Widget build(BuildContext context) {
    return _ProfileCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Account', style: AppTextStyles.headlineMd),
          const SizedBox(height: AppSpacing.stackSm),
          _AccountRow(
            icon: Icons.settings,
            label: 'Settings',
            onTap: onSettings,
          ),
          const SizedBox(height: AppSpacing.unit),
          _AccountRow(
            icon: Icons.notifications,
            label: 'Notifications',
            onTap: onNotifications,
          ),
          const SizedBox(height: AppSpacing.unit),
          _AccountRow(
            icon: Icons.palette,
            label: 'Appearance',
            onTap: onAppearance,
          ),
        ],
      ),
    );
  }
}

class _ExploreCard extends StatelessWidget {
  const _ExploreCard({
    required this.onShop,
    required this.onLeaderboard,
    required this.onNoriPlus,
  });

  final VoidCallback onShop;
  final VoidCallback onLeaderboard;
  final VoidCallback onNoriPlus;

  @override
  Widget build(BuildContext context) {
    return _ProfileCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Explore', style: AppTextStyles.headlineMd),
          const SizedBox(height: 2),
          Text(
            "Design previews for what's next — not built yet.",
            style: AppTextStyles.bodyMd.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.stackSm),
          _AccountRow(
            icon: Icons.shopping_bag,
            label: 'Shop',
            onTap: onShop,
            trailing: const SoonBadge(),
          ),
          const SizedBox(height: AppSpacing.unit),
          _AccountRow(
            icon: Icons.leaderboard,
            label: 'Leaderboard',
            onTap: onLeaderboard,
            trailing: const SoonBadge(),
          ),
          const SizedBox(height: AppSpacing.unit),
          _AccountRow(
            icon: Icons.diamond,
            label: 'Nori Plus',
            onTap: onNoriPlus,
            trailing: const SoonBadge(),
          ),
        ],
      ),
    );
  }
}

class _AccountRow extends StatelessWidget {
  const _AccountRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        side: const BorderSide(color: AppColors.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.gutter),
          child: Row(
            children: [
              Icon(icon, color: AppColors.onSurfaceVariant),
              const SizedBox(width: AppSpacing.stackSm),
              Expanded(child: Text(label, style: AppTextStyles.labelLg)),
              if (trailing != null) ...[
                trailing!,
                const SizedBox(width: AppSpacing.unit),
              ],
              const Icon(
                Icons.chevron_right,
                color: AppColors.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.containerPaddingMobile),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.surfaceContainerHighest),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.05),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}
