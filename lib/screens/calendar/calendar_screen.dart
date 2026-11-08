import 'package:flutter/material.dart';
import 'package:nori/data/app_data.dart';
import 'package:nori/data/tips_store.dart';
import 'package:nori/models/calendar_day.dart';
import 'package:nori/models/habit.dart';
import 'package:nori/models/nori_user.dart';
import 'package:nori/screens/habits/add_habit_screen.dart';
import 'package:nori/screens/habits/habit_day_actions.dart';
import 'package:nori/theme/app_theme.dart';
import 'package:nori/utils/date_labels.dart';
import 'package:nori/utils/remote_errors.dart';
import 'package:nori/widgets/habit_progress_card.dart';
import 'package:nori/widgets/load_error_view.dart';
import 'package:nori/widgets/nori_avatar.dart';
import 'package:nori/widgets/nori_card.dart';
import 'package:nori/widgets/nori_screen_header.dart';
import 'package:nori/widgets/nori_scroll_scaffold.dart';
import 'package:nori/widgets/one_time_hint.dart';
import 'package:nori/widgets/streak_chip.dart';
import 'package:nori/widgets/xp_pill.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key, required this.active});

  /// See [HomeScreen.active] — same [IndexedStack] staleness fix.
  final bool active;

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen>
    with RemoteLoadState<CalendarScreen> {
  NoriUser? _user;

  /// Every month read so far, so stepping back to one shows it at once and
  /// refreshes it behind the scenes.
  final Map<int, CalendarMonthStats> _months = {};
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
    if (!oldWidget.active && widget.active) {
      // Show the newest XP/coins at once; the reload below still has the last word.
      _user = AppData.user.lastKnownUser ?? _user;
      _loadData();
    }
  }

  static int _monthKey(int year, int month) => year * 100 + month;

  /// The viewed month, or null while it is still being read.
  CalendarMonthStats? get _stats => _months[_monthKey(_year, _month)];

  Future<void> _loadData() =>
      guardedLoad(_fetchData, hasData: _user != null && _stats != null);

  Future<void> _fetchData() async {
    // Captured because the viewer may step to another month mid-fetch; this
    // result still belongs to the month it was asked for.
    final year = _year;
    final month = _month;
    final (user, stats) = await (
      AppData.user.getCurrentUser(),
      AppData.calendar.getMonth(year, month),
    ).wait;
    if (!mounted) return;
    setState(() {
      _user = user;
      _months[_monthKey(year, month)] = stats;
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
    final error = loadError;

    return Scaffold(
      body: SafeArea(
        child: user == null
            ? error != null
                  ? LoadErrorView(error: error, onRetry: _loadData)
                  : const Center(child: CircularProgressIndicator())
            : NoriScrollScaffold(
                maxWidth: 1200,
                children: [
                  _CalendarHeader(user: user),
                  const SizedBox(height: AppSpacing.stackLg),
                  Row(
                    children: [
                      IconButton(
                        tooltip: 'Previous month',
                        onPressed: () => _changeMonth(-1),
                        icon: const Icon(
                          Icons.chevron_left,
                          color: AppColors.ink,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          '${monthFull(_month)} $_year',
                          textAlign: TextAlign.center,
                          style: AppTextStyles.headlineLgMobile,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Next month',
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
                  const OneTimeHint(
                    tip: Tip.calendarDays,
                    icon: Icons.edit_calendar,
                    message: 'Tap a past day to log or edit its habits.',
                  ),
                  if (stats == null)
                    _MonthLoading(error: error, onRetry: _loadData)
                  else ...[
                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 2,
                      crossAxisSpacing: AppSpacing.gutter,
                      mainAxisSpacing: AppSpacing.gutter,
                      childAspectRatio: 1.7,
                      children: [
                        _CalendarStatCard(
                          icon: Icons.local_fire_department,
                          iconColor: AppColors.terracottaDark,
                          value: '${stats.currentStreak}',
                          label: 'Current streak',
                        ),
                        _CalendarStatCard(
                          icon: Icons.star,
                          iconColor: AppColors.mustardDark,
                          value: '${stats.perfectDays}',
                          label: 'Perfect days',
                        ),
                        _CalendarStatCard(
                          icon: Icons.check_circle,
                          iconColor: AppColors.mossDark,
                          value: '${stats.habitsDone}',
                          label: 'Habits done',
                        ),
                        _CalendarStatCard(
                          icon: Icons.event_busy,
                          iconColor: AppColors.inkMuted,
                          value: '${stats.missedDays}',
                          label: 'Missed days',
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.stackMd),
                    _CalendarCard(days: stats.days, onDayTap: _openDayDetail),
                  ],
                ],
              ),
      ),
    );
  }
}

/// Stands in for a month's stats and grid while it is being read, so the
/// month title and arrows stay put and respond to the tap.
class _MonthLoading extends StatelessWidget {
  const _MonthLoading({required this.error, required this.onRetry});

  /// Set when reading this month failed; shows a retry instead of spinning.
  final Object? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (error != null) {
      return SizedBox(
        height: 320,
        child: LoadErrorView(error: error!, onRetry: onRetry),
      );
    }
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: AppSpacing.stackLg * 2),
      child: Center(child: CircularProgressIndicator()),
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
      title: 'Calendar',
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
    return NoriCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.stackSm,
        vertical: AppSpacing.unit,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 26, color: iconColor),
          const SizedBox(width: AppSpacing.unit),
          Flexible(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: AppTextStyles.headlineMd),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.labelSm,
                ),
              ],
            ),
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
    return NoriCard(
      padding: const EdgeInsets.all(AppSpacing.gutter),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              for (
                var weekday = DateTime.monday;
                weekday <= DateTime.sunday;
                weekday++
              )
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
              for (final day in days)
                _CalendarDayCell(day: day, onTap: onDayTap),
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
              _LegendItem(
                color: AppColors.moss,
                borderColor: AppColors.ink,
                label: 'Today',
              ),
              _LegendItem(
                color: Colors.transparent,
                borderColor: AppColors.inkFaint,
                label: 'Upcoming',
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
      // Upcoming days sit on the page (no fill, faint outline) so they read
      // as "not yet" instead of as missed days, which used to differ from
      // them by ~1% of fill color (linenAlt vs linen).
      CalendarDayStatus.future => (
        Colors.transparent,
        AppColors.inkFaint,
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
              child: Icon(Icons.star, size: 13, color: AppColors.mustardDark),
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

class _DayDetailSheetState extends State<_DayDetailSheet>
    with
        RemoteLoadState<_DayDetailSheet>,
        OptimisticHabits<_DayDetailSheet>,
        HabitDayActions<_DayDetailSheet> {
  List<Habit>? _habits;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() => guardedLoad(_reload, hasData: _habits != null);

  Future<void> _reload() async {
    final stamp = editStamp;
    final habits = await AppData.habits.getHabitsForDate(widget.date);
    if (!mounted || stamp != editStamp) return;
    setState(() => _habits = habits);
  }

  @override
  DateTime get actionDate => widget.date;

  @override
  Future<void> reloadActionHabits() => _reload();

  @override
  Object? snapshotHabits() => _habits;

  @override
  void restoreHabitSnapshot(Object snapshot) =>
      _habits = snapshot as List<Habit>;

  @override
  void applyHabitChange(String habitId, Habit Function(Habit) change) {
    final habits = _habits;
    if (habits == null) return;
    setState(() {
      _habits = [for (final h in habits) h.id == habitId ? change(h) : h];
    });
  }

  Future<void> _editHabitDefinition(Habit habit) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => AddHabitScreen(habit: habit)),
    );
    await _load();
  }

  String get _title {
    final date = widget.date;
    return '${weekdayFull(date.weekday)}, ${monthFull(date.month)} ${date.day}';
  }

  @override
  Widget build(BuildContext context) {
    final habits = _habits;
    final error = loadError;
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
              ? error != null
                    ? LoadErrorView(error: error, onRetry: _load)
                    : const Center(child: CircularProgressIndicator())
              : ListView(
                  controller: scrollController,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(
                          bottom: AppSpacing.stackMd,
                        ),
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
                              toggleBinary(habit, completed),
                          onLogProgress: (amount) => logProgress(habit, amount),
                          onClaim: () => claim(habit),
                          onUnclaim: () => unclaim(habit),
                          onEditHabit: () => _editHabitDefinition(habit),
                          onEditProgress: (value) => editProgress(habit, value),
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
