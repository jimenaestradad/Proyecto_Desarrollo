import 'package:flutter/material.dart';
import 'package:nori/data/app_data.dart';
import 'package:nori/data/habit_repository.dart';
import 'package:nori/models/calendar_day.dart';
import 'package:nori/models/habit.dart';
import 'package:nori/models/nori_user.dart';
import 'package:nori/screens/habits/add_habit_screen.dart';
import 'package:nori/screens/pet/evolution_screen.dart';
import 'package:nori/theme/app_theme.dart';
import 'package:nori/utils/date_labels.dart';
import 'package:nori/widgets/habit_progress_card.dart';
import 'package:nori/widgets/nori_avatar.dart';
import 'package:nori/widgets/nori_screen_header.dart';
import 'package:nori/widgets/streak_chip.dart';
import 'package:nori/widgets/xp_pill.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key, required this.active});

  /// See [HomeScreen.active] — same [IndexedStack] staleness fix.
  final bool active;

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  NoriUser? _user;
  CalendarMonthStats? _stats;
  late int _year;
  late int _month;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _year = now.year;
    _month = now.month;
    _loadData();
  }

  @override
  void didUpdateWidget(covariant CalendarScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.active && widget.active) _loadData();
  }

  Future<void> _loadData() async {
    final user = await AppData.user.getCurrentUser();
    final stats = await AppData.calendar.getMonth(_year, _month);
    if (!mounted) return;
    setState(() {
      _user = user;
      _stats = stats;
    });
  }

  bool get _isCurrentMonth {
    final now = DateTime.now();
    return _year == now.year && _month == now.month;
  }

  /// Steps the viewed month by [delta], clamped so it can't go past the
  /// current month.
  void _changeMonth(int delta) {
    var year = _year;
    var month = _month + delta;
    if (month < 1) {
      month = 12;
      year -= 1;
    } else if (month > 12) {
      month = 1;
      year += 1;
    }
    final now = DateTime.now();
    if (year > now.year || (year == now.year && month > now.month)) return;
    setState(() {
      _year = year;
      _month = month;
      _stats = null;
    });
    _loadData();
  }

  Future<void> _openDayDetail(DateTime date) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _DayDetailSheet(date: date),
    );
    // Habits may have been logged/claimed inside the sheet — the month's
    // stats and day colours are derived from that same data, so refresh.
    if (!mounted) return;
    await _loadData();
  }

  @override
  Widget build(BuildContext context) {
    final user = _user;
    final stats = _stats;

    return Scaffold(
      body: SafeArea(
        child: user == null || stats == null
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
                            _CalendarHeader(user: user),
                            const SizedBox(height: AppSpacing.stackLg),
                            Row(
                              children: [
                                IconButton(
                                  onPressed: () => _changeMonth(-1),
                                  icon: const Icon(
                                    Icons.chevron_left,
                                    color: AppColors.ink,
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    '${stats.monthLabel} ${stats.year}',
                                    textAlign: TextAlign.center,
                                    style: isWide
                                        ? AppTextStyles.headlineLg
                                        : AppTextStyles.headlineLgMobile,
                                  ),
                                ),
                                IconButton(
                                  onPressed: _isCurrentMonth
                                      ? null
                                      : () => _changeMonth(1),
                                  icon: Icon(
                                    Icons.chevron_right,
                                    color: _isCurrentMonth
                                        ? AppColors.inkFaint
                                        : AppColors.ink,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.unit),
                            Text(
                              'Stay consistent to level up your Nori!',
                              textAlign: TextAlign.center,
                              style: AppTextStyles.bodyMd.copyWith(
                                color: AppColors.inkMuted,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.stackMd),
                            GridView.count(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              crossAxisCount: isWide ? 4 : 2,
                              crossAxisSpacing: AppSpacing.gutter,
                              mainAxisSpacing: AppSpacing.gutter,
                              childAspectRatio: isWide ? 1.35 : 1.15,
                              children: [
                                _CalendarStatCard(
                                  icon: Icons.local_fire_department,
                                  iconColor: AppColors.terracottaDark,
                                  value: '${stats.currentStreak}',
                                  label: 'Current Streak',
                                ),
                                _CalendarStatCard(
                                  icon: Icons.star,
                                  iconColor: AppColors.mustardDark,
                                  value: '${stats.perfectDays}',
                                  label: 'Perfect Days',
                                ),
                                _CalendarStatCard(
                                  icon: Icons.check_circle,
                                  iconColor: AppColors.mossDark,
                                  value: '${stats.habitsDone}',
                                  label: 'Habits Done',
                                ),
                                _CalendarStatCard(
                                  icon: Icons.sentiment_dissatisfied,
                                  iconColor: AppColors.inkMuted,
                                  value: '${stats.missedDays}',
                                  label: 'Missed Days',
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.stackMd),
                            _CalendarCard(days: stats.days, onDayTap: _openDayDetail),
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

class _CalendarHeader extends StatelessWidget {
  const _CalendarHeader({required this.user});

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
      title: 'Nori',
      titleStyle: AppTextStyles.headlineMd,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (user.currentStreak > 0) ...[
            StreakChip(streak: user.currentStreak),
            const SizedBox(width: 4),
          ],
          XpPill(xp: user.totalXp),
        ],
      ),
    );
  }
}

class _CalendarStatCard extends StatelessWidget {
  const _CalendarStatCard({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.stackSm),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AppColors.ink, width: AppBorder.standard),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 30, color: iconColor),
          const SizedBox(height: AppSpacing.unit),
          Text(value, style: AppTextStyles.headlineMd),
          Text(
            label,
            textAlign: TextAlign.center,
            style: AppTextStyles.labelSm,
          ),
        ],
      ),
    );
  }
}

