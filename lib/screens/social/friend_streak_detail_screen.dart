import 'package:flutter/material.dart';
import 'package:nori/data/app_data.dart';
import 'package:nori/models/social_people.dart';
import 'package:nori/screens/social/friend_profile_screen.dart';
import 'package:nori/screens/social/friends_screen.dart';
import 'package:nori/screens/social/social_load_state.dart';
import 'package:nori/screens/social/widgets/social_widgets.dart';
import 'package:nori/theme/app_theme.dart';
import 'package:nori/utils/date_labels.dart';
import 'package:nori/utils/remote_errors.dart';
import 'package:nori/widgets/nori_card.dart';
import 'package:nori/widgets/nori_empty_state.dart';
import 'package:nori/widgets/nori_screen_header.dart';
import 'package:nori/widgets/nori_scroll_scaffold.dart';
import 'package:nori/widgets/progress_bar_pill.dart';
import 'package:nori/widgets/section_header.dart';
import 'package:nori/widgets/streak_chip.dart';
import 'package:nori/widgets/tactile_button.dart';

class FriendStreakDetailScreen extends StatefulWidget {
  const FriendStreakDetailScreen({super.key, required this.friendId});
  final String friendId;

  @override
  State<FriendStreakDetailScreen> createState() =>
      _FriendStreakDetailScreenState();
}

class _FriendStreakDetailScreenState extends State<FriendStreakDetailScreen>
    with
        RemoteLoadState<FriendStreakDetailScreen>,
        SocialLoadState<FriendStreakDetailScreen> {
  FriendStreak? _streak;
  SocialUser? _friend;
  SocialUser? _me;
  bool _sending = false;
  bool _nudging = false;
  bool _nudged = false;

  @override
  Future<void> loadSocial() async {
    final streak = await AppData.social.getFriendStreak(widget.friendId);
    final people = await AppData.social.getUserDirectory();
    final friends = await AppData.social.getFriends();
    if (!mounted) return;
    setState(() {
      _streak = friends.any((f) => f.id == widget.friendId) ? streak : null;
      _friend = people[widget.friendId];
      _me = people['me'];
    });
  }

  Future<void> _highFive() async {
    if (_sending) return;
    setState(() => _sending = true);
    final success = await guardedAction(
      () => AppData.social.sendHighFive(widget.friendId),
    );
    if (!mounted) return;
    setState(() => _sending = false);
    if (success) {
      showSocialToast(context, 'High-five sent to ${_friend!.firstName}');
    }
  }

  Future<void> _nudge() async {
    if (_nudging || _nudged) return;
    setState(() => _nudging = true);
    final success = await guardedAction(
      () => AppData.social.nudge(widget.friendId),
    );
    if (!mounted) return;
    setState(() {
      _nudging = false;
      if (success) _nudged = true;
    });
    if (success) {
      showSocialToast(context, 'Nudge sent to ${_friend!.firstName}');
    }
  }

  List<StreakDay> _lastFortnight(FriendStreak streak) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return List.generate(14, (index) {
      final date = DateTime(today.year, today.month, today.day - 13 + index);
      for (final day in streak.days) {
        if (DateUtils.isSameDay(date, day.date)) return day;
      }
      return StreakDay(date: date, me: false, friend: false);
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: buildLoaded((context) {
        final streak = _streak;
        final friend = _friend;
        final me = _me;
        final available = streak != null && friend != null && me != null;
        final days = available ? _lastFortnight(streak) : <StreakDay>[];
        final today = days.isEmpty ? null : days.last;
        return NoriScrollScaffold(
          maxWidth: 800,
          children: [
            NoriScreenHeader(
              leading: NoriScreenHeader.backButton(context),
              title: 'Streak details',
              titleStyle: AppTextStyles.headlineLgMobile,
            ),
            const SizedBox(height: AppSpacing.stackMd),
            if (!available)
              NoriEmptyState(
                icon: Icons.local_fire_department_outlined,
                title: 'No friend streak yet',
                message: 'Complete daily habits together to start a streak.',
                actionLabel: 'See friends',
                onAction: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => const FriendsScreen(),
                  ),
                ),
              )
            else ...[
              NoriCard(
                color: AppColors.mustardLight,
                borderWidth: AppBorder.thick,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(
                      Icons.local_fire_department,
                      size: 64,
                      color: AppColors.mustardDark,
                    ),
                    const SizedBox(height: AppSpacing.stackSm),
                    Text(
                      '${streak.current}-day streak!',
                      style: AppTextStyles.headlineLg,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.unit),
                    Text(
                      'You & ${friend.firstName} have completed habits together for ${streak.current} days.',
                      style: AppTextStyles.bodyMd,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.gutter),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: AppSpacing.unit,
                      runSpacing: AppSpacing.unit,
                      children: [
                        _StatChip(label: 'Current', value: streak.current),
                        _StatChip(label: 'Best', value: streak.best),
                      ],
                    ),
                    if (streak.nextBadgeLabel.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.stackMd),
                      Text(
                        streak.daysToBadge > 0
                            ? '${streak.daysToBadge} days until "${streak.nextBadgeLabel}"'
                            : 'Milestone reached: ${streak.nextBadgeLabel}',
                        style: AppTextStyles.labelLg,
                      ),
                      const SizedBox(height: AppSpacing.stackSm),
                      ProgressBarPill(
                        progress: streak.current + streak.daysToBadge == 0
                            ? 0
                            : streak.current /
                                  (streak.current + streak.daysToBadge),
                        semanticLabel: 'Next streak milestone',
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.stackLg),
              SectionHeader(
                icon: Icons.calendar_month_outlined,
                title: 'Last 14 days',
                trailing: Text(
                  'Today: bold outline',
                  style: AppTextStyles.labelSm,
                ),
              ),
              const SizedBox(height: AppSpacing.stackSm),
              for (var row = 0; row < 2; row++) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var column = 0; column < 7; column++)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.unit / 2),
                          child: _StreakDayCell(
                            day: days[row * 7 + column],
                            today: row * 7 + column == 13,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.unit),
              ],
              const SizedBox(height: AppSpacing.stackSm),
              const Wrap(
                spacing: AppSpacing.gutter,
                runSpacing: AppSpacing.unit,
                children: [
                  _Legend(
                    icon: Icons.check,
                    label: 'Both done',
                    color: AppColors.moss,
                  ),
                  _Legend(
                    icon: Icons.timelapse,
                    label: 'One done',
                    color: AppColors.mustardLight,
                  ),
                  _Legend(
                    icon: Icons.remove,
                    label: 'Neither done',
                    color: AppColors.linenAlt,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.stackMd),
              // Mock rule: completing at least one habit each day keeps a shared streak.
              Text(
                'You both complete at least one habit a day. Preview rule.',
                style: AppTextStyles.bodyMd.copyWith(color: AppColors.inkMuted),
              ),
              const SizedBox(height: AppSpacing.stackLg),
              SectionHeader(title: 'Today', trailing: const SizedBox.shrink()),
              const SizedBox(height: AppSpacing.stackSm),
              PersonRow(
                user: me,
                highlighted: true,
                subtitle: 'You: ${today!.me ? 'done today' : 'not yet'}',
                trailing: Icon(
                  today.me ? Icons.check_circle : Icons.schedule,
                  color: today.me ? AppColors.mossDark : AppColors.inkMuted,
                ),
              ),
              const SizedBox(height: AppSpacing.stackSm),
              PersonRow(
                user: friend,
                subtitle:
                    '${friend.firstName}: ${today.friend ? 'done today' : 'not yet'}',
                trailing: Icon(
                  today.friend ? Icons.check_circle : Icons.schedule,
                  color: today.friend ? AppColors.mossDark : AppColors.inkMuted,
                ),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => FriendProfileScreen(userId: friend.id),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.stackMd),
              TactileButton(
                label: _sending ? 'Sending...' : 'Send high-five',
                icon: Icons.celebration_outlined,
                onPressed: _sending ? null : _highFive,
              ),
              if (!today.friend) ...[
                const SizedBox(height: AppSpacing.stackSm),
                TextButton.icon(
                  onPressed: _nudging || _nudged ? null : _nudge,
                  icon: const Icon(Icons.notifications_active_outlined),
                  label: Text(
                    _nudging
                        ? 'Sending...'
                        : _nudged
                        ? 'Nudged'
                        : 'Nudge',
                    style: AppTextStyles.labelLg,
                  ),
                ),
              ],
            ],
          ],
        );
      }),
    ),
  );
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.label, required this.value});
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) => NoriCard(
    radius: AppRadius.full,
    borderWidth: AppBorder.thin,
    padding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.stackSm,
      vertical: AppSpacing.unit,
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: AppTextStyles.labelLg),
        const SizedBox(width: AppSpacing.unit),
        StreakChip(streak: value),
      ],
    ),
  );
}

