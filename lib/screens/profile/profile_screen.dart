import 'package:flutter/material.dart';
import 'package:nori/data/app_data.dart';
import 'package:nori/models/achievement.dart';
import 'package:nori/models/habit_stat.dart';
import 'package:nori/models/nori_user.dart';
import 'package:nori/screens/achievements/achievements_screen.dart';
import 'package:nori/screens/profile/edit_profile_screen.dart';
import 'package:nori/screens/settings/settings_screen.dart';
import 'package:nori/theme/app_theme.dart';
import 'package:nori/utils/remote_errors.dart';
import 'package:nori/widgets/load_error_view.dart';
import 'package:nori/widgets/nori_avatar.dart';
import 'package:nori/widgets/nori_card.dart';
import 'package:nori/widgets/nori_icon_badge.dart';
import 'package:nori/widgets/nori_list_row.dart';
import 'package:nori/widgets/nori_screen_header.dart';
import 'package:nori/widgets/nori_scroll_scaffold.dart';
import 'package:nori/widgets/progress_bar_pill.dart';
import 'package:nori/widgets/section_header.dart';
import 'package:nori/widgets/xp_pill.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, required this.active});

  /// See [HomeScreen.active] — same [IndexedStack] staleness fix.
  final bool active;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with RemoteLoadState<ProfileScreen> {
  NoriUser? _user;
  List<Achievement>? _achievementPreview;
  double? _weeklyCompletion;
  List<HabitStat>? _habitStats;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void didUpdateWidget(covariant ProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.active && widget.active) {
      // Show the newest XP/coins at once; the reload below still has the last word.
      _user = AppData.user.lastKnownUser ?? _user;
      _loadData();
    }
  }

  Future<void> _loadData() => guardedLoad(_fetchData, hasData: _user != null);

  /// Latest [_fetchData] call; an older one finishing late is dropped.
  int _loadSeq = 0;

  Future<void> _fetchData() async {
    final seq = ++_loadSeq;
    // Independent reads, fired together instead of one round trip after
    // another.
    final (user, achievementsByCategory, weeklyCompletion, habitStats) = await (
      AppData.user.getCurrentUser(),
      AppData.achievements.getAchievementsByCategory(),
      _computeWeeklyCompletion(),
      AppData.calendar.getHabitStats(),
    ).wait;
    // Earned trophies first, then the ones closest to done, so "My
    // Achievements" never leads with locked ones the user hasn't touched.
    final all = achievementsByCategory.values.expand((c) => c).toList();
    int rank(Achievement a) => switch (a.status) {
      AchievementStatus.unlocked => 0,
      AchievementStatus.inProgress => 1,
      AchievementStatus.locked => 2,
      AchievementStatus.comingSoon => 3,
    };
    final achievements = (all..sort((a, b) => rank(a).compareTo(rank(b))))
        .take(4)
        .toList(growable: false);

    if (!mounted || seq != _loadSeq) return;
    setState(() {
      _user = user;
      _achievementPreview = achievements;
      _weeklyCompletion = weeklyCompletion;
      // getCurrentUser already computed it — no second month fetch.
      _habitStats = habitStats;
    });
  }

  /// Fraction (0-1) of scheduled habits claimed over the last 7 days
  /// (today inclusive), the same "scheduled vs. claimed" definition
  /// [MockCalendarRepository] uses for a day's status — so this and the
  /// calendar screen can never disagree about what counts as done.
  Future<double> _computeWeeklyCompletion() async {
    final today = DateTime.now();
    var scheduled = 0;
    var completed = 0;
    final byDay = await AppData.habits.getHabitsForRange(
      today.subtract(const Duration(days: 6)),
      today,
    );
    for (final habits in byDay.values) {
      scheduled += habits.length;
      completed += habits.where((h) => h.isCompletedToday).length;
    }
    return scheduled == 0 ? 0 : completed / scheduled;
  }

  Future<void> _editProfile() async {
    final user = _user;
    if (user == null) return;

    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => EditProfileScreen(user: user)),
    );
    if (saved == true) await _loadData();
  }

  void _openAchievements() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AchievementsScreen()),
    );
  }

  void _openSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SettingsScreen()),
    );
  }

  Future<void> _logOut() async {
    // Actually end the Firebase session (not just navigate away) — see
    // AuthRepository.logOut doc: otherwise relaunching the app would read
    // the still-signed-in Firebase user and skip straight back to Home.
    final ok = await guardedAction(AppData.auth.logOut);
    if (!ok) return;
    // Un-point AppData.user (etc.) from this account's Firestore data so a
    // different account signing in next doesn't start out reading it —
    // see AppData.unbindUser.
    AppData.unbindUser();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/welcome', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    final user = _user;
    final achievementPreview = _achievementPreview;
    final weeklyCompletion = _weeklyCompletion;
    final habitStats = _habitStats;
    final error = loadError;

    return Scaffold(
      body: SafeArea(
        child:
            user == null ||
                achievementPreview == null ||
                weeklyCompletion == null ||
                habitStats == null
            ? error != null
                  ? LoadErrorView(error: error, onRetry: _loadData)
                  : const Center(child: CircularProgressIndicator())
            : NoriScrollScaffold(
                maxWidth: 1000,
                children: [
                  _ProfileHeader(user: user),
                  const SizedBox(height: AppSpacing.stackMd),
                  _ProfileHero(user: user, onEdit: _editProfile),
                  const SizedBox(height: AppSpacing.stackMd),
                  _AchievementsPreviewCard(
                    achievements: achievementPreview,
                    onViewAll: _openAchievements,
                  ),
                  const SizedBox(height: AppSpacing.stackMd),
                  _HabitStatisticsCard(
                    weeklyCompletion: weeklyCompletion,
                    habitStats: habitStats,
                  ),
                  const SizedBox(height: AppSpacing.stackMd),
                  _AccountCard(onSettings: _openSettings, onLogOut: _logOut),
                ],
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
    return NoriScreenHeader(
      leading: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          NoriAvatar(imageUrl: user.avatarUrl),
          const SizedBox(width: AppSpacing.stackSm),
        ],
      ),
      title: 'Profile',
      titleStyle: AppTextStyles.headlineMd,
      trailing: XpPill(xp: user.totalXp),
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
              NoriAvatar(
                imageUrl: user.avatarUrl,
                size: 120,
                borderWidth: AppBorder.thick,
              ),
              Positioned(
                right: -4,
                bottom: 2,
                child: IconButton.filled(
                  tooltip: 'Edit profile',
                  onPressed: onEdit,
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.moss,
                    foregroundColor: AppColors.ink,
                    minimumSize: const Size.square(38),
                    side: const BorderSide(
                      color: AppColors.ink,
                      width: AppBorder.standard,
                    ),
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
                color: AppColors.mossDark,
              ),
              _ProfilePill(
                icon: Icons.local_fire_department,
                label: '${user.currentStreak} day streak',
                color: AppColors.mustardDark,
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
        border: Border.all(color: AppColors.ink, width: AppBorder.thin),
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
    required this.onViewAll,
  });

  final List<Achievement> achievements;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    return _ProfileCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionHeader(
            title: 'My achievements',
            titleStyle: AppTextStyles.headlineMd,
            trailing: TextButton(
              onPressed: onViewAll,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.mossDark,
                side: const BorderSide(
                  color: AppColors.ink,
                  width: AppBorder.thin,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
              ),
              child: const Text('View all'),
            ),
          ),
          const SizedBox(height: AppSpacing.stackSm),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: AppSpacing.gutter,
            mainAxisSpacing: AppSpacing.gutter,
            childAspectRatio: 0.72,
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
    final isComingSoon = achievement.status == AchievementStatus.comingSoon;
    final isDimmed = isLocked || isComingSoon;
    final color = isDimmed ? AppColors.inkFaint : achievement.color;

    return NoriCard(
      padding: const EdgeInsets.all(AppSpacing.unit),
      // White once it's earned or in progress, like the full Achievements
      // screen; only locked and coming-soon tiles stay muted.
      color: isDimmed ? AppColors.linenAlt : AppColors.white,
      borderWidth: AppBorder.thin,
      child: Column(
        // Top-aligned so the icons line up across tiles whose titles and
        // subtitles wrap to different heights.
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          const SizedBox(height: AppSpacing.unit),
          if (achievement.imageAsset != null)
            // Locked art is faded; the illustration alone otherwise reads as
            // earned (only the icon fallback below shows a lock).
            Opacity(
              opacity: isDimmed ? 0.4 : 1,
              child: Image.asset(
                achievement.imageAsset!,
                width: 80,
                height: 80,
                fit: BoxFit.contain,
              ),
            )
          else
            NoriIconBadge(
              icon: isComingSoon
                  ? Icons.hourglass_empty
                  : isLocked
                  ? Icons.lock
                  : achievement.icon,
              background: color.withValues(alpha: 0.16),
              size: 80,
              circle: true,
              iconSize: 38,
              iconColor: color,
            ),
          const SizedBox(height: AppSpacing.unit),
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
            style: AppTextStyles.labelSm.copyWith(color: AppColors.inkMuted),
          ),
          // Earned trophies say so, so they don't read like the in-progress
          // ones beside them.
          if (achievement.status == AchievementStatus.unlocked) ...[
            const SizedBox(height: 4),
            Text(
              'Completed',
              style: AppTextStyles.labelSm.copyWith(color: AppColors.mossDark),
            ),
          ],
        ],
      ),
    );
  }
}