class _CalendarCard extends StatelessWidget {
  const _CalendarCard({required this.days, required this.onDayTap});

  final List<CalendarDay> days;
  final ValueChanged<DateTime> onDayTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.gutter),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AppColors.ink, width: AppBorder.standard),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              for (var weekday = DateTime.monday; weekday <= DateTime.sunday; weekday++)
                Expanded(
                  child: Text(
                    weekdayAbbr(weekday),
                    textAlign: TextAlign.center,
                    style: AppTextStyles.labelSm,
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.stackSm),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 7,
            childAspectRatio: 1,
            crossAxisSpacing: AppSpacing.unit,
            mainAxisSpacing: AppSpacing.unit,
            children: [
              for (final day in days) _CalendarDayCell(day: day, onTap: onDayTap),
            ],
          ),
          const SizedBox(height: AppSpacing.stackMd),
          const Divider(color: AppColors.ink, height: 1),
          const SizedBox(height: AppSpacing.gutter),
          const Wrap(
            alignment: WrapAlignment.center,
            spacing: AppSpacing.gutter,
            runSpacing: AppSpacing.unit,
            children: [
              _LegendItem(
                color: AppColors.mustardLight,
                borderColor: AppColors.ink,
                label: 'Perfect',
              ),
              _LegendItem(
                color: AppColors.blush,
                borderColor: AppColors.ink,
                label: 'Done',
              ),
              _LegendItem(
                color: AppColors.linenAlt,
                borderColor: AppColors.ink,
                label: 'Missed',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CalendarDayCell extends StatelessWidget {
  const _CalendarDayCell({required this.day, required this.onTap});

  final CalendarDay day;
  final ValueChanged<DateTime> onTap;

  @override
  Widget build(BuildContext context) {
    if (day.status == CalendarDayStatus.empty) {
      return const SizedBox.shrink();
    }

    final (
      backgroundColor,
      borderColor,
      borderWidth,
      textColor,
    ) = switch (day.status) {
      CalendarDayStatus.perfect => (
        AppColors.mustardLight,
        AppColors.ink,
        AppBorder.thin,
        AppColors.mustardDark,
      ),
      CalendarDayStatus.done => (
        AppColors.blush,
        AppColors.ink,
        AppBorder.thin,
        AppColors.terracottaDark,
      ),
      CalendarDayStatus.missed => (
        AppColors.linenAlt,
        AppColors.ink,
        AppBorder.thin,
        AppColors.inkMuted,
      ),
      CalendarDayStatus.today => (
        AppColors.moss,
        AppColors.ink,
        AppBorder.thick,
        AppColors.ink,
      ),
      CalendarDayStatus.future => (
        AppColors.linen,
        AppColors.ink,
        AppBorder.thin,
        AppColors.inkFaint,
      ),
      CalendarDayStatus.empty => throw StateError('Empty days return early'),
    };

    final isPerfect = day.status == CalendarDayStatus.perfect;
    final isToday = day.status == CalendarDayStatus.today;
    // Future days have nothing logged yet — tapping one would just open an
    // empty sheet, so it's left inert.
    final date = day.date;
    final isTappable = date != null && day.status != CalendarDayStatus.future;

    final cell = Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(AppRadius.sm * 0.55),
        border: Border.all(color: borderColor, width: borderWidth),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (isPerfect)
            Positioned(
              top: 3,
              right: 3,
              child: Icon(
                Icons.star,
                size: 13,
                color: AppColors.mustardDark,
              ),
            ),
          Text(
            '${day.day}',
            style: AppTextStyles.bodyMd.copyWith(
              color: textColor,
              fontWeight: isPerfect || isToday
                  ? FontWeight.w700
                  : FontWeight.w400,
            ),
          ),
        ],
      ),
    );

    if (!isTappable) return cell;

    return InkWell(
      onTap: () => onTap(date),
      borderRadius: BorderRadius.circular(AppRadius.sm * 0.55),
      child: cell,
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({
    required this.color,
    required this.borderColor,
    required this.label,
  });

  final Color color;
  final Color borderColor;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: borderColor, width: AppBorder.thin),
          ),
        ),
        const SizedBox(width: AppSpacing.unit),
        Text(label, style: AppTextStyles.labelSm),
      ],
    );
  }
}

