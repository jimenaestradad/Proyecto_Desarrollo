import 'package:flutter/material.dart';
import 'package:nori/data/app_data.dart';
import 'package:nori/data/auth_repository.dart';
import 'package:nori/models/nori_user.dart';
import 'package:nori/screens/premium/nori_plus_screen.dart';
import 'package:nori/theme/app_theme.dart';
import 'package:nori/utils/remote_errors.dart';
import 'package:nori/widgets/future_feature_banner.dart';
import 'package:nori/widgets/load_error_view.dart';
import 'package:nori/widgets/nori_card.dart';
import 'package:nori/widgets/nori_list_row.dart';
import 'package:nori/widgets/nori_screen_header.dart';
import 'package:nori/widgets/nori_scroll_scaffold.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with RemoteLoadState<SettingsScreen> {
  NoriUser? _user;
  List<String>? _categories;

  /// Null while loading. See docs/BACKEND.md, "Account linking, both
  /// directions" -- a Google-only account can attach a password from
  /// here (the Google->password direction; password->Google already
  /// happens automatically on login_screen.dart's account-linking
  /// prompt). Once true, the row that offers this hides itself.
  bool? _hasPasswordProvider;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() => guardedLoad(hasData: _user != null, () async {
    await _loadUser();
    await _loadCategories();
    await _loadPasswordProvider();
  });

  Future<void> _loadUser() async {
    final user = await AppData.user.getCurrentUser();
    if (!mounted) return;
    setState(() => _user = user);
  }

  Future<void> _loadPasswordProvider() async {
    final hasPassword = await AppData.auth.hasPasswordProvider();
    if (!mounted) return;
    setState(() => _hasPasswordProvider = hasPassword);
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _addPassword() async {
    final passwordController = TextEditingController();
    final confirmController = TextEditingController();
    final password = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          side: const BorderSide(color: AppColors.ink, width: AppBorder.thin),
        ),
        title: const Text('Set a Password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Add a password so you can also log in without Google.'),
            const SizedBox(height: AppSpacing.gutter),
            TextField(
              controller: passwordController,
              autofocus: true,
              obscureText: true,
              decoration: const InputDecoration(hintText: 'New password'),
            ),
            const SizedBox(height: AppSpacing.unit),
            TextField(
              controller: confirmController,
              obscureText: true,
              decoration: const InputDecoration(hintText: 'Confirm password'),
              onSubmitted: (value) =>
                  Navigator.pop(dialogContext, passwordController.text),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (passwordController.text != confirmController.text) {
                _showMessage('Passwords do not match.');
                return;
              }
              Navigator.pop(dialogContext, passwordController.text);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    passwordController.dispose();
    confirmController.dispose();
    if (password == null || password.isEmpty || !mounted) return;

    try {
      await AppData.auth.addPassword(password);
      if (!mounted) return;
      _showMessage('Password set — you can now log in with either method.');
      await _loadPasswordProvider();
    } on AuthException catch (e) {
      if (!mounted) return;
      _showMessage(e.message);
    } catch (_) {
      if (!mounted) return;
      _showMessage('Unable to set a password. Please try again.');
    }
  }

  /// Asks for the username typed back before deleting -- deletion is
  /// permanent and wipes habits, pet and coins, so a single tap shouldn't
  /// be able to do it.
  Future<void> _deleteAccount() async {
    final user = _user;
    if (user == null) return;
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          side: const BorderSide(color: AppColors.ink, width: AppBorder.thin),
        ),
        title: const Text('Delete Account?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This permanently deletes your account, habits, history, pet, '
              'coins and items. It can\'t be undone.',
            ),
            const SizedBox(height: AppSpacing.gutter),
            Text('Type ${user.username} to confirm.'),
            const SizedBox(height: AppSpacing.unit),
            TextField(
              controller: controller,
              autofocus: true,
              autocorrect: false,
              decoration: InputDecoration(hintText: user.username),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: AppColors.onError,
            ),
            onPressed: () => Navigator.pop(
              dialogContext,
              controller.text.trim().toLowerCase() ==
                  user.username.toLowerCase(),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (confirmed == null || !mounted) return;
    if (!confirmed) {
      _showMessage("The username didn't match — nothing was deleted.");
      return;
    }

    _showMessage('Deleting your account...');
    try {
      await AppData.auth.deleteAccount();
    } on AuthException catch (e) {
      if (mounted) _showMessage(e.message);
      return;
    } catch (_) {
      if (!mounted) return;
      _showMessage('Unable to delete your account. Please try again.');
      return;
    }
    // Same teardown as ProfileScreen._logOut.
    AppData.unbindUser();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/welcome', (route) => false);
  }

  Future<void> _loadCategories() async {
    final categories = await AppData.habitCategories.getCategories();
    if (!mounted) return;
    setState(() => _categories = categories);
  }

  void _openNoriPlus() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const NoriPlusScreen()),
    );
  }

  Future<void> _toggleVacationMode() async {
    final user = _user;
    if (user == null) return;
    await guardedAction(() async {
      await AppData.user.setVacationMode(!user.vacationModeEnabled);
      await _loadUser();
    });
  }

  Future<void> _addCategory() async {
    final name = await _promptForText(
      title: 'New Category',
      hint: 'e.g. Finance',
    );
    if (name == null || name.trim().isEmpty) return;
    await guardedAction(() async {
      await AppData.habitCategories.addCategory(name.trim());
      await _loadCategories();
    });
  }

  Future<void> _renameCategory(String category) async {
    final name = await _promptForText(
      title: 'Rename Category',
      hint: category,
      initialValue: category,
    );
    if (name == null || name.trim().isEmpty || name.trim() == category) return;
    await guardedAction(() async {
      await AppData.habitCategories.renameCategory(category, name.trim());
      await _loadCategories();
    });
  }

  Future<void> _deleteCategory(String category) async {
    await guardedAction(() async {
      await AppData.habitCategories.deleteCategory(category);
      await _loadCategories();
    });
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
    final error = loadError;

    return Scaffold(
      body: SafeArea(
        child: user == null || categories == null
            ? error != null
                  ? LoadErrorView(error: error, onRetry: _loadData)
                  : const Center(child: CircularProgressIndicator())
            : NoriScrollScaffold(
                maxWidth: 800,
                children: [
                  NoriScreenHeader(
                    leading: NoriScreenHeader.backButton(context),
                    title: 'Settings',
                    titleStyle: AppTextStyles.headlineLgMobile,
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
                  const SizedBox(height: AppSpacing.stackMd),
                  Text(
                    'Account',
                    style: AppTextStyles.labelLg.copyWith(
                      color: AppColors.inkMuted,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.unit),
                  if (_hasPasswordProvider == false) ...[
                    NoriListRow(
                      icon: Icons.password,
                      label: 'Set a Password',
                      onTap: _addPassword,
                    ),
                    const SizedBox(height: AppSpacing.unit),
                  ],
                  NoriListRow(
                    icon: Icons.delete_forever,
                    label: 'Delete Account',
                    onTap: _deleteAccount,
                  ),
                  const SizedBox(height: AppSpacing.stackMd),
                  Text(
                    'Plan',
                    style: AppTextStyles.labelLg.copyWith(
                      color: AppColors.inkMuted,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.unit),
                  _PlanCard(onUpgrade: _openNoriPlus),
                ],
              ),
      ),
    );
  }
}

/// Moved here from the Habits tab — vacation mode is an account-level
/// setting, not something that should compete for space on the daily list.
/// Toggling this also logs the on/off transition to `VacationLog`
/// (`lib/data/vacation_log.dart`), which `MockCalendarRepository` reads so
/// days it was active on are treated as neutral (frozen) rather than missed
/// in the streak walk and calendar grid — see FEATURES.md §2. Pet stat decay
/// is not paused by this yet (a separate, smaller follow-up).
class VacationModeCard extends StatelessWidget {
  const VacationModeCard({
    super.key,
    required this.enabled,
    required this.onToggle,
  });

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
              side: const BorderSide(
                color: AppColors.ink,
                width: AppBorder.thin,
              ),
              foregroundColor: AppColors.ink,
              minimumSize: const Size(0, 48),
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
    return NoriCard(
      padding: const EdgeInsets.all(AppSpacing.stackSm),
      borderWidth: AppBorder.thin,
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
                  icon: const Icon(
                    Icons.edit,
                    size: 18,
                    color: AppColors.inkMuted,
                  ),
                ),
                IconButton(
                  tooltip: 'Delete',
                  onPressed: categories.length > 1
                      ? () => onDelete(category)
                      : null,
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
              side: const BorderSide(
                color: AppColors.ink,
                width: AppBorder.thin,
              ),
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

/// No real subscription/billing yet (see CLAUDE.md — no backend), so this
/// always reads "Free Plan"; the row just opens the [NoriPlusScreen] preview.
class _PlanCard extends StatelessWidget {
  const _PlanCard({required this.onUpgrade});

  final VoidCallback onUpgrade;

  @override
  Widget build(BuildContext context) {
    return NoriCard(
      padding: const EdgeInsets.all(AppSpacing.stackSm),
      borderWidth: AppBorder.thin,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Free Plan', style: AppTextStyles.labelLg),
          const SizedBox(height: 2),
          Text(
            'Upgrade for more customization and pet features.',
            style: AppTextStyles.labelSm.copyWith(color: AppColors.inkFaint),
          ),
          const SizedBox(height: AppSpacing.stackSm),
          NoriListRow(
            icon: Icons.diamond,
            label: 'Nori Plus',
            onTap: onUpgrade,
            trailing: const SoonBadge(),
          ),
        ],
      ),
    );
  }
}
