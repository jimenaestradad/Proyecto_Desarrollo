import 'package:flutter/material.dart';
import 'package:nori/data/app_data.dart';
import 'package:nori/data/habit_history_store.dart' show dateOnly;
import 'package:nori/data/habit_repository.dart';
import 'package:nori/models/habit.dart';
import 'package:nori/models/nori_user.dart';
import 'package:nori/navigation/reloadable.dart';
import 'package:nori/screens/habits/add_habit_screen.dart';
import 'package:nori/theme/app_theme.dart';
import 'package:nori/widgets/habit_progress_card.dart';
import 'package:nori/widgets/progress_bar_pill.dart';
import 'package:nori/widgets/tactile_button.dart';
import 'package:nori/widgets/xp_pill.dart';

class HabitsListScreen extends StatefulWidget {
  const HabitsListScreen({super.key});

  @override
  State<HabitsListScreen> createState() => _HabitsListScreenState();
}

class _HabitsListScreenState extends State<HabitsListScreen>
    implements Reloadable {
  NoriUser? _user;
  List<Habit>? _habits;
  bool _completedToBottom = false;

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
  Future<void> reload() => _loadData();

  Future<void> _loadData() async {
    final user = await AppData.user.getCurrentUser();
    final habits = await AppData.habits.getHabitsForDate(_selectedDate);
    if (!mounted) return;
    setState(() {
      _user = user;
      _habits = habits;
    });
  }

  Future<void> _reloadHabits() async {
    final habits = await AppData.habits.getHabitsForDate(_selectedDate);
    if (!mounted) return;
    setState(() => _habits = habits);
  }

  /// Steps the viewed day by [deltaDays]. Clamped so it can't go past today
  /// — there's nothing to show for a future day.
  void _changeDate(int deltaDays) {
    final next = _selectedDate.add(Duration(days: deltaDays));
    if (next.isAfter(dateOnly(DateTime.now()))) return;
    setState(() => _selectedDate = next);
    _loadData();
  }

  Future<void> _reloadUser() async {
    final user = await AppData.user.getCurrentUser();
    if (!mounted) return;
    setState(() => _user = user);
  }

  Future<void> _applyReward(HabitRewardResult reward) async {
    if (reward.xpDelta == 0 && reward.coinsDelta == 0) return;
    if (reward.xpDelta != 0) await AppData.user.addXp(reward.xpDelta);
    if (reward.coinsDelta != 0) await AppData.user.addCoins(reward.coinsDelta);
    final user = await AppData.user.getCurrentUser();
    await AppData.pet.syncEvolution(user.level);
    await _reloadUser();
  }

  Future<void> _toggleBinary(Habit habit, bool completed) async {
    final reward = await AppData.habits.setHabitCompletedForDate(
      habit.id,
      _selectedDate,
      completed,
    );
    await _applyReward(reward);
    await _reloadHabits();
  }

  Future<void> _logProgress(Habit habit, double amount) async {
    await AppData.habits.logProgressForDate(habit.id, _selectedDate, amount);
    await _reloadHabits();
  }

  Future<void> _claim(Habit habit) async {
    final reward = await AppData.habits.claimHabitForDate(
      habit.id,
      _selectedDate,
    );
    await _applyReward(reward);
    await _reloadHabits();
  }

  /// Reverses the viewed day's claim (reward included) without touching the
  /// logged value — the claim button turns into this once a habit is
  /// completed.
  Future<void> _unclaim(Habit habit) async {
    final reward = await AppData.habits.unclaimHabitForDate(
      habit.id,
      _selectedDate,
    );
    await _applyReward(reward);
    await _reloadHabits();
  }

  /// Un-claims first (reversing the viewed day's reward) whenever the habit
  /// was already completed, then applies the new absolute value — powers the
  /// progress-card's tap-to-edit / undo / reset-to-0 dialog.
  Future<void> _editProgress(Habit habit, double value) async {
    if (habit.isCompletedToday) {
      final reward = await AppData.habits.unclaimHabitForDate(
        habit.id,
        _selectedDate,
      );
      await _applyReward(reward);
    }
    await AppData.habits.setProgressForDate(habit.id, _selectedDate, value);
    await _reloadHabits();
  }

  Future<void> _openAddHabit() async {
    final added = await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute(builder: (_) => const AddHabitScreen()));
    if (!mounted) return;
    if (added == true) await _reloadHabits();
  }

  Future<void> _openEditHabit(Habit habit) async {
    final edited = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => AddHabitScreen(habit: habit)),
    );
    if (!mounted) return;
    if (edited == true) await _reloadHabits();
  }

  Future<void> _onReorder(int oldIndex, int newIndex) async {
    final habits = List<Habit>.from(_habits!);
    if (newIndex > oldIndex) newIndex -= 1;
    final habit = habits.removeAt(oldIndex);
    habits.insert(newIndex, habit);
    setState(() => _habits = habits);
    await AppData.habits.reorderHabits([for (final h in habits) h.id]);
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

    return Scaffold(
      body: SafeArea(
        child: user == null || habits == null
            ? const Center(child: CircularProgressIndicator())
            : LayoutBuilder(
                builder: (context, constraints) {
                  final horizontalPadding = constraints.maxWidth >= 800
                      ? AppSpacing.containerPaddingDesktop
                      : AppSpacing.containerPaddingMobile;
                  final completedCount = habits
                      .where((habit) => habit.isCompletedToday)
                      .length;
                  final completion = habits.isEmpty
                      ? 0.0
                      : completedCount / habits.length;
                  final displayHabits = _completedToBottom
                      ? _sortedForDisplay(habits)
                      : habits;
                  // Drag-reorder persists a global order, which doesn't make
                  // sense to trigger from a past day's read-only-ish view —
                  // history still falls back to the plain sorted list.
                  final canReorder = _isToday;

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
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'Nori',
                                    style: AppTextStyles.headlineMd,
                                  ),
                                ),
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
                                setState(
                                  () => _selectedDate = dateOnly(DateTime.now()),
                                );
                                _loadData();
                              },
                            ),
                            const SizedBox(height: AppSpacing.unit),
                            Text(
                              _isToday
                                  ? 'Keep up the good work! Your pet is happy.'
                                  : "You're viewing a past day — you can still log or edit it.",
                              style: AppTextStyles.bodyMd.copyWith(
                                color: AppColors.inkFaint,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.stackMd),
                            Row(
                              children: [
                                Icon(
                                  Icons.vertical_align_bottom,
                                  size: 16,
                                  color: AppColors.inkFaint,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Completed to bottom',
                                  style: AppTextStyles.labelSm.copyWith(
                                    color: AppColors.inkFaint,
                                  ),
                                ),
                                Switch(
                                  value: _completedToBottom,
                                  onChanged: (value) =>
                                      setState(() => _completedToBottom = value),
                                  materialTapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
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
                            ProgressBarPill(
                              progress: completion,
                              color: AppColors.terracotta,
                            ),
                            const SizedBox(height: AppSpacing.stackMd),
                            if (habits.isEmpty)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: AppSpacing.stackMd,
                                ),
                                child: Text(
                                  _isToday
                                      ? 'No habits scheduled for today.'
                                      : 'No habits were scheduled that day.',
                                  textAlign: TextAlign.center,
                                  style: AppTextStyles.bodyMd.copyWith(
                                    color: AppColors.inkFaint,
                                  ),
                                ),
                              )
                            else if (_completedToBottom || !canReorder)
                              for (final habit in displayHabits) ...[
                                HabitProgressCard(
                                  habit: habit,
                                  onToggleBinary: (completed) =>
                                      _toggleBinary(habit, completed),
                                  onLogProgress: (amount) =>
                                      _logProgress(habit, amount),
                                  onClaim: () => _claim(habit),
                                  onUnclaim: () => _unclaim(habit),
                                  onEditHabit: () => _openEditHabit(habit),
                                  onEditProgress: (value) =>
                                      _editProgress(habit, value),
                                ),
                                if (habit != displayHabits.last)
                                  const SizedBox(height: AppSpacing.stackSm),
                              ]
                            else
                              ReorderableListView(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                buildDefaultDragHandles: false,
                                onReorder: _onReorder,
                                children: [
                                  for (var index = 0; index < habits.length; index++)
                                    Padding(
                                      key: ValueKey(habits[index].id),
                                      padding: const EdgeInsets.only(
                                        bottom: AppSpacing.stackSm,
                                      ),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          ReorderableDragStartListener(
                                            index: index,
                                            child: const Padding(
                                              padding: EdgeInsets.only(
                                                top: 14,
                                                right: 4,
                                              ),
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
                                                  _toggleBinary(
                                                    habits[index],
                                                    completed,
                                                  ),
                                              onLogProgress: (amount) =>
                                                  _logProgress(
                                                    habits[index],
                                                    amount,
                                                  ),
                                              onClaim: () =>
                                                  _claim(habits[index]),
                                              onUnclaim: () =>
                                                  _unclaim(habits[index]),
                                              onEditHabit: () =>
                                                  _openEditHabit(habits[index]),
                                              onEditProgress: (value) =>
                                                  _editProgress(
                                                    habits[index],
                                                    value,
                                                  ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            const SizedBox(height: AppSpacing.stackMd),
                            TactileButton(
                              label: 'Add New Habit',
                              icon: Icons.add,
                              // A new habit belongs to today, not whatever
                              // past day is on screen — jump back to add one.
                              onPressed: _isToday ? _openAddHabit : null,
                            ),
                            if (!_isToday) ...[
                              const SizedBox(height: AppSpacing.unit),
                              Text(
                                'Jump to Today to add a new habit.',
                                textAlign: TextAlign.center,
                                style: AppTextStyles.labelSm.copyWith(
                                  color: AppColors.inkFaint,
                                ),
                              ),
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

  static const _weekdays = [
    'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun', //
  ];
  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  String get _label {
    final today = dateOnly(DateTime.now());
    final diff = today.difference(date).inDays;
    if (diff == 0) return "Today's Goals";
    if (diff == 1) return "Yesterday's Goals";
    return '${_weekdays[date.weekday - 1]}, ${_months[date.month - 1]} ${date.day}';
  }

  @override
  Widget build(BuildContext context) {
    final isToday = !canGoForward;
    return Row(
      children: [
        _DateArrowButton(icon: Icons.chevron_left, onPressed: onBack),
        Expanded(
          child: Text(
            _label,
            textAlign: TextAlign.center,
            style: AppTextStyles.headlineLgMobile,
          ),
        ),
        _DateArrowButton(
          icon: Icons.chevron_right,
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
  const _DateArrowButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      icon: Icon(
        icon,
        color: onPressed == null ? AppColors.inkFaint : AppColors.ink,
      ),
    );
  }
}
