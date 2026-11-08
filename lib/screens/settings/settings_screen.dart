import 'package:flutter/material.dart';
import 'package:nori/data/app_data.dart';
import 'package:nori/data/auth_repository.dart';
import 'package:nori/data/cloud_functions_client.dart';
import 'package:nori/data/tips_store.dart';
import 'package:nori/models/nori_user.dart';
import 'package:nori/screens/habits/archived_habits_screen.dart';
import 'package:nori/screens/onboarding/intro_screen.dart';
import 'package:nori/screens/premium/nori_plus_screen.dart';
import 'package:nori/theme/app_theme.dart';
import 'package:nori/utils/app_log.dart';
import 'package:nori/utils/validators.dart';
import 'package:nori/utils/remote_errors.dart';
import 'package:nori/widgets/future_feature_banner.dart';
import 'package:nori/widgets/load_error_view.dart';
import 'package:nori/widgets/nori_card.dart';
import 'package:nori/widgets/nori_list_row.dart';
import 'package:nori/widgets/nori_screen_header.dart';
import 'package:nori/widgets/nori_scroll_scaffold.dart';
import 'package:nori/widgets/nori_text_prompt.dart';
import 'package:nori/widgets/password_rules.dart';

/// The one account that gets the dev-only reset row below; the
/// `resetDemoAccount` Cloud Function enforces the same email server-side.
const kDemoAccountEmail = 'demo@test.com';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with RemoteLoadState<SettingsScreen> {
  NoriUser? _user;
  List<String>? _categories;

  /// Null while loading; false offers password linking for Google-only accounts.
  /// The row hides once password authentication is available.
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
    final result = await showDialog<_NewPassword>(
      context: context,
      builder: (_) => _SetPasswordDialog(onProblem: _showMessage),
    );
    final password = result?.next;
    if (password == null || password.isEmpty || !mounted) return;

    try {
      await AppData.auth.addPassword(password);
      if (!mounted) return;
      _showMessage('Password set — you can now log in with either method.');
      await _loadPasswordProvider();
    } on AuthException catch (e) {
      if (!mounted) return;
      _showMessage(e.message);
    } catch (error, stackTrace) {
      logError('addPassword', error, stackTrace);
      if (!mounted) return;
      _showMessage('Unable to set a password. Please try again.');
    }
  }

  Future<void> _changePassword() async {
    final result = await showDialog<_NewPassword>(
      context: context,
      builder: (_) =>
          _SetPasswordDialog(onProblem: _showMessage, askCurrent: true),
    );
    if (result == null || !mounted) return;

    try {
      await AppData.auth.changePassword(
        currentPassword: result.current,
        newPassword: result.next,
      );
      if (!mounted) return;
      _showMessage('Password changed.');
    } on AuthException catch (e) {
      if (!mounted) return;
      _showMessage(e.message);
    } catch (error, stackTrace) {
      logError('changePassword', error, stackTrace);
      if (!mounted) return;
      _showMessage('Unable to change your password. Please try again.');
    }
  }

  /// Require the typed username before permanent deletion of habits, pet and coins.
  /// Request a password or fresh Google sign-in for the server's recent-auth requirement.
  Future<void> _deleteAccount() async {
    final user = _user;
    if (user == null) return;
    final hasPassword =
        _hasPasswordProvider ?? await AppData.auth.hasPasswordProvider();
    if (!mounted) return;
    final request = await showDialog<DeleteAccountRequest>(
      context: context,
      builder: (_) => DeleteAccountDialog(
        username: user.username,
        hasPassword: hasPassword,
      ),
    );
    // Cancel (or tapping outside) closes without a word.
    if (request == null || !mounted) return;
    if (!request.usernameMatches) {
      _showMessage("The username didn't match — nothing was deleted.");
      return;
    }
    final password = request.password;
    if (hasPassword && password.isEmpty) {
      _showMessage('Enter your password to delete your account.');
      return;
    }

    _showMessage('Deleting your account...');
    try {
      await AppData.auth.deleteAccount(password: hasPassword ? password : null);
    } on AuthException catch (e) {
      if (mounted) _showMessage(e.message);
      return;
    } catch (error, stackTrace) {
      logError('deleteAccount', error, stackTrace);
      if (!mounted) return;
      _showMessage('Unable to delete your account. Please try again.');
      return;
    }
    // Same teardown as ProfileScreen._logOut.
    AppData.unbindUser();
    if (!mounted) return;
    // Shown before leaving: the messenger lives above the navigator, so the
    // message is still on screen once Welcome is up.
    _showMessage('Your account has been deleted.');
    Navigator.pushNamedAndRemoveUntil(context, '/welcome', (route) => false);
  }

  /// Dev-only: the `resetDemoAccount` function takes back every bucket-list
  /// payout (de-evolving Nori) so that flow can be tested again. The server
  /// refuses anyone but [kDemoAccountEmail]; this row just hides itself.
  bool _resettingDemo = false;

  Future<void> _resetDemoAccount() async {
    // The call takes a few seconds (cold start), and nothing else on the
    // screen moves meanwhile: say it started, and ignore a second tap.
    if (_resettingDemo) return;
    _resettingDemo = true;
    _showMessage('Resetting demo account…');
    try {
      await _runDemoReset();
    } finally {
      _resettingDemo = false;
    }
  }

  Future<void> _runDemoReset() async {
    await guardedAction(() async {
      try {
        await callCloudFunction('resetDemoAccount', {});
      } on CloudFunctionFailure catch (e) {
        if (mounted) _showMessage(e.message);
        return;
      }
      if (!mounted) return;
      _showMessage(
        'Demo account reset — bucket list items pay out again, and care items and coins are topped up.',
      );
    });
  }

  Future<void> _loadCategories() async {
    final categories = await AppData.habitCategories.getCategories();
    if (!mounted) return;
    setState(() => _categories = categories);
  }

  // The Habits tab reloads itself when you switch back to it, so a restore
  // needs no result handed back here.
  void _openArchived() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ArchivedHabitsScreen()),
    );
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

  /// Forgets what this account has seen, so the hint cards show again, then
  /// plays the intro cards right away.
  Future<void> _replayIntro() async {
    final store = TipsStore.current();
    await store.reset();
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => IntroScreen(store: store)),
    );
  }

  Future<void> _addCategory() async {
    final name = await _promptForText(
      title: 'New category',
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
      title: 'Rename category',
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
  }) => showNoriTextPrompt(
    context,
    title: title,
    hint: hint,
    initialValue: initialValue,
  );

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
                  const SizedBox(height: AppSpacing.unit),
                  NoriListRow(
                    icon: Icons.inventory_2_outlined,
                    label: 'Archived habits',
                    onTap: _openArchived,
                  ),
                  const SizedBox(height: AppSpacing.stackMd),
                  Text(
                    'Habit categories',
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
                    'Help',
                    style: AppTextStyles.labelLg.copyWith(
                      color: AppColors.inkMuted,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.unit),
                  NoriListRow(
                    icon: Icons.lightbulb_outline,
                    label: 'Replay intro and tips',
                    onTap: _replayIntro,
                  ),
                  const SizedBox(height: AppSpacing.stackMd),
                  if (user.email.toLowerCase() == kDemoAccountEmail) ...[
                    Text(
                      'Developer',
                      style: AppTextStyles.labelLg.copyWith(
                        color: AppColors.inkMuted,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.unit),
                    NoriListRow(
                      icon: Icons.restart_alt,
                      label: 'Reset demo account',
                      onTap: _resetDemoAccount,
                    ),
                    const SizedBox(height: AppSpacing.stackMd),
                  ],
                  if (_hasPasswordProvider != null) ...[
                    Text(
                      'Account',
                      style: AppTextStyles.labelLg.copyWith(
                        color: AppColors.inkMuted,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.unit),
                    NoriListRow(
                      icon: Icons.password,
                      label: _hasPasswordProvider == true
                          ? 'Change password'
                          : 'Set a password',
                      onTap: _hasPasswordProvider == true
                          ? _changePassword
                          : _addPassword,
                    ),
                    const SizedBox(height: AppSpacing.stackMd),
                  ],
                  Text(
                    'Plan',
                    style: AppTextStyles.labelLg.copyWith(
                      color: AppColors.inkMuted,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.unit),
                  _PlanCard(onUpgrade: _openNoriPlus),
                  const SizedBox(height: AppSpacing.stackMd),
                  NoriListRow(
                    icon: Icons.delete_forever,
                    label: 'Delete account',
                    onTap: _deleteAccount,
                    destructive: true,
                  ),
                ],
              ),
      ),
    );
  }
}

