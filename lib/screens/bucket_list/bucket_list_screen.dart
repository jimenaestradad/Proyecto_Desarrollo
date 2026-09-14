import 'package:flutter/material.dart';
import 'package:nori/data/app_data.dart';
import 'package:nori/models/bucket_list_item.dart';
import 'package:nori/theme/app_theme.dart';
import 'package:nori/utils/id_generator.dart';
import 'package:nori/widgets/nori_icon_badge.dart';
import 'package:nori/widgets/nori_screen_header.dart';
import 'package:nori/widgets/reward_pill.dart';
import 'package:nori/widgets/tactile_button.dart';

/// One-time major life goals — see docs/FEATURES.md §11. Reached from the
/// Habits screen topbar, not the bottom nav: distinct from the daily habit
/// list, but not important enough to compete for a nav slot.
class BucketListScreen extends StatefulWidget {
  const BucketListScreen({super.key});

  @override
  State<BucketListScreen> createState() => _BucketListScreenState();
}

class _BucketListScreenState extends State<BucketListScreen> {
  List<BucketListItem>? _items;

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  Future<void> _loadItems() async {
    final items = await AppData.bucketList.getItems();
    if (!mounted) return;
    setState(() => _items = items);
  }

  Future<void> _applyReward(int xpDelta, int coinsDelta) async {
    if (xpDelta == 0 && coinsDelta == 0) return;
    if (xpDelta != 0) await AppData.user.addXp(xpDelta);
    if (coinsDelta != 0) await AppData.user.addCoins(coinsDelta);
  }

  Future<void> _toggleComplete(BucketListItem item) async {
    final reward = item.isCompleted
        ? await AppData.bucketList.uncompleteItem(item.id)
        : await AppData.bucketList.completeItem(item.id);
    await _applyReward(reward.xpDelta, reward.coinsDelta);
    await _loadItems();
  }

  Future<void> _openAddDialog() async {
    final added = await showDialog<BucketListItem>(
      context: context,
      builder: (_) => const _AddBucketItemDialog(),
    );
    if (added == null) return;
    await AppData.bucketList.addItem(added);
    await _loadItems();
  }

  Future<void> _deleteItem(BucketListItem item) async {
    await AppData.bucketList.deleteItem(item.id);
    await _loadItems();
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;

    return Scaffold(
      body: SafeArea(
        child: items == null
            ? const Center(child: CircularProgressIndicator())
            : LayoutBuilder(
                builder: (context, constraints) {
                  final horizontalPadding = constraints.maxWidth >= 800
                      ? AppSpacing.containerPaddingDesktop
                      : AppSpacing.containerPaddingMobile;
                  final completedCount = items.where((i) => i.isCompleted).length;

                  return SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      horizontalPadding,
                      AppSpacing.gutter,
                      horizontalPadding,
                      AppSpacing.stackLg,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 900),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            NoriScreenHeader(
                              leading: NoriScreenHeader.backButton(context),
                              title: 'Bucket List',
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
                                '$completedCount / ${items.length} completed',
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
                                  onDelete: () => _deleteItem(item),
                                ),
                                if (item != items.last)
                                  const SizedBox(height: AppSpacing.stackSm),
                              ],
                            const SizedBox(height: AppSpacing.stackMd),
                            TactileButton(
                              label: 'Add Bucket List Goal',
                              icon: Icons.add,
                              onPressed: _openAddDialog,
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

class _BucketListCard extends StatelessWidget {
  const _BucketListCard({
    required this.item,
    required this.onToggle,
    required this.onDelete,
  });

  final BucketListItem item;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final claimed = item.isCompleted;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: claimed ? AppColors.white : AppColors.linenAlt,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AppColors.ink, width: AppBorder.thin),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              NoriIconBadge(
                icon: item.icon,
                background: item.color,
                size: 44,
                iconSize: 22,
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
                      style: AppTextStyles.labelSm.copyWith(color: AppColors.inkFaint),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<void>(
                tooltip: 'More',
                padding: EdgeInsets.zero,
                icon: const Icon(Icons.more_vert, size: 18, color: AppColors.inkFaint),
                itemBuilder: (context) => [
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
                  backgroundColor: claimed ? AppColors.linenAlt : AppColors.moss,
                  foregroundColor: claimed ? AppColors.inkMuted : AppColors.ink,
                  side: const BorderSide(color: AppColors.ink, width: AppBorder.thin),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  textStyle: AppTextStyles.labelLg,
                ),
                child: Text(claimed ? 'Undo' : 'Mark Achieved'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AddBucketItemDialog extends StatefulWidget {
  const _AddBucketItemDialog();

  @override
  State<_AddBucketItemDialog> createState() => _AddBucketItemDialogState();
}

class _AddBucketItemDialogState extends State<_AddBucketItemDialog> {
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

  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _xpController = TextEditingController(text: '150');
  final _coinController = TextEditingController(text: '75');
  IconData _icon = _icons.first;
  Color _color = _colors.first;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _xpController.dispose();
    _coinController.dispose();
    super.dispose();
  }

  void _save() {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;
    final item = BucketListItem(
      id: generateId(),
      title: title,
      description: _descriptionController.text.trim(),
      icon: _icon,
      color: _color,
      xpReward: int.tryParse(_xpController.text.trim()) ?? 150,
      coinReward: int.tryParse(_coinController.text.trim()) ?? 75,
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
      title: const Text('New Bucket List Goal'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _titleController,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Title (e.g. Visit Japan)'),
            ),
            const SizedBox(height: AppSpacing.stackSm),
            TextField(
              controller: _descriptionController,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Description'),
            ),
            const SizedBox(height: AppSpacing.stackSm),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _xpController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'XP reward'),
                  ),
                ),
                const SizedBox(width: AppSpacing.stackSm),
                Expanded(
                  child: TextField(
                    controller: _coinController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Coin reward'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.stackSm),
            Wrap(
              spacing: AppSpacing.unit,
              children: [
                for (final icon in _icons)
                  ChoiceChip(
                    label: Icon(icon, size: 18),
                    selected: _icon == icon,
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
                          width: _color == color ? AppBorder.thick : AppBorder.thin,
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
          child: const Text('Add'),
        ),
      ],
    );
  }
}
