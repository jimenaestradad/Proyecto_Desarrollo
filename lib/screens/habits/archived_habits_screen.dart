import 'package:flutter/material.dart';
import 'package:nori/data/app_data.dart';
import 'package:nori/data/habit_repository.dart' show kMaxDeletableActiveDays;
import 'package:nori/models/habit.dart';
import 'package:nori/theme/app_theme.dart';
import 'package:nori/utils/date_labels.dart';
import 'package:nori/utils/remote_errors.dart';
import 'package:nori/widgets/delete_habit_dialog.dart';
import 'package:nori/widgets/load_error_view.dart';
import 'package:nori/widgets/nori_card.dart';
import 'package:nori/widgets/nori_icon_badge.dart';
import 'package:nori/widgets/nori_screen_header.dart';
import 'package:nori/widgets/nori_scroll_scaffold.dart';
import 'package:nori/widgets/tactile_button.dart';

/// Every archived habit, with Restore (and Delete, for one with almost no
/// history). Pops `true` if anything changed, so the Habits list reloads.
/// See docs/BACKEND.md, "Deleting vs. archiving a habit".
class ArchivedHabitsScreen extends StatefulWidget {
  const ArchivedHabitsScreen({super.key});

  @override
  State<ArchivedHabitsScreen> createState() => _ArchivedHabitsScreenState();
}

class _ArchivedHabitsScreenState extends State<ArchivedHabitsScreen>
    with RemoteLoadState<ArchivedHabitsScreen> {
  List<Habit>? _habits;

  /// habitId → days with activity, for deciding whether Delete shows.
  Map<String, int> _activeDays = const {};
  bool _changed = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() => guardedLoad(_fetch, hasData: _habits != null);

  Future<void> _fetch() async {
    final habits = await AppData.habits.getArchivedHabits();
    final counts = await Future.wait([
      for (final habit in habits) AppData.habits.activeDayCount(habit.id),
    ]);
    if (!mounted) return;
    setState(() {
      _habits = habits;
      _activeDays = {
        for (var i = 0; i < habits.length; i++) habits[i].id: counts[i],
      };
    });
  }

  Future<void> _restore(Habit habit) async {
    setState(() => _busy = true);
    final ok = await guardedAction(() async {
      await AppData.habits.restoreHabit(habit.id);
      await _fetch();
    });
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (ok) _changed = true;
    });
    if (ok) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('Restored "${habit.name}".')));
    }
  }

  Future<void> _delete(Habit habit) async {
    if (!await confirmDeleteHabit(context, habit) || !mounted) return;
    setState(() => _busy = true);
    final ok = await guardedAction(() async {
      await AppData.habits.deleteHabit(habit.id);
      await _fetch();
    });
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (ok) _changed = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final habits = _habits;
    final error = loadError;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.pop(context, _changed);
      },
      child: Scaffold(
        body: SafeArea(
          child: NoriScrollScaffold(
            maxWidth: 800,
            children: [
              NoriScreenHeader(
                leading: NoriScreenHeader.backButton(context),
                title: 'Archived Habits',
                titleStyle: AppTextStyles.headlineLgMobile,
              ),
              const SizedBox(height: AppSpacing.stackMd),
              if (habits == null && error != null)
                LoadErrorView(error: error, onRetry: _loadData)
              else if (habits == null)
                const Padding(
                  padding: EdgeInsets.all(AppSpacing.stackLg),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (habits.isEmpty)
                const _EmptyArchive()
              else
                for (final habit in habits) ...[
                  _ArchivedHabitCard(
                    habit: habit,
                    canDelete:
                        (_activeDays[habit.id] ??
                            kMaxDeletableActiveDays + 1) <=
                        kMaxDeletableActiveDays,
                    busy: _busy,
                    onRestore: () => _restore(habit),
                    onDelete: () => _delete(habit),
                  ),
                  const SizedBox(height: AppSpacing.unit),
                ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ArchivedHabitCard extends StatelessWidget {
  const _ArchivedHabitCard({
    required this.habit,
    required this.canDelete,
    required this.busy,
    required this.onRestore,
    required this.onDelete,
  });

  final Habit habit;
  final bool canDelete;
  final bool busy;
  final VoidCallback onRestore;
  final VoidCallback onDelete;

  /// "Archived Sep 30", from the habit's still-open archived stretch.
  String? get _archivedLabel {
    for (final range in habit.archivedRanges.reversed) {
      if (range.end != null) continue;
      final day = DateTime.tryParse(range.start);
      if (day == null) return null;
      return 'Archived ${monthAbbr(day.month)} ${day.day}';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final label = _archivedLabel;
    return NoriCard(
      padding: const EdgeInsets.all(AppSpacing.gutter),
      child: Row(
        children: [
          NoriIconBadge(
            icon: habit.icon,
            background: habit.color,
            size: 44,
            iconSize: 22,
          ),
          const SizedBox(width: AppSpacing.gutter),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  habit.name,
                  style: AppTextStyles.labelLg,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (label != null)
                  Text(
                    label,
                    style: AppTextStyles.bodyMd.copyWith(
                      color: AppColors.inkMuted,
                    ),
                  ),
              ],
            ),
          ),
          if (canDelete)
            IconButton(
              tooltip: 'Delete',
              icon: const Icon(Icons.delete_outline),
              color: AppColors.onErrorContainer,
              onPressed: busy ? null : onDelete,
            ),
          TactileButton(
            label: 'Restore',
            icon: Icons.unarchive_outlined,
            expand: false,
            backgroundColor: AppColors.mossLight,
            onPressed: busy ? null : onRestore,
          ),
        ],
      ),
    );
  }
}

class _EmptyArchive extends StatelessWidget {
  const _EmptyArchive();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.stackLg),
      child: Column(
        children: [
          const Icon(
            Icons.inventory_2_outlined,
            size: 48,
            color: AppColors.inkMuted,
          ),
          const SizedBox(height: AppSpacing.stackSm),
          Text(
            'No archived habits. Archiving a habit hides it from today on '
            'and keeps its history.',
            style: AppTextStyles.bodyLg.copyWith(color: AppColors.inkMuted),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