class _HabitStatisticsCard extends StatelessWidget {
  const _HabitStatisticsCard({
    required this.weeklyCompletion,
    required this.habitStats,
  });

  /// Fraction 0-1, from [_ProfileScreenState._computeWeeklyCompletion].
  final double weeklyCompletion;

  /// Per-habit completion rate over the last 30 days, from
  /// [CalendarRepository.getHabitStats]. Sorted here (not by the
  /// repository) since sort order is purely a display concern.
  final List<HabitStat> habitStats;

  @override
  Widget build(BuildContext context) {
    final sortedStats = [...habitStats]
      ..sort((a, b) => b.completionRate.compareTo(a.completionRate));

    return _ProfileCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Habit statistics', style: AppTextStyles.headlineMd),
          const SizedBox(height: AppSpacing.stackMd),
          _StatisticRow(
            label: 'Weekly completion',
            value: '${(weeklyCompletion * 100).round()}%',
            progress: weeklyCompletion,
            color: AppColors.moss,
            textColor: AppColors.mossDark,
          ),
          if (sortedStats.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.stackMd),
            Text('Habit breakdown', style: AppTextStyles.labelLg),
            const SizedBox(height: 2),
            Text(
              'Last 30 days',
              style: AppTextStyles.labelSm.copyWith(color: AppColors.inkMuted),
            ),
            const SizedBox(height: AppSpacing.stackSm),
            for (final stat in sortedStats) ...[
              _HabitStatRow(
                stat: stat,
                tagLabel: sortedStats.length > 1 && stat == sortedStats.first
                    ? 'Easiest'
                    : sortedStats.length > 1 && stat == sortedStats.last
                    ? 'Most missed'
                    : null,
                tagColor: sortedStats.length > 1 && stat == sortedStats.first
                    ? AppColors.moss
                    : AppColors.terracotta,
                tagTextColor:
                    sortedStats.length > 1 && stat == sortedStats.first
                    ? AppColors.mossDark
                    : AppColors.terracottaDark,
              ),
              if (stat != sortedStats.last)
                const SizedBox(height: AppSpacing.stackSm),
            ],
          ],
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
    required this.textColor,
  });

  final String label;
  final String value;
  final double progress;

  /// Bar fill. Too light to read as text, so the value uses [textColor].
  final Color color;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: Text(label, style: AppTextStyles.labelLg)),
            Text(
              value,
              style: AppTextStyles.labelLg.copyWith(color: textColor),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.unit),
        ProgressBarPill(progress: progress, height: 14, color: color),
      ],
    );
  }
}