/// Bottom sheet for one calendar day's habits — the tap target for a day
/// cell. Goes through the same `getHabitsForDate`/`*ForDate` calls as the
/// habits screen's back/forward arrows, so a day looks identical however
/// you reached it.
class _DayDetailSheet extends StatefulWidget {
  const _DayDetailSheet({required this.date});

  final DateTime date;

  @override
  State<_DayDetailSheet> createState() => _DayDetailSheetState();
}

class _DayDetailSheetState extends State<_DayDetailSheet> {
  List<Habit>? _habits;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final habits = await AppData.habits.getHabitsForDate(widget.date);
    if (!mounted) return;
    setState(() => _habits = habits);
  }

  Future<void> _applyReward(HabitRewardResult reward) async {
    if (reward.xpDelta == 0 && reward.coinsDelta == 0) return;
    if (reward.xpDelta != 0) await AppData.user.addXp(reward.xpDelta);
    if (reward.coinsDelta != 0) await AppData.user.addCoins(reward.coinsDelta);
    final user = await AppData.user.getCurrentUser();
    final previousStage = (await AppData.pet.getPet()).stage;
    await AppData.pet.syncEvolution(user.level);
    final pet = await AppData.pet.getPet();
    if (!mounted) return;
    if (previousStage != pet.stage) {
      await showEvolutionCelebration(context, petName: pet.name, stage: pet.stage);
    }
  }

  Future<void> _toggleBinary(Habit habit, bool completed) async {
    final reward = await AppData.habits.setHabitCompletedForDate(
      habit.id,
      widget.date,
      completed,
    );
    await _applyReward(reward);
    await _reload();
  }

  Future<void> _logProgress(Habit habit, double amount) async {
    await AppData.habits.logProgressForDate(habit.id, widget.date, amount);
    await _reload();
  }

  Future<void> _claim(Habit habit) async {
    final reward = await AppData.habits.claimHabitForDate(habit.id, widget.date);
    await _applyReward(reward);
    await _reload();
  }

  Future<void> _unclaim(Habit habit) async {
    final reward = await AppData.habits.unclaimHabitForDate(
      habit.id,
      widget.date,
    );
    await _applyReward(reward);
    await _reload();
  }

  Future<void> _editProgress(Habit habit, double value) async {
    if (habit.isCompletedToday) {
      final reward = await AppData.habits.unclaimHabitForDate(
        habit.id,
        widget.date,
      );
      await _applyReward(reward);
    }
    await AppData.habits.setProgressForDate(habit.id, widget.date, value);
    await _reload();
  }

  Future<void> _editHabitDefinition(Habit habit) async {
    await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute(builder: (_) => AddHabitScreen(habit: habit)));
    await _reload();
  }

  String get _title {
    final date = widget.date;
    return '${weekdayFull(date.weekday)}, ${monthFull(date.month)} ${date.day}';
  }

  @override
  Widget build(BuildContext context) {
    final habits = _habits;
    return DraggableScrollableSheet(
      initialChildSize: 0.62,
      minChildSize: 0.35,
      maxChildSize: 0.92,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(AppRadius.md),
            ),
            border: Border(
              top: BorderSide(color: AppColors.ink, width: AppBorder.standard),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.gutter,
            AppSpacing.stackSm,
            AppSpacing.gutter,
            AppSpacing.gutter,
          ),
          child: habits == null
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  controller: scrollController,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: AppSpacing.stackMd),
                        decoration: BoxDecoration(
                          color: AppColors.linenAlt,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Text(_title, style: AppTextStyles.headlineMd),
                    const SizedBox(height: AppSpacing.unit),
                    Text(
                      'You can still log or edit this day.',
                      style: AppTextStyles.bodyMd.copyWith(
                        color: AppColors.inkFaint,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.stackMd),
                    if (habits.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.stackMd,
                        ),
                        child: Text(
                          'No habits were scheduled that day.',
                          textAlign: TextAlign.center,
                          style: AppTextStyles.bodyMd.copyWith(
                            color: AppColors.inkFaint,
                          ),
                        ),
                      )
                    else
                      for (final habit in habits) ...[
                        HabitProgressCard(
                          habit: habit,
                          onToggleBinary: (completed) =>
                              _toggleBinary(habit, completed),
                          onLogProgress: (amount) => _logProgress(habit, amount),
                          onClaim: () => _claim(habit),
                          onUnclaim: () => _unclaim(habit),
                          onEditHabit: () => _editHabitDefinition(habit),
                          onEditProgress: (value) => _editProgress(habit, value),
                        ),
                        const SizedBox(height: AppSpacing.stackSm),
                      ],
                  ],
                ),
        );
      },
    );
  }
}