/// Account-level Vacation Mode toggle that records transitions in VacationLog.
/// Frozen days remain neutral in calendar/streak history; pet decay is not paused yet.
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
    return NoriCard(
      padding: const EdgeInsets.all(AppSpacing.stackSm),
      borderWidth: AppBorder.thin,
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
                        'Vacation mode',
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
            label: const Text('Add category'),
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
          Text('Free plan', style: AppTextStyles.labelLg),
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

/// What [DeleteAccountDialog] hands back when Delete is tapped.
class DeleteAccountRequest {
  const DeleteAccountRequest({
    required this.usernameMatches,
    required this.password,
  });

  final bool usernameMatches;
  final String password;
}

/// "Set a Password" for a Google-only account. Its own widget so it owns
/// its text controllers, for the same reason as [DeleteAccountDialog].
/// What [_SetPasswordDialog] hands back; [current] is empty unless it asked.
typedef _NewPassword = ({String current, String next});

/// Sets a password (Google-only accounts) or, with [askCurrent], changes one.
class _SetPasswordDialog extends StatefulWidget {
  const _SetPasswordDialog({required this.onProblem, this.askCurrent = false});

  final ValueChanged<String> onProblem;
  final bool askCurrent;

  @override
  State<_SetPasswordDialog> createState() => _SetPasswordDialogState();
}

class _SetPasswordDialogState extends State<_SetPasswordDialog> {
  final _currentController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  @override
  void dispose() {
    _currentController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _submit() {
    if (widget.askCurrent && _currentController.text.isEmpty) {
      widget.onProblem('Enter your current password.');
      return;
    }
    final problem = validateNewPassword(_passwordController.text);
    if (problem != null) {
      widget.onProblem(problem);
      return;
    }
    if (widget.askCurrent &&
        _passwordController.text == _currentController.text) {
      widget.onProblem('Choose a password different from your current one.');
      return;
    }
    if (_passwordController.text != _confirmController.text) {
      widget.onProblem('Passwords do not match.');
      return;
    }
    Navigator.pop(context, (
      current: _currentController.text,
      next: _passwordController.text,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        side: const BorderSide(color: AppColors.ink, width: AppBorder.thin),
      ),
      scrollable: true,
      title: Text(widget.askCurrent ? 'Change password' : 'Set a password'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.askCurrent) ...[
            TextField(
              controller: _currentController,
              autofocus: true,
              obscureText: true,
              decoration: const InputDecoration(hintText: 'Current password'),
            ),
          ] else
            const Text('Add a password so you can also log in without Google.'),
          const SizedBox(height: AppSpacing.gutter),
          TextField(
            controller: _passwordController,
            autofocus: !widget.askCurrent,
            obscureText: true,
            decoration: const InputDecoration(hintText: 'New password'),
          ),
          const SizedBox(height: AppSpacing.unit),
          PasswordRules(controller: _passwordController),
          const SizedBox(height: AppSpacing.unit),
          TextField(
            controller: _confirmController,
            obscureText: true,
            decoration: const InputDecoration(hintText: 'Confirm password'),
            // Same check as Save — submitting from the keyboard used to
            // skip the match check entirely.
            onSubmitted: (_) => _submit(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Save')),
      ],
    );
  }
}

/// The confirm-by-typing dialog for deleting the account. Its own widget so
/// it owns its text controllers: disposing them right after `showDialog`
/// returns (as the caller used to) frees them while the close animation is
/// still drawing the fields.
class DeleteAccountDialog extends StatefulWidget {
  const DeleteAccountDialog({
    super.key,
    required this.username,
    required this.hasPassword,
  });

  final String username;
  final bool hasPassword;

  @override
  State<DeleteAccountDialog> createState() => DeleteAccountDialogState();
}

@visibleForTesting
class DeleteAccountDialogState extends State<DeleteAccountDialog> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final username = widget.username;
    return AlertDialog(
      scrollable: true,
      backgroundColor: AppColors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        side: const BorderSide(color: AppColors.ink, width: AppBorder.thin),
      ),
      title: const Text('Delete account?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'This permanently deletes your account, habits, history, pet, '
            'coins and items. It can\'t be undone.',
          ),
          const SizedBox(height: AppSpacing.gutter),
          Text('Type $username to confirm.'),
          const SizedBox(height: AppSpacing.unit),
          TextField(
            controller: _usernameController,
            autofocus: true,
            autocorrect: false,
            decoration: InputDecoration(hintText: username),
          ),
          const SizedBox(height: AppSpacing.gutter),
          if (widget.hasPassword) ...[
            const Text('Enter your password to confirm it\'s you.'),
            const SizedBox(height: AppSpacing.unit),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(hintText: 'Password'),
            ),
          ] else
            const Text("You'll be asked to sign in with Google again."),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: AppTheme.destructiveFilledButton,
          onPressed: () => Navigator.pop(
            context,
            DeleteAccountRequest(
              usernameMatches:
                  _usernameController.text.trim().toLowerCase() ==
                  username.toLowerCase(),
              password: _passwordController.text,
            ),
          ),
          child: const Text('Delete'),
        ),
      ],
    );
  }
}
