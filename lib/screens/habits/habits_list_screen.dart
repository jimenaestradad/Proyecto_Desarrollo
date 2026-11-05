import 'package:flutter/material.dart';
import 'package:nori/data/app_data.dart';
import 'package:nori/data/habit_history_store.dart' show addDays, dateOnly;
import 'package:nori/data/habit_repository.dart';
import 'package:nori/models/app_notification.dart';
import 'package:nori/models/habit.dart';
import 'package:nori/models/nori_user.dart';
import 'package:nori/screens/bucket_list/bucket_list_screen.dart';
import 'package:nori/screens/habits/add_habit_screen.dart';
import 'package:nori/screens/habits/archived_habits_screen.dart';
import 'package:nori/screens/habits/habit_day_actions.dart';
import 'package:nori/screens/notifications/notifications_screen.dart';
import 'package:nori/theme/app_theme.dart';
import 'package:nori/data/tips_store.dart';
import 'package:nori/utils/date_labels.dart';
import 'package:nori/utils/remote_errors.dart';
import 'package:nori/widgets/circular_icon_button.dart';
import 'package:nori/widgets/habit_progress_card.dart';
import 'package:nori/widgets/load_error_view.dart';
import 'package:nori/widgets/nori_card.dart';
import 'package:nori/widgets/nori_scroll_scaffold.dart';
import 'package:nori/widgets/one_time_hint.dart';
import 'package:nori/widgets/progress_bar_pill.dart';
import 'package:nori/widgets/streak_chip.dart';
import 'package:nori/widgets/tactile_button.dart';
import 'package:nori/widgets/xp_pill.dart';

class HabitsListScreen extends StatefulWidget {
  const HabitsListScreen({
    super.key,
    required this.active,
    required this.onOpenHome,
  });

  /// See [HomeScreen.active] — same [IndexedStack] staleness problem, same
  /// fix: reload on the false→true transition.
  final bool active;

  /// Switches the shell to the Home tab, where pet care lives — for a
  /// notification's "Take care" button.
  final VoidCallback onOpenHome;

  @override
  State<HabitsListScreen> createState() => _HabitsListScreenState();
}

