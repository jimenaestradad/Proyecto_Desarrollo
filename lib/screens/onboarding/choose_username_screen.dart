import 'dart:async';

import 'package:flutter/material.dart';
import 'package:nori/data/app_data.dart';
import 'package:nori/data/username_repository.dart';
import 'package:nori/theme/app_theme.dart';
import 'package:nori/widgets/loading_overlay.dart';
import 'package:nori/widgets/nori_text_field.dart';
import 'package:nori/widgets/tactile_button.dart';

enum _UsernameStatus { idle, checking, available, taken }

/// Second step of Google Sign-In (see docs/OPEN_DECISIONS.md): shown after
/// Google auth succeeds for a uid that hasn't claimed a Nori username yet
/// — either a brand-new sign-up, or a previous attempt that authenticated
/// with Google and then got interrupted before finishing this step.
///
/// Pushed from login_screen.dart's _completeGoogleSignIn, which passes the
/// already-authenticated uid/email and a suggested starting username. Pops
/// with the claimed username string on success; this screen has no back
/// button because canceling here would leave a signed-in Google account
/// with no username and nowhere else in the app to resolve that — see
/// docs/OPEN_DECISIONS.md if "abandon sign-up here" needs a real answer.
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

class _ChooseUsernameScreenState extends State<ChooseUsernameScreen> {
  late final _usernameController = TextEditingController(
    text: widget.suggestedUsername,
  );

  bool _loading = false;
  Timer? _usernameDebounce;
  _UsernameStatus _usernameStatus = _UsernameStatus.idle;

  @override
  void initState() {
    super.initState();
    // Check the pre-filled suggestion right away instead of waiting for a
    // keystroke that may never come if the person likes the suggestion.
    _onUsernameChanged(widget.suggestedUsername);
  }

  @override
  void dispose() {
    _usernameDebounce?.cancel();
    _usernameController.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _onUsernameChanged(String value) {
    _usernameDebounce?.cancel();
    final username = value.trim();
    if (username.length < 3) {
      setState(() => _usernameStatus = _UsernameStatus.idle);
      return;
    }

    setState(() => _usernameStatus = _UsernameStatus.checking);
    _usernameDebounce = Timer(const Duration(milliseconds: 400), () async {
      bool available;
      try {
        available = await AppData.usernames.isAvailable(username);
      } catch (_) {
        if (!mounted || _usernameController.text.trim() != username) return;
        setState(() => _usernameStatus = _UsernameStatus.idle);
        return;
      }
      if (!mounted || _usernameController.text.trim() != username) return;
      setState(
        () => _usernameStatus = available
            ? _UsernameStatus.available
            : _UsernameStatus.taken,
      );
    });
  }

  Future<void> _submit() async {
    if (_loading) return;
    FocusScope.of(context).unfocus();

    final username = _usernameController.text.trim();
    if (username.length < 3) {
      _showMessage('Username must be at least 3 characters.');
      return;
    }
    if (_usernameStatus == _UsernameStatus.taken) {
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
        _usernameStatus = _UsernameStatus.taken;
      });
      _showMessage('That username was just taken — please pick another.');
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showMessage('Unable to claim that username. Please try again.');
    }
  }

  Widget? get _suffixIcon {
    switch (_usernameStatus) {
      case _UsernameStatus.idle:
        return null;
      case _UsernameStatus.checking:
        return const Padding(
          padding: EdgeInsets.all(14),
          child: SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        );
      case _UsernameStatus.available:
        return const Icon(Icons.check_circle, color: AppColors.moss);
      case _UsernameStatus.taken:
        return const Icon(Icons.cancel, color: AppColors.error);
    }
  }

  String? get _helperText {
    switch (_usernameStatus) {
      case _UsernameStatus.idle:
      case _UsernameStatus.checking:
        return null;
      case _UsernameStatus.available:
        return 'Username is available';
      case _UsernameStatus.taken:
        return 'Username is already taken';
    }
  }

  Color? get _helperColor {
    switch (_usernameStatus) {
      case _UsernameStatus.taken:
        return AppColors.error;
      case _UsernameStatus.available:
        return AppColors.mossDark;
      case _UsernameStatus.idle:
      case _UsernameStatus.checking:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // See the class doc — leaving this screen mid-flow would strand a
      // signed-in Google account with no username, so the system back
      // gesture/button is disabled the same way the missing AppBar back
      // button is.
      canPop: false,
      child: Scaffold(
        body: Stack(
          children: [
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.containerPaddingMobile,
                      vertical: AppSpacing.stackMd,
                    ),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight:
                            constraints.maxHeight - (AppSpacing.stackMd * 2),
                      ),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 420),
                          child: Container(
                            padding: const EdgeInsets.all(AppSpacing.stackMd),
                            decoration: BoxDecoration(
                              color: AppColors.white,
                              borderRadius: BorderRadius.circular(
                                AppRadius.lg,
                              ),
                              border: Border.all(
                                color: AppColors.ink,
                                width: AppBorder.standard,
                              ),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 64,
                                  height: 64,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: AppColors.ink,
                                      width: AppBorder.thick,
                                    ),
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
                                Text(
                                  'Pick a username',
                                  style: AppTextStyles.headlineLgMobile,
                                ),
                                const SizedBox(height: AppSpacing.unit),
                                Text(
                                  'Signed in as ${widget.email}. Choose a '
                                  'username to finish setting up your Nori '
                                  'account.',
                                  style: AppTextStyles.bodyMd.copyWith(
                                    color: AppColors.inkMuted,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: AppSpacing.stackMd),
                                NoriTextField(
                                  controller: _usernameController,
                                  label: 'Username',
                                  hint: 'alex_habits',
                                  icon: Icons.alternate_email,
                                  textInputAction: TextInputAction.done,
                                  onChanged: _onUsernameChanged,
                                  onSubmitted: (_) => _submit(),
                                  suffixIcon: _suffixIcon,
                                  helperText: _helperText,
                                  helperColor: _helperColor,
                                ),
                                const SizedBox(height: AppSpacing.unit),
                                TactileButton(
                                  label: 'Continue',
                                  icon: Icons.arrow_forward,
                                  onPressed: _loading ? null : _submit,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            if (_loading) const LoadingOverlay(),
          ],
        ),
      ),
    );
  }
}
