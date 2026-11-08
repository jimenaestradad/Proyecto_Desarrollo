import 'package:flutter/material.dart';
import 'package:nori/data/app_data.dart';
import 'package:nori/data/auth_repository.dart';
import 'package:nori/data/session_photos.dart';
import 'package:nori/data/username_repository.dart';
import 'package:nori/utils/photo_picker.dart';
import 'package:nori/utils/validators.dart';
import 'package:nori/models/nori_user.dart';
import 'package:nori/screens/onboarding/username_availability.dart';
import 'package:nori/theme/app_theme.dart';
import 'package:nori/utils/app_log.dart';
import 'package:nori/utils/remote_errors.dart';
import 'package:nori/widgets/nori_avatar.dart';
import 'package:nori/widgets/nori_card.dart';
import 'package:nori/widgets/nori_screen_header.dart';
import 'package:nori/widgets/nori_scroll_scaffold.dart';
import 'package:nori/widgets/nori_text_field.dart';
import 'package:nori/widgets/tactile_button.dart';

/// Edits [NoriUser.name], [NoriUser.username] and [NoriUser.email] from Profile.
/// Avatar-photo editing remains a coming-soon stub pending an image picker.
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key, required this.user});

  final NoriUser user;

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen>
    with
        RemoteLoadState<EditProfileScreen>,
        UsernameAvailability<EditProfileScreen> {
  late final _nameController = TextEditingController(text: widget.user.name);
  late final _usernameController = TextEditingController(
    text: widget.user.username,
  );

  @override
  TextEditingController get usernameController => _usernameController;

  /// Live availability check, skipped while the field still holds the
  /// person's own current username (that one is always "taken" by them).
  void _onUsernameEdited(String value) {
    final unchanged =
        value.trim().toLowerCase() == widget.user.username.trim().toLowerCase();
    if (unchanged) {
      setState(() => usernameStatus = UsernameStatus.idle);
      return;
    }
    onUsernameChanged(value);
  }

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
    } catch (error, stackTrace) {
      logError('hasPasswordProvider', error, stackTrace);
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

  Future<void> _editPhoto() async {
    final bytes = await pickPhoto(context);
    if (bytes == null || !mounted) return;
    SessionPhotos.avatar.value = bytes;
    _showMessage('Photo set for this session.');
  }

  Future<void> _save() async {
    if (_saving) return;

    final name = _nameController.text.trim();
    final username = _usernameController.text.trim();
    final email = _emailController.text.trim();

    if (name.isEmpty || username.isEmpty || email.isEmpty) {
      _showMessage('Please complete all fields.');
      return;
    }

    // An unchanged username or email is left alone: accounts made before
    // these checks existed may not match them.
    final usernameChanged =
        username.toLowerCase() != widget.user.username.trim().toLowerCase();
    final problem =
        validateName(name) ??
        (usernameChanged ? validateUsername(username) : null) ??
        (email.toLowerCase() != _loginEmail.toLowerCase()
            ? validateEmail(email)
            : null);
    if (problem != null) {
      _showMessage(problem);
      return;
    }

    if (usernameStatus == UsernameStatus.taken) {
      _showMessage('That username is already taken — please choose another.');
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
      } catch (error, stackTrace) {
        logError('changeEmail', error, stackTrace);
        if (!mounted) return;
        setState(() => _saving = false);
        _showMessage('Unable to change your email. Please try again.');
        return;
      }
    }

    // Update the /usernames index only when the normalized username changes,
    // avoiding a needless transaction for name-only or email-only saves.
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
      } catch (error, stackTrace) {
        logError('changeUsername', error, stackTrace);
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

  Future<String?> _promptForPassword() => showDialog<String>(
    context: context,
    builder: (_) => const _ConfirmPasswordDialog(),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: NoriScrollScaffold(
          maxWidth: 600,
          children: [
            NoriScreenHeader(
              leading: NoriScreenHeader.backButton(context),
              title: 'Edit profile',
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
                    label: 'Full name',
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
                    onChanged: _onUsernameEdited,
                    suffixIcon: usernameSuffixIcon,
                    helperText: usernameHelperText,
                    helperColor: usernameHelperColor,
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
              label: _saving ? 'Saving...' : 'Save changes',
              icon: Icons.check,
              onPressed: _saving ? null : _save,
            ),
          ],
        ),
      ),
    );
  }
}

/// Asks for the current password before an email change. Owns its
/// controller so it's disposed with the dialog, after the close animation —
/// disposing right after `showDialog` returns left the still-animating field
/// on a dead controller.
class _ConfirmPasswordDialog extends StatefulWidget {
  const _ConfirmPasswordDialog();

  @override
  State<_ConfirmPasswordDialog> createState() => _ConfirmPasswordDialogState();
}

class _ConfirmPasswordDialogState extends State<_ConfirmPasswordDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        side: const BorderSide(color: AppColors.ink, width: AppBorder.thin),
      ),
      title: const Text('Confirm your password'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Enter your current password to change your email.'),
          const SizedBox(height: AppSpacing.gutter),
          TextField(
            controller: _controller,
            autofocus: true,
            obscureText: true,
            decoration: const InputDecoration(hintText: 'Current password'),
            onSubmitted: (value) => Navigator.pop(context, value),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _controller.text),
          child: const Text('Continue'),
        ),
      ],
    );
  }
}
