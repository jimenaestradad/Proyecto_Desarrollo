import 'package:flutter/material.dart';
import 'package:nori/data/app_data.dart';
import 'package:nori/models/nori_user.dart';
import 'package:nori/theme/app_theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  NoriUser? _user;
  List<String>? _categories;

  @override
  void initState() {
    super.initState();
    _loadUser();
    _loadCategories();
  }

  Future<void> _loadUser() async {
    final user = await AppData.user.getCurrentUser();
    if (!mounted) return;
    setState(() => _user = user);
  }

  Future<void> _loadCategories() async {
    final categories = await AppData.habitCategories.getCategories();
    if (!mounted) return;
    setState(() => _categories = categories);
  }

  Future<void> _toggleVacationMode() async {
    final user = _user;
    if (user == null) return;
    await AppData.user.setVacationMode(!user.vacationModeEnabled);
    await _loadUser();
  }

  Future<void> _addCategory() async {
    final name = await _promptForText(title: 'New Category', hint: 'e.g. Finance');
    if (name == null || name.trim().isEmpty) return;
    await AppData.habitCategories.addCategory(name.trim());
    await _loadCategories();
  }

  Future<void> _renameCategory(String category) async {
    final name = await _promptForText(
      title: 'Rename Category',
      hint: category,
      initialValue: category,
    );
    if (name == null || name.trim().isEmpty || name.trim() == category) return;
    await AppData.habitCategories.renameCategory(category, name.trim());
    await _loadCategories();
  }

  Future<void> _deleteCategory(String category) async {
    await AppData.habitCategories.deleteCategory(category);
    await _loadCategories();
  }

  Future<String?> _promptForText({
    required String title,
    String? hint,
    String? initialValue,
  }) async {
    final controller = TextEditingController(text: initialValue);
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          side: const BorderSide(color: AppColors.ink, width: AppBorder.thin),
        ),
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(hintText: hint),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.moss,
              foregroundColor: AppColors.ink,
            ),
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final user = _user;
    final categories = _categories;

    return Scaffold(
      body: SafeArea(
        child: user == null || categories == null
            ? const Center(child: CircularProgressIndicator())
            : LayoutBuilder(
                builder: (context, constraints) {
                  final horizontalPadding = constraints.maxWidth >= 800
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
                        constraints: const BoxConstraints(maxWidth: 800),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                IconButton(
                                  onPressed: () => Navigator.pop(context),
                                  icon: const Icon(Icons.arrow_back),
                                ),
                                Expanded(
                                  child: Text(
                                    'Settings',
                                    style: AppTextStyles.headlineLgMobile,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.stackMd),
                            Text(
                              'Habits',
                              style: AppTextStyles.labelLg.copyWith(
                                color: AppColors.inkMuted,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.unit),
                            VacationModeCard(
                              enabled: user.vacationModeEnabled,
                              onToggle: _toggleVacationMode,
                            ),
                            const SizedBox(height: AppSpacing.stackMd),
                            Text(
                              'Habit Categories',
                              style: AppTextStyles.labelLg.copyWith(
                                color: AppColors.inkMuted,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.unit),
                            _CategoriesCard(
                              categories: categories,
                              onAdd: _addCategory,
                              onRename: _renameCategory,
                              onDelete: _deleteCategory,
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

/// Moved here from the Habits tab — vacation mode is an account-level
/// setting, not something that should compete for space on the daily list.
/// Its effect is currently limited to persisting the flag on [NoriUser]:
/// there's no real day-rollover/streak-freeze engine yet, since streaks are
/// still just a static int (see docs/OPEN_DECISIONS.md "Technical rules /
/// edge cases" — timezone/day-rollover handling is undecided).
class VacationModeCard extends StatelessWidget {
  const VacationModeCard({super.key, required this.enabled, required this.onToggle});

  final bool enabled;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.stackSm),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AppColors.ink, width: AppBorder.thin),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.mustardLight,
              borderRadius: BorderRadius.circular(AppRadius.sm * 0.6),
              border: Border.all(color: AppColors.ink, width: AppBorder.thin),
            ),
            child: const Icon(
              Icons.beach_access,
              color: AppColors.mustardDark,
              size: 18,
            ),
          ),
          const SizedBox(width: AppSpacing.stackSm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        'Vacation Mode',
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.labelLg,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.unit),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: enabled ? AppColors.mossLight : AppColors.linen,
                        borderRadius: BorderRadius.circular(AppRadius.full),
                        border: Border.all(
                          color: AppColors.ink,
                          width: AppBorder.thin,
                        ),
                      ),
                      child: Text(
                        enabled ? 'Active' : 'Inactive',
                        style: AppTextStyles.labelSm.copyWith(
                          color: enabled
                              ? AppColors.mossDark
                              : AppColors.inkMuted,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Freezes streaks safely when you take a break.',
                  style: AppTextStyles.labelSm.copyWith(
                    color: AppColors.inkFaint,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.unit),
          OutlinedButton(
            onPressed: onToggle,
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.ink, width: AppBorder.thin),
              foregroundColor: AppColors.ink,
            ),
            child: Text(enabled ? 'Disable' : 'Enable'),
          ),
        ],
      ),
    );
  }
}

/// The category list the Add/Edit Habit screen's "Category" dropdown pulls
/// from — see [HabitCategoryRepository]. Add/rename/delete only affects the
/// picker; habits already using a deleted category keep their subtitle text.
class _CategoriesCard extends StatelessWidget {
  const _CategoriesCard({
    required this.categories,
    required this.onAdd,
    required this.onRename,
    required this.onDelete,
  });

  final List<String> categories;
  final VoidCallback onAdd;
  final ValueChanged<String> onRename;
  final ValueChanged<String> onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.stackSm),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AppColors.ink, width: AppBorder.thin),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final category in categories) ...[
            Row(
              children: [
                Expanded(child: Text(category, style: AppTextStyles.labelLg)),
                IconButton(
                  tooltip: 'Rename',
                  onPressed: () => onRename(category),
                  icon: const Icon(Icons.edit, size: 18, color: AppColors.inkMuted),
                ),
                IconButton(
                  tooltip: 'Delete',
                  onPressed: categories.length > 1 ? () => onDelete(category) : null,
                  icon: const Icon(Icons.delete_outline, size: 18),
                ),
              ],
            ),
            if (category != categories.last)
              const Divider(height: 1, color: AppColors.linenAlt),
          ],
          const SizedBox(height: AppSpacing.unit),
          OutlinedButton.icon(
            onPressed: onAdd,
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.ink, width: AppBorder.thin),
              foregroundColor: AppColors.ink,
            ),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add Category'),
          ),
        ],
      ),
    );
  }
}