class _HabitsListScreenState extends State<HabitsListScreen>
    with RemoteLoadState<HabitsListScreen>, HabitDayActions<HabitsListScreen> {
  // Created once: a new stream per build would resubscribe every rebuild.
  late final Stream<bool> _hasUnreadNotifications = AppData.notifications
      .watchHasUnread();
  NoriUser? _user;
  List<Habit>? _habits;

  /// Habits that are active today but not due today (a Mon/Wed/Fri habit on
  /// a Tuesday). Only loaded when viewing today; listed in their own section
  /// so every habit is reachable from this tab, but kept out of the day's
  /// "x / y Completed" count.
  List<Habit> _notDueToday = const [];
  bool _completedToBottom = false;

  /// True while a long-press has put the list into drag-reorder mode —
  /// handles only render then, instead of always being present.
  bool _reordering = false;

  /// The day being viewed. Defaults to today; the back/forward arrows step
  /// this one day at a time so the same screen doubles as a history browser
  /// — see [AppData.habits]'s `*ForDate` methods, which this always goes
  /// through (today included, where they just delegate to the plain ones).
  DateTime _selectedDate = dateOnly(DateTime.now());

  bool get _isToday => _selectedDate == dateOnly(DateTime.now());

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void didUpdateWidget(covariant HabitsListScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.active && widget.active) _loadData();
  }

  Future<void> _loadData() => guardedLoad(_fetchData, hasData: _habits != null);

  /// The habits due on [date], plus (for today only) the active ones that
  /// aren't due.
  Future<(List<Habit>, List<Habit>)> _loadDay(DateTime date) async {
    final isToday = date == dateOnly(DateTime.now());
    final (due, active) = await (
      AppData.habits.getHabitsForDate(date),
      isToday ? AppData.habits.getTodayHabits() : Future.value(<Habit>[]),
    ).wait;
    final dueIds = {for (final habit in due) habit.id};
    return (
      due,
      [
        for (final habit in active)
          if (!dueIds.contains(habit.id)) habit,
      ],
    );
  }

  Future<void> _fetchData() async {
    final date = _selectedDate;
    final (user, day) = await (
      AppData.user.getCurrentUser(),
      _loadDay(date),
    ).wait;
    if (!mounted) return;
    setState(() {
      _user = user;
      // Dropped if the user has moved to another day meanwhile — that
      // day's own load owns the list now.
      if (date == _selectedDate) {
        _habits = day.$1;
        _notDueToday = day.$2;
      }
    });
  }

  Future<void> _reloadHabits() async {
    final date = _selectedDate;
    final day = await _loadDay(date);
    if (!mounted || date != _selectedDate) return;
    setState(() {
      _habits = day.$1;
      _notDueToday = day.$2;
    });
  }

  /// Steps the viewed day by [deltaDays]. Clamped so it can't go past today
  /// — there's nothing to show for a future day. The previous day's cards
  /// are cleared while the new day loads, so they can't be tapped and have
  /// the action land on the newly selected date.
  void _changeDate(int deltaDays) {
    final next = addDays(_selectedDate, deltaDays);
    if (next.isAfter(dateOnly(DateTime.now()))) return;
    setState(() {
      _selectedDate = next;
      _habits = null;
      _notDueToday = const [];
    });
    guardedLoad(_reloadHabits, hasData: false);
  }

  @override
  DateTime get actionDate => _selectedDate;

  @override
  Future<void> reloadActionHabits() => _reloadHabits();

  /// The user badge (level, XP, coins) changes with a paying claim.
  @override
  Future<NoriUser?> onRewardApplied(HabitRewardResult reward) async {
    final user = await AppData.user.getCurrentUser();
    if (!mounted) return user;
    setState(() => _user = user);
    return user;
  }

  Future<void> _openAddHabit() async {
    final added = await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute(builder: (_) => const AddHabitScreen()));
    if (!mounted) return;
    if (added == true) await guardedAction(_reloadHabits);
  }

  Future<void> _openEditHabit(Habit habit) async {
    final edited = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => AddHabitScreen(habit: habit)),
    );
    if (!mounted) return;
    if (edited == true) await guardedAction(_reloadHabits);
  }

  Future<void> _onReorder(int oldIndex, int newIndex) async {
    final habits = List<Habit>.from(_habits!);
    if (newIndex > oldIndex) newIndex -= 1;
    final habit = habits.removeAt(oldIndex);
    habits.insert(newIndex, habit);
    // Persist before updating the displayed order — on failure (once a real
    // backend can fail) the UI simply doesn't move instead of silently
    // diverging from what's actually stored.
    final ok = await guardedAction(
      () => AppData.habits.reorderHabits([for (final h in habits) h.id]),
    );
    if (!ok || !mounted) return;
    setState(() => _habits = habits);
  }

  Future<void> _openNotifications() async {
    final action = await Navigator.of(context).push<NotificationAction>(
      MaterialPageRoute(builder: (_) => const NotificationsScreen()),
    );
    if (!mounted) return;
    switch (action) {
      case NotificationAction.carePet:
        widget.onOpenHome();
      case null:
        break;
    }
  }

  Future<void> _openArchived() async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const ArchivedHabitsScreen()),
    );
    if (!mounted) return;
    if (changed == true) await guardedAction(_reloadHabits);
  }

  void _openBucketList() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const BucketListScreen()));
  }

  /// Display-only re-sort (completed habits last) used while
  /// [_completedToBottom] is on — the stored order (used for drag-reorder)
  /// is untouched.
  List<Habit> _sortedForDisplay(List<Habit> habits) => [
    for (final h in habits)
      if (!h.isCompletedToday) h,
    for (final h in habits)
      if (h.isCompletedToday) h,
  ];

  @override
  Widget build(BuildContext context) {
    final user = _user;
    final habits = _habits;
    final error = loadError;

    return Scaffold(
      body: SafeArea(
        child: user == null || habits == null
            ? error != null
                  ? LoadErrorView(error: error, onRetry: _loadData)
                  : const Center(child: CircularProgressIndicator())
            : _buildContent(user, habits),
      ),
    );
  }

  Widget _buildContent(NoriUser user, List<Habit> habits) {
    final completedCount = habits
        .where((habit) => habit.isCompletedToday)
        .length;
    final completion = habits.isEmpty ? 0.0 : completedCount / habits.length;
    final displayHabits = _completedToBottom
        ? _sortedForDisplay(habits)
        : habits;
    // Drag-reorder persists a global order, which doesn't make sense to
    // trigger from a past day's read-only-ish view — history still falls
    // back to the plain sorted list.
    final canReorder = _isToday;

    return NoriScrollScaffold(
      maxWidth: 1200,
      children: [
        Row(
          children: [
            Expanded(child: Text('Habits', style: AppTextStyles.headlineMd)),
            CircularIconButton(
              icon: Icons.inventory_2_outlined,
              tooltip: 'Archived Habits',
              onPressed: _openArchived,
            ),
            const SizedBox(width: 6),
            CircularIconButton(
              icon: Icons.flag,
              tooltip: 'Bucket List',
              onPressed: _openBucketList,
            ),
            const SizedBox(width: 6),
            StreamBuilder<bool>(
              stream: _hasUnreadNotifications,
              builder: (context, snapshot) {
                final hasUnread = snapshot.data ?? false;
                return CircularIconButton(
                  icon: Icons.notifications,
                  tooltip: hasUnread
                      ? 'Notifications (unread)'
                      : 'Notifications',
                  onPressed: _openNotifications,
                  showDot: hasUnread,
                );
              },
            ),
            const SizedBox(width: 8),
            if (user.currentStreak > 0) ...[
              StreakChip(streak: user.currentStreak),
              const SizedBox(width: 4),
            ],
            XpPill(xp: user.totalXp),
          ],
        ),
        const SizedBox(height: AppSpacing.stackLg),
        _DateNavRow(
          date: _selectedDate,
          canGoForward: !_isToday,
          onBack: () => _changeDate(-1),
          onForward: () => _changeDate(1),
          onJumpToToday: () {
            setState(() => _selectedDate = dateOnly(DateTime.now()));
            _loadData();
          },
        ),
        const SizedBox(height: AppSpacing.unit),
        Text(
          _isToday
              ? 'Keep up the good work!'
              : "You're viewing a past day — you can still log or edit it.",
          style: AppTextStyles.bodyMd.copyWith(color: AppColors.inkFaint),
        ),
        const SizedBox(height: AppSpacing.stackMd),
        Row(
          children: [
            Text(
              'Completed to bottom',
              style: AppTextStyles.labelSm.copyWith(color: AppColors.inkFaint),
            ),
            Switch(
              value: _completedToBottom,
              onChanged: (value) => setState(() => _completedToBottom = value),
              activeThumbColor: AppColors.white,
              activeTrackColor: AppColors.moss,
              inactiveThumbColor: AppColors.white,
              inactiveTrackColor: AppColors.linenAlt,
            ),
            const Spacer(),
            Text(
              '$completedCount / ${habits.length} Completed',
              style: AppTextStyles.labelLg.copyWith(
                color: AppColors.terracottaDark,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.unit),
        ProgressBarPill(progress: completion, color: AppColors.terracotta),
        const SizedBox(height: AppSpacing.stackMd),
        if (habits.isNotEmpty)
          const OneTimeHint(
            tip: Tip.habitsGestures,
            icon: Icons.touch_app,
            message:
                'Tap a number to edit progress. Long-press a card to '
                'reorder.',
          ),
        if (habits.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.stackMd),
            child: Text(
              _isToday
                  ? 'No habits scheduled for today.'
                  : 'No habits were scheduled that day.',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMd.copyWith(color: AppColors.inkFaint),
            ),
          )
        else if (!(_reordering && canReorder && !_completedToBottom))
          for (final habit in displayHabits) ...[
            GestureDetector(
              onLongPress: (canReorder && !_completedToBottom)
                  ? () => setState(() => _reordering = true)
                  : null,
              child: HabitProgressCard(
                habit: habit,
                onToggleBinary: (completed) => toggleBinary(habit, completed),
                onLogProgress: (amount) => logProgress(habit, amount),
                onClaim: () => claim(habit),
                onUnclaim: () => unclaim(habit),
                onEditHabit: () => _openEditHabit(habit),
                onEditProgress: (value) => editProgress(habit, value),
              ),
            ),
            if (habit != displayHabits.last)
              const SizedBox(height: AppSpacing.stackSm),
          ]
        else ...[
          Row(
            children: [
              const Icon(
                Icons.drag_indicator,
                size: 16,
                color: AppColors.inkFaint,
              ),
              const SizedBox(width: 4),
              Text(
                'Drag to reorder',
                style: AppTextStyles.labelSm.copyWith(
                  color: AppColors.inkFaint,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => setState(() => _reordering = false),
                child: const Text('Done'),
              ),
            ],
          ),
          ReorderableListView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            onReorder: _onReorder,
            children: [
              for (var index = 0; index < habits.length; index++)
                Padding(
                  key: ValueKey(habits[index].id),
                  padding: const EdgeInsets.only(bottom: AppSpacing.stackSm),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ReorderableDragStartListener(
                        index: index,
                        child: const Padding(
                          padding: EdgeInsets.only(top: 14, right: 4),
                          child: Icon(
                            Icons.drag_indicator,
                            color: AppColors.inkFaint,
                          ),
                        ),
                      ),
                      Expanded(
                        child: HabitProgressCard(
                          habit: habits[index],
                          onToggleBinary: (completed) =>
                              toggleBinary(habits[index], completed),
                          onLogProgress: (amount) =>
                              logProgress(habits[index], amount),
                          onClaim: () => claim(habits[index]),
                          onUnclaim: () => unclaim(habits[index]),
                          onEditHabit: () => _openEditHabit(habits[index]),
                          onEditProgress: (value) =>
                              editProgress(habits[index], value),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
        if (_notDueToday.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.stackLg),
          _NotDueTodaySection(habits: _notDueToday, onEdit: _openEditHabit),
        ],
        const SizedBox(height: AppSpacing.stackMd),
        TactileButton(
          label: 'Add New Habit',
          icon: Icons.add,
          // A new habit belongs to today, not whatever past day is on
          // screen — jump back to add one.
          onPressed: _isToday ? _openAddHabit : null,
        ),
        if (!_isToday) ...[
          const SizedBox(height: AppSpacing.unit),
          Text(
            'Jump to Today to add a new habit.',
            textAlign: TextAlign.center,
            style: AppTextStyles.labelSm.copyWith(color: AppColors.inkFaint),
          ),
        ],
      ],
    );
  }
}

/// Habits that are active but not scheduled today. Read-only rows (nothing to
/// log until their day comes) that open the same edit screen, so every habit
/// can still be found, edited or archived from this tab.
class _NotDueTodaySection extends StatelessWidget {
  const _NotDueTodaySection({required this.habits, required this.onEdit});

  final List<Habit> habits;
  final ValueChanged<Habit> onEdit;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Not due today', style: AppTextStyles.labelLg),
        const SizedBox(height: 2),
        Text(
          'Scheduled for other days, so they don\'t count toward today.',
          style: AppTextStyles.bodyMd.copyWith(color: AppColors.inkFaint),
        ),
        const SizedBox(height: AppSpacing.stackSm),
        for (final habit in habits) ...[
          NoriCard(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.gutter,
              vertical: AppSpacing.unit * 2,
            ),
            color: AppColors.linen,
            borderWidth: AppBorder.thin,
            child: Row(
              children: [
                Icon(habit.icon, color: AppColors.inkFaint),
                const SizedBox(width: AppSpacing.gutter),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(habit.name, style: AppTextStyles.labelLg),
                      Text(
                        habit.scheduleLabel,
                        style: AppTextStyles.labelSm.copyWith(
                          color: AppColors.inkFaint,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Edit ${habit.name}',
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => onEdit(habit),
                ),
              ],
            ),
          ),
          if (habit != habits.last) const SizedBox(height: AppSpacing.stackSm),
        ],
      ],
    );
  }
}

/// Back/forward day-stepper above the habit list, plus the day's label.
/// Doubles as the entry point into history — every arrow tap re-fetches
/// through [HabitRepository.getHabitsForDate], so this is the same data
/// path the calendar's day-detail sheet uses.
class _DateNavRow extends StatelessWidget {
  const _DateNavRow({
    required this.date,
    required this.canGoForward,
    required this.onBack,
    required this.onForward,
    required this.onJumpToToday,
  });

  final DateTime date;
  final bool canGoForward;
  final VoidCallback onBack;
  final VoidCallback onForward;
  final VoidCallback onJumpToToday;

  String get _label {
    final today = dateOnly(DateTime.now());
    final diff = today.difference(date).inDays;
    if (diff == 0) return "Today's Goals";
    if (diff == 1) return "Yesterday's Goals";
    return '${weekdayAbbr(date.weekday)}, ${monthAbbr(date.month)} ${date.day}';
  }

  @override
  Widget build(BuildContext context) {
    final isToday = !canGoForward;
    return Row(
      children: [
        _DateArrowButton(
          icon: Icons.chevron_left,
          tooltip: 'Previous day',
          onPressed: onBack,
        ),
        Expanded(
          child: Text(
            _label,
            textAlign: TextAlign.center,
            style: AppTextStyles.headlineLgMobile,
          ),
        ),
        _DateArrowButton(
          icon: Icons.chevron_right,
          tooltip: 'Next day',
          onPressed: canGoForward ? onForward : null,
        ),
        if (!isToday) ...[
          const SizedBox(width: AppSpacing.unit),
          IconButton(
            tooltip: 'Jump to today',
            onPressed: onJumpToToday,
            icon: const Icon(Icons.today, color: AppColors.inkFaint),
          ),
        ],
      ],
    );
  }
}

class _DateArrowButton extends StatelessWidget {
  const _DateArrowButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(
        icon,
        color: onPressed == null ? AppColors.inkFaint : AppColors.ink,
      ),
    );
  }
}
