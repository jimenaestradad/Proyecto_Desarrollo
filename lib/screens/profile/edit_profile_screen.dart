import 'package:flutter/material.dart';
import 'package:nori/data/app_data.dart';
import 'package:nori/data/auth_repository.dart';
import 'package:nori/data/username_repository.dart';
import 'package:nori/models/nori_user.dart';
import 'package:nori/theme/app_theme.dart';
import 'package:nori/utils/remote_errors.dart';
import 'package:nori/widgets/nori_avatar.dart';
import 'package:nori/widgets/nori_card.dart';
import 'package:nori/widgets/nori_screen_header.dart';
import 'package:nori/widgets/nori_scroll_scaffold.dart';
import 'package:nori/widgets/nori_text_field.dart';
import 'package:nori/widgets/tactile_button.dart';

/// Pushed from [ProfileScreen]'s avatar edit pencil. Editing is scoped to the
/// three user-owned text fields [NoriUser] has ([NoriUser.name],
/// [NoriUser.username], [NoriUser.email]) — changing the avatar photo itself
/// needs an image picker that doesn't exist anywhere in the app yet, so that
/// button stays a "coming soon" stub (separate backlog item: mock profile
/// picture).
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key, required this.user});

  final NoriUser user;

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen>
    with RemoteLoadState<EditProfileScreen> {
  late final _nameController = TextEditingController(text: widget.user.name);
  late final _usernameController = TextEditingController(
    text: widget.user.username,
  );
  // The login email, not the profile doc's copy -- they differ once a
  // requested email change has been confirmed from the inbox.
  late final String _loginEmail =
      AppData.auth.currentEmail ?? widget.user.email;
  late final _emailController = TextEditingController(text: _loginEmail);

  bool _saving = false;

  /// Null while loading. A Google-only account's email belongs to Google,
  /// so the field is read-only for it.
  bool? _hasPasswordProvider;

  @override
  void initState() {
    super.initState();
    _loadPasswordProvider();
  }

  Future<void> _loadPasswordProvider() async {
    try {
      final hasPassword = await AppData.auth.hasPasswordProvider();
      if (mounted) setState(() => _hasPasswordProvider = hasPassword);
    } catch (_) {
      // Leaves the field read-only; changing the email is the rare case.
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _editPhoto() => _showMessage('Coming soon');

  Future<void> _save() async {
    if (_saving) return;

    final name = _nameController.text.trim();
    final username = _usernameController.text.trim();
    final email = _emailController.text.trim();

    if (name.isEmpty || username.isEmpty || email.isEmpty) {
      _showMessage('Please complete all fields.');
      return;
    }

    if (username.length < 3) {
      _showMessage('Username must be at least 3 characters.');
      return;
    }

    final emailChanged = email.toLowerCase() != _loginEmail.toLowerCase();
    String? password;
    if (emailChanged) {
      password = await _promptForPassword();
      if (password == null || password.isEmpty || !mounted) return;
    }

    setState(() => _saving = true);

    // First, since a wrong password should stop the whole save.
    if (password != null) {
      try {
        await AppData.auth.changeEmail(newEmail: email, password: password);
      } on AuthException catch (e) {
        if (!mounted) return;
        setState(() => _saving = false);
        _showMessage(e.message);
        return;
      } catch (_) {
        if (!mounted) return;
        setState(() => _saving = false);
        _showMessage('Unable to change your email. Please try again.');
        return;
      }
    }

    // Only touch the /usernames uniqueness index when the username
    // actually changed -- changeUsername is a no-op for that case anyway,
    // but skipping it avoids a needless transaction on every save (name-
    // only or email-only edits are the common case). See
    // UsernameRepository.changeUsername and firestore.rules's own note
    // that a change is create-new + delete-old.
    if (username.trim().toLowerCase() !=
        widget.user.username.trim().toLowerCase()) {
      try {
        await AppData.usernames.changeUsername(
          uid: widget.user.id,
          oldUsername: widget.user.username,
          newUsername: username,
        );
      } on UsernameTakenException {
        if (!mounted) return;
        setState(() => _saving = false);
        _showMessage('That username is already taken — please choose another.');
        return;
      } catch (_) {
        if (!mounted) return;
        setState(() => _saving = false);
        _showMessage('Unable to save changes. Please try again.');
        return;
      }
    }

    final ok = await guardedAction(
      // The profile keeps the login email; a new one is written here on
      // the first save after it's confirmed.
      () => AppData.user.updateProfile(
        name: name,
        username: username,
        email: _loginEmail,
      ),
    );
    if (!mounted) return;
    if (!ok) {
      setState(() => _saving = false);
      return;
    }
    if (emailChanged) {
      _showMessage(
        'We sent a link to $email. Your login email changes once you open it.',
      );
    }
    Navigator.pop(context, true);
  }

  Future<String?> _promptForPassword() async {
    final controller = TextEditingController();
    final password = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          side: const BorderSide(color: AppColors.ink, width: AppBorder.thin),
        ),
        title: const Text('Confirm Your Password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Enter your current password to change your email.'),
            const SizedBox(height: AppSpacing.gutter),
            TextField(
              controller: controller,
              autofocus: true,
              obscureText: true,
              decoration: const InputDecoration(hintText: 'Current password'),
              onSubmitted: (value) => Navigator.pop(dialogContext, value),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    controller.dispose();
    return password;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: NoriScrollScaffold(
          maxWidth: 600,
          children: [
            NoriScreenHeader(
              leading: NoriScreenHeader.backButton(context),
              title: 'Edit Profile',
              titleStyle: AppTextStyles.headlineLgMobile,
            ),
            const SizedBox(height: AppSpacing.stackMd),
            Center(
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  NoriAvatar(
                    imageUrl: widget.user.avatarUrl,
                    size: 120,
                    borderWidth: AppBorder.thick,
                  ),
                  Positioned(
                    right: -4,
                    bottom: 2,
                    child: IconButton.filled(
                      tooltip: 'Change photo',
                      onPressed: _editPhoto,
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.moss,
                        foregroundColor: AppColors.ink,
                        minimumSize: const Size.square(38),
                        side: const BorderSide(
                          color: AppColors.ink,
                          width: AppBorder.standard,
                        ),
                      ),
                      icon: const Icon(Icons.camera_alt, size: 18),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.stackMd),
            NoriCard(
              radius: AppRadius.md,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  NoriTextField(
                    controller: _nameController,
                    label: 'Full Name',
                    hint: 'Alex Human',
                    icon: Icons.person,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.name],
                  ),
                  NoriTextField(
                    controller: _usernameController,
                    label: 'Username',
                    hint: 'alex_habits',
                    icon: Icons.alternate_email,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.username],
                  ),
                  NoriTextField(
                    controller: _emailController,
                    label: 'Email',
                    hint: 'alex@example.com',
                    icon: Icons.mail,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.email],
                    readOnly: _hasPasswordProvider != true,
                    helperText: _hasPasswordProvider == false
                        ? 'Managed by your Google account.'
                        : null,
                    onSubmitted: (_) => _save(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.stackMd),
            TactileButton(
              label: _saving ? 'Saving...' : 'Save Changes',
              icon: Icons.check,
              onPressed: _saving ? null : _save,
            ),
          ],
        ),
      ),
    );
  }
}