class _StreakDayCell extends StatelessWidget {
  const _StreakDayCell({required this.day, required this.today});
  final StreakDay day;
  final bool today;

  @override
  Widget build(BuildContext context) {
    final oneDone = day.me || day.friend;
    final state = day.both
        ? 'Both done'
        : oneDone
        ? 'One done'
        : 'Neither done';
    return Semantics(
      label:
          '${weekdayFull(day.date.weekday)}, ${monthAbbr(day.date.month)} ${day.date.day}: $state${today ? ', today' : ''}',
      child: Tooltip(
        message: '${day.date.day} ${monthAbbr(day.date.month)}: $state',
        child: Column(
          children: [
            Text(
              weekdayInitial(day.date.weekday),
              style: AppTextStyles.labelSm,
            ),
            const SizedBox(height: AppSpacing.unit),
            AspectRatio(
              aspectRatio: 1,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: day.both
                      ? AppColors.moss
                      : oneDone
                      ? AppColors.mustardLight
                      : AppColors.linenAlt,
                  border: Border.all(
                    color: AppColors.ink,
                    width: today ? AppBorder.thick : AppBorder.thin,
                  ),
                ),
                child: day.both || oneDone
                    ? Icon(
                        day.both ? Icons.check : Icons.timelapse,
                        size: 18,
                        color: AppColors.ink,
                      )
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.icon, required this.label, required this.color});
  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        padding: const EdgeInsets.all(AppSpacing.unit / 2),
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.ink, width: AppBorder.thin),
        ),
        child: Icon(icon, size: 16, color: AppColors.ink),
      ),
      const SizedBox(width: AppSpacing.unit),
      Text(label, style: AppTextStyles.labelSm),
    ],
  );
}