class _HabitStatRow extends StatelessWidget {
  const _HabitStatRow({
    required this.stat,
    this.tagLabel,
    required this.tagColor,
    required this.tagTextColor,
  });

  final HabitStat stat;

  /// 'Easiest' / 'Most Missed' / null (no tag — only the two extremes get
  /// one, and only when there's more than one habit to compare against).
  final String? tagLabel;
  final Color tagColor;
  final Color tagTextColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        NoriIconBadge(
          icon: stat.icon,
          // The habit's color as the badge fill with an ink icon, like every
          // other NoriIconBadge. A pastel icon on a tint of itself vanished.
          background: stat.color,
          size: 36,
          iconSize: 18,
        ),
        const SizedBox(width: AppSpacing.stackSm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      stat.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.labelLg,
                    ),
                  ),
                  if (tagLabel != null) ...[
                    const SizedBox(width: AppSpacing.unit),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: tagColor.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(AppRadius.full),
                        border: Border.all(
                          color: AppColors.ink,
                          width: AppBorder.thin,
                        ),
                      ),
                      child: Text(
                        tagLabel!,
                        style: AppTextStyles.labelSm.copyWith(
                          color: tagTextColor,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(width: AppSpacing.unit),
                  Text(
                    '${(stat.completionRate * 100).round()}%',
                    style: AppTextStyles.labelSm.copyWith(
                      color: AppColors.inkMuted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              // Default moss fill: a pastel habit color barely showed against
              // the linen track.
              ProgressBarPill(progress: stat.completionRate, height: 8),
            ],
          ),
        ),
      ],
    );
  }
}

class _AccountCard extends StatelessWidget {
  const _AccountCard({required this.onSettings, required this.onLogOut});

  final VoidCallback onSettings;
  final VoidCallback onLogOut;

  @override
  Widget build(BuildContext context) {
    return _ProfileCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Account', style: AppTextStyles.headlineMd),
          const SizedBox(height: AppSpacing.stackSm),
          NoriListRow(
            icon: Icons.settings,
            label: 'Settings',
            onTap: onSettings,
          ),
          const SizedBox(height: AppSpacing.unit),
          NoriListRow(icon: Icons.logout, label: 'Log out', onTap: onLogOut),
        ],
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return NoriCard(radius: AppRadius.md, child: child);
  }
}
