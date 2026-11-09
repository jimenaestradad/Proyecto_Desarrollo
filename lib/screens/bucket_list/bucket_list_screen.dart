import 'package:flutter/material.dart';
import 'package:nori/data/app_data.dart';
import 'package:nori/data/cloud_functions_client.dart';
import 'package:nori/models/bucket_list_item.dart';
import 'package:nori/theme/app_theme.dart';
import 'package:nori/utils/id_generator.dart';
import 'package:nori/utils/ordered_queue.dart';
import 'package:nori/utils/remote_errors.dart';
import 'package:nori/widgets/load_error_view.dart';
import 'package:nori/widgets/nori_card.dart';
import 'package:nori/widgets/nori_icon_badge.dart';
import 'package:nori/widgets/nori_screen_header.dart';
import 'package:nori/widgets/nori_scroll_scaffold.dart';
import 'package:nori/widgets/reward_pill.dart';
import 'package:nori/widgets/tactile_button.dart';

/// One-time major life goals — see docs/product/FEATURES.md §11. Reached from the
/// Habits screen topbar, not the bottom nav: distinct from the daily habit
/// list, but not important enough to compete for a nav slot.
class BucketListScreen extends StatefulWidget {
  const BucketListScreen({super.key});

  @override
  State<BucketListScreen> createState() => _BucketListScreenState();
}

class _BucketListScreenState extends State<BucketListScreen>
    with RemoteLoadState<BucketListScreen> {
  List<BucketListItem>? _items;

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  Future<void> _loadItems() =>
      guardedLoad(_fetchItems, hasData: _items != null);

  Future<void> _fetchItems() async {
    final stamp = _edits;
    final items = await AppData.bucketList.getItems();
    if (!mounted || stamp != _edits) return;
    // Once the list shows the goal, the add did land; adding the same goal
    // again is then deliberate and gets a new id.
    if (items.any((item) => item.id == _unconfirmedAdd?.id)) {
      _unconfirmedAdd = null;
    }
    setState(() => _items = items);
  }

  /// The last goal whose add didn't report success (it timed out or failed).
  /// A timed-out write can still commit, so adding the same goal again reuses
  /// this id and overwrites that one document instead of creating a twin.
  BucketListItem? _unconfirmedAdd;

  int _pending = 0;
  int _edits = 0;

  /// The list before the first change now in flight; a failed call puts it
  /// back at once, so the undo doesn't depend on the re-read (which fails
  /// too when the server is unreachable). Dropped once nothing is in flight.
  List<BucketListItem>? _baseline;

  /// Server calls run in the order they were made, so an edit or delete never
  /// overtakes the add it depends on.
  final _serverQueue = OrderedQueue();

  /// Shows a change on the list at once and runs [server] in the background.
  /// A failure, or the last change finishing, re-reads the list (the server
  /// owns reward state, ids and ordering).
  Future<void> _optimistic(
    List<BucketListItem> Function(List<BucketListItem>) change,
    Future<void> Function() server,
  ) async {
    final items = _items;
    if (items == null) return;
    _edits++;
    if (_pending == 0) _baseline = items;
    _pending++;
    setState(() => _items = change(items));
    final ok = await guardedAction(() => _serverQueue.run(server));
    _pending--;
    final baseline = _baseline;
    if (_pending == 0) _baseline = null;
    if (!ok && baseline != null && mounted) {
      setState(() => _items = baseline);
    }
    if (mounted && (!ok || _pending == 0)) await guardedAction(_fetchItems);
  }

  // Completion goes through Cloud Functions because it changes XP and coins
  // atomically; the real repository rejects a direct write.
  Future<void> _toggleComplete(BucketListItem item) {
    final completing = !item.isCompleted;
    return _optimistic(
      (items) => [
        for (final i in items)
          if (i.id == item.id)
            completing
                ? i.copyWith(
                    isCompleted: true,
                    completedAt: DateTime.now(),
                    rewardPaid: true,
                  )
                : i.copyWith(isCompleted: false, rewardPaid: false)
          else
            i,
      ],
      () async {
        final result = await callCloudFunction(
          completing ? 'completeBucketListItem' : 'uncompleteBucketListItem',
          {'itemId': item.id},
        );
        if (completing && result['limited'] == true && mounted) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(
                content: Text(
                  'Achieved! You have already collected '
                  '${BucketListItem.paidGoalsPerWeek} goal rewards this week, '
                  'so this one pays nothing.',
                ),
              ),
            );
        }
      },
    );
  }

  Future<void> _openAddDialog() async {
    final added = await showDialog<BucketListItem>(
      context: context,
      builder: (_) => const _BucketItemDialog(),
    );
    if (added == null) return;
    final retry = _unconfirmedAdd;
    final item = retry != null && retry.sameGoalAs(added) ? retry : added;
    _unconfirmedAdd = item;
    await _optimistic((items) => [...items, item], () async {
      await AppData.bucketList.addItem(item);
      if (_unconfirmedAdd?.id == item.id) _unconfirmedAdd = null;
    });
  }

  Future<void> _openEditDialog(BucketListItem item) async {
    final updated = await showDialog<BucketListItem>(
      context: context,
      builder: (_) => _BucketItemDialog(existing: item),
    );
    if (updated == null) return;
    await _optimistic(
      (items) => [for (final i in items) i.id == updated.id ? updated : i],
      () => AppData.bucketList.updateItem(updated),
    );
  }

  /// Confirm deletion if the item ever paid rewards, since deletion claws them back.
  /// Uncompleting retains the reward; never-paid items delete immediately.
  Future<void> _deleteItem(BucketListItem item) async {
    final paidOut = item.isCompleted || item.rewardPaid;
    if (paidOut && !await _confirmDeleteCompleted(item)) return;
    await _optimistic(
      (items) => [
        for (final i in items)
          if (i.id != item.id) i,
      ],
      () => AppData.bucketList.deleteItem(item.id),
    );
  }

  Future<bool> _confirmDeleteCompleted(BucketListItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          side: const BorderSide(color: AppColors.ink, width: AppBorder.thin),
        ),
        title: Text('Delete "${item.title}"?'),
        content: const Text(
          'This one already paid out — deleting it takes back the XP and '
          'coins it earned.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: AppTheme.destructiveFilledButton,
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    final error = loadError;

    return Scaffold(
      body: SafeArea(
        child: items == null
            ? error != null
                  ? LoadErrorView(error: error, onRetry: _loadItems)
                  : const Center(child: CircularProgressIndicator())
            : NoriScrollScaffold(
                maxWidth: 900,
                children: [
                  NoriScreenHeader(
                    leading: NoriScreenHeader.backButton(context),
                    title: 'Bucket list',
                    titleStyle: AppTextStyles.headlineLgMobile,
                  ),
                  const SizedBox(height: 2),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.containerPaddingMobile,
                    ),
                    child: Text(
                      'Big, one-time milestones — travel, a marathon, a degree. '
                      'Worth a lot more XP and coins than a daily habit.',
                      style: AppTextStyles.bodyMd.copyWith(
                        color: AppColors.inkMuted,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.stackSm),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.containerPaddingMobile,
                    ),
                    child: Text(
                      '${items.where((i) => i.isCompleted).length} / ${items.length} completed',
                      style: AppTextStyles.labelLg.copyWith(
                        color: AppColors.terracottaDark,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.stackMd),
                  if (items.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.stackLg,
                      ),
                      child: Text(
                        'Nothing here yet — add your first big goal.',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.bodyMd.copyWith(
                          color: AppColors.inkFaint,
                        ),
                      ),
                    )
                  else
                    for (final item in items) ...[
                      _BucketListCard(
                        item: item,
                        onToggle: () => _toggleComplete(item),
                        onEdit: () => _openEditDialog(item),
                        onDelete: () => _deleteItem(item),
                      ),
                      if (item != items.last)
                        const SizedBox(height: AppSpacing.stackSm),
                    ],
                  const SizedBox(height: AppSpacing.stackMd),
                  TactileButton(
                    label: 'Add bucket list goal',
                    icon: Icons.add,
                    onPressed: _openAddDialog,
                  ),
                ],
              ),
      ),
    );
  }
}

