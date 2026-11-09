import 'package:flutter/material.dart';
import 'package:nori/data/app_data.dart';
import 'package:nori/data/username_repository.dart';
import 'package:nori/screens/onboarding/username_availability.dart';
import 'package:nori/theme/app_theme.dart';
import 'package:nori/utils/app_log.dart';
import 'package:nori/utils/validators.dart';
import 'package:nori/widgets/auth_card_screen.dart';
import 'package:nori/widgets/nori_text_field.dart';
import 'package:nori/widgets/tactile_button.dart';

/// Claims a username after Google auth for new or interrupted sign-ups.
/// Receives the authenticated uid/email and suggestion; pops with the claimed name.
/// No back button: cancellation would strand an account without a username.
/// The one way out is [_useDifferentAccount]: it signs out, which leaves the
/// account (and its empty profile) behind, harmless and picked up again if
/// that account ever signs in.
class ChooseUsernameScreen extends StatefulWidget {
  const ChooseUsernameScreen({
    super.key,
    required this.uid,
    required this.email,
    required this.suggestedUsername,
  });

  final String uid;
  final String email;
  final String suggestedUsername;

  @override
  State<ChooseUsernameScreen> createState() => _ChooseUsernameScreenState();
}

class _ChooseUsernameScreenState extends State<ChooseUsernameScreen>
    with UsernameAvailability<ChooseUsernameScreen> {
  late final _usernameController = TextEditingController(
    text: widget.suggestedUsername,
  );

  @override
  TextEditingController get usernameController => _usernameController;

  bool _loading = false;

  @override
  void initState() {
    super.initState();
    // Check the pre-filled suggestion right away instead of waiting for a
    // keystroke that may never come if the person likes the suggestion.
    onUsernameChanged(widget.suggestedUsername);
  }

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _submit() async {
    if (_loading) return;
    FocusScope.of(context).unfocus();

    final username = _usernameController.text.trim();
    final problem = validateUsername(username);
    if (problem != null) {
      _showMessage(problem);
      return;
    }
    if (usernameStatus == UsernameStatus.taken) {
      _showMessage('That username is already taken — please choose another.');
      return;
    }

    setState(() => _loading = true);
    try {
      await AppData.usernames.claim(username: username, uid: widget.uid);
      if (!mounted) return;
      Navigator.pop(context, username);
    } on UsernameTakenException {
      if (!mounted) return;
      setState(() {
        _loading = false;
        usernameStatus = UsernameStatus.taken;
      });
      _showMessage('That username was just taken — please pick another.');
    } catch (error, stackTrace) {
      logError('claimUsername', error, stackTrace);
      if (!mounted) return;
      setState(() => _loading = false);
      _showMessage('Unable to claim that username. Please try again.');
    }
  }

  /// For someone who got here with the wrong account (the wrong Google
  /// account in the picker, say): without this the only way out was to kill
  /// the app, which reopened on this same screen because the session persists.
  Future<void> _useDifferentAccount() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      await AppData.auth.logOut();
    } catch (error, stackTrace) {
      logError('logOut (username picker)', error, stackTrace);
      if (!mounted) return;
      setState(() => _loading = false);
      _showMessage("Couldn't sign out. Please try again.");
      return;
    }
    AppData.unbindUser();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/welcome', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // See the class doc — leaving this screen mid-flow would strand a
      // signed-in Google account with no username, so the system back
      // gesture/button is disabled the same way the missing AppBar back
      // button is.
      canPop: false,
      child: AuthCardScreen(
        loading: _loading,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.ink, width: AppBorder.thick),
            ),
            child: ClipOval(
              child: Image.asset(
                'assets/images/nori_closeup.png',
                width: 64,
                height: 64,
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.stackSm),
          Text('Pick a username', style: AppTextStyles.headlineLgMobile),
          const SizedBox(height: AppSpacing.unit),
          Text(
            'Signed in as ${widget.email}. Choose a '
            'username to finish setting up your Nori '
            'account.',
            style: AppTextStyles.bodyMd.copyWith(color: AppColors.inkMuted),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.stackMd),
          NoriTextField(
            controller: _usernameController,
            label: 'Username',
            hint: 'alex_habits',
            icon: Icons.alternate_email,
            textInputAction: TextInputAction.done,
            inputFormatters: usernameInputFormatters,
            onChanged: onUsernameChanged,
            onSubmitted: (_) => _submit(),
            suffixIcon: usernameSuffixIcon,
            helperText: usernameHelperText,
            helperColor: usernameHelperColor,
          ),
          const SizedBox(height: AppSpacing.unit),
          TactileButton(
            label: 'Continue',
            icon: Icons.arrow_forward,
            onPressed: _loading ? null : _submit,
          ),
          TextButton(
            onPressed: _loading ? null : _useDifferentAccount,
            child: const Text('Not you? Use a different account'),
          ),
        ],
      ),
    );
  }
}