class _BucketListCard extends StatelessWidget {
  const _BucketListCard({
    required this.item,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  final BucketListItem item;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final claimed = item.isCompleted;
    return NoriCard(
      padding: const EdgeInsets.all(14),
      color: claimed ? AppColors.white : AppColors.linenAlt,
      borderWidth: AppBorder.thin,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // A completed item only differed by a faint strikethrough and
              // the button's label -- easy to miss at a glance. This adds
              // an explicit checkmark badge, the same visual language
              // customization_screen.dart already uses for "selected".
              Stack(
                clipBehavior: Clip.none,
                children: [
                  NoriIconBadge(
                    icon: item.icon,
                    background: item.color,
                    size: 44,
                    iconSize: 22,
                  ),
                  if (claimed)
                    Positioned(
                      top: -4,
                      right: -4,
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.moss,
                          border: Border.all(
                            color: AppColors.ink,
                            width: AppBorder.thin,
                          ),
                        ),
                        child: const Icon(
                          Icons.check,
                          size: 13,
                          color: AppColors.ink,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: AppTextStyles.bodyMd.copyWith(
                        fontWeight: FontWeight.w700,
                        color: claimed ? AppColors.inkFaint : AppColors.ink,
                        decoration: claimed ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.description,
                      style: AppTextStyles.labelSm.copyWith(
                        color: AppColors.inkFaint,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<void>(
                tooltip: 'More options for ${item.title}',
                padding: EdgeInsets.zero,
                icon: const Icon(
                  Icons.more_vert,
                  size: 18,
                  color: AppColors.inkFaint,
                ),
                itemBuilder: (context) => [
                  PopupMenuItem(onTap: onEdit, child: const Text('Edit')),
                  PopupMenuItem(onTap: onDelete, child: const Text('Delete')),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              RewardPill(xp: item.xpReward, coins: item.coinReward),
              const Spacer(),
              FilledButton(
                onPressed: onToggle,
                style: FilledButton.styleFrom(
                  backgroundColor: claimed
                      ? AppColors.linenAlt
                      : AppColors.moss,
                  foregroundColor: claimed ? AppColors.inkMuted : AppColors.ink,
                  side: const BorderSide(
                    color: AppColors.ink,
                    width: AppBorder.thin,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  textStyle: AppTextStyles.labelLg,
                ),
                child: Text(claimed ? 'Undo' : 'Mark achieved'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BucketItemDialog extends StatefulWidget {
  const _BucketItemDialog({this.existing});

  final BucketListItem? existing;

  @override
  State<_BucketItemDialog> createState() => _BucketItemDialogState();
}

class _BucketItemDialogState extends State<_BucketItemDialog> {
  static const _icons = [
    Icons.flight_takeoff,
    Icons.directions_run,
    Icons.school,
    Icons.emoji_events,
    Icons.terrain,
    Icons.celebration,
  ];
  static const _colors = [
    AppColors.blushPink,
    AppColors.mossLight,
    AppColors.sky,
    AppColors.mustardLight,
    AppColors.terracotta,
  ];

  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late BucketGoalSize _size;
  late IconData _icon;
  late Color _color;

  /// Shown under the title after Add/Save with it empty — the tap used to
  /// do nothing at all.
  String? _titleError;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _titleController = TextEditingController(text: existing?.title ?? '');
    _descriptionController = TextEditingController(
      text: existing?.description ?? '',
    );
    _size = existing == null
        ? BucketGoalSize.medium
        : BucketGoalSize.nearest(existing.coinReward);
    _icon = existing?.icon ?? _icons.first;
    _color = existing?.color ?? _colors.first;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _save() {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      setState(() => _titleError = 'Give your goal a title.');
      return;
    }
    final description = _descriptionController.text.trim();
    final existing = widget.existing;
    final xpReward = _size.xp;
    final coinReward = _size.coins;

    final item = existing == null
        ? BucketListItem(
            id: generateId(),
            title: title,
            description: description,
            icon: _icon,
            color: _color,
            xpReward: xpReward,
            coinReward: coinReward,
          )
        : existing.copyWith(
            title: title,
            description: description,
            icon: _icon,
            color: _color,
            xpReward: xpReward,
            coinReward: coinReward,
          );
    Navigator.pop(context, item);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        side: const BorderSide(color: AppColors.ink, width: AppBorder.thin),
      ),
      title: Text(
        widget.existing == null
            ? 'New bucket list goal'
            : 'Edit bucket list goal',
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _titleController,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: 'Title (e.g. Visit Japan)',
                errorText: _titleError,
              ),
              onChanged: (_) {
                if (_titleError != null) setState(() => _titleError = null);
              },
            ),
            const SizedBox(height: AppSpacing.stackSm),
            TextField(
              controller: _descriptionController,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Description'),
            ),
            const SizedBox(height: AppSpacing.stackSm),
            Text('How big is this goal?', style: AppTextStyles.labelLg),
            const SizedBox(height: AppSpacing.unit),
            Wrap(
              spacing: AppSpacing.unit,
              children: [
                for (final size in BucketGoalSize.values)
                  ChoiceChip(
                    label: Text(size.label),
                    selected: _size == size,
                    showCheckmark: false,
                    selectedColor: AppColors.mossLight,
                    onSelected: (_) => setState(() => _size = size),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${_size.xp} XP · ${_size.coins} coins. Only the first '
              '${BucketListItem.paidGoalsPerWeek} goals you achieve each week '
              'pay a reward.',
              style: AppTextStyles.labelSm.copyWith(color: AppColors.inkMuted),
            ),
            const SizedBox(height: AppSpacing.stackSm),
            Wrap(
              spacing: AppSpacing.unit,
              children: [
                for (final icon in _icons)
                  ChoiceChip(
                    label: Icon(icon, size: 18),
                    selected: _icon == icon,
                    // Selection reads from the fill alone (the goal's
                    // chosen color), not a checkmark crowding the icon.
                    showCheckmark: false,
                    selectedColor: _color,
                    onSelected: (_) => setState(() => _icon = icon),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.stackSm),
            Wrap(
              spacing: AppSpacing.unit,
              children: [
                for (final color in _colors)
                  InkWell(
                    onTap: () => setState(() => _color = color),
                    borderRadius: BorderRadius.circular(AppRadius.full),
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.ink,
                          width: _color == color
                              ? AppBorder.thick
                              : AppBorder.thin,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _save,
          child: Text(widget.existing == null ? 'Add' : 'Save'),
        ),
      ],
    );
  }
}
