import 'dart:async';

import 'package:flutter/material.dart';
import 'package:nori/data/app_data.dart';
import 'package:nori/data/auth_repository.dart';
import 'package:nori/data/username_repository.dart';
import 'package:nori/screens/onboarding/name_pet_screen.dart';
import 'package:nori/theme/app_theme.dart';
import 'package:nori/widgets/loading_overlay.dart';
import 'package:nori/widgets/nori_text_field.dart';
import 'package:nori/widgets/tactile_button.dart';

enum _UsernameStatus { idle, checking, available, taken }

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _loading = false;

  Timer? _usernameDebounce;
  _UsernameStatus _usernameStatus = _UsernameStatus.idle;

  /// Set when a Firebase Auth account was created but claiming its
  /// username then failed (someone else grabbed it in that instant).
  /// Sticky for the rest of this screen's lifetime regardless of what they
  /// retype next — [_submit] must never call signUp() a second time for
  /// the same person (it would fail with email-already-in-use); it just
  /// needs to claim a (possibly different) username for this uid.
  String? _uidPendingUsername;

  @override
  void dispose() {
    _usernameDebounce?.cancel();
    _nameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
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
    if (username.isEmpty) {
      setState(() => _usernameStatus = _UsernameStatus.idle);
      return;
    }
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
        // Can't reach Firestore right now — don't block typing on it, the
        // atomic claim at submit time is the real backstop either way.
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

    final name = _nameController.text.trim();
    final username = _usernameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if ([
      name,
      username,
      email,
      password,
      confirmPassword,
    ].any((value) => value.isEmpty)) {
      _showMessage('Please complete all required fields.');
      return;
    }

    if (username.length < 3) {
      _showMessage('Username must be at least 3 characters.');
      return;
    }

    if (password != confirmPassword) {
      _showMessage('Passwords do not match.');
      return;
    }

    if (_usernameStatus == _UsernameStatus.taken) {
      _showMessage('That username is already taken — please choose another.');
      return;
    }

    setState(() => _loading = true);

    try {
      final String uid;
      if (_uidPendingUsername != null) {
        // The account already exists from a previous attempt on this
        // screen — only the username claim failed. Reuse that account
        // instead of calling signUp() again (which would fail with
        // email-already-in-use).
        uid = _uidPendingUsername!;
      } else {
        final user = await AppData.auth.signUp(
          name: name,
          username: username,
          email: email,
          password: password,
        );
        uid = user.id;
      }

      // Point AppData.user (etc.) at this uid's real Firestore data before
      // touching it below — see AppData.bindToUser. Safe to call again on
      // a retried username claim too (rebinding to the same uid is a
      // no-op in practice).
      AppData.bindToUser(uid);

      try {
        await AppData.usernames.claim(username: username, uid: uid);
      } on UsernameTakenException {
        _uidPendingUsername = uid;
        if (!mounted) return;
        setState(() {
          _loading = false;
          _usernameStatus = _UsernameStatus.taken;
        });
        _showMessage(
          'That username was just taken — pick another one to finish creating your account.',
        );
        return;
      }

      await AppData.user.updateProfile(
        name: name,
        username: username,
        email: email,
      );
      if (!mounted) return;
      // Last onboarding step: let them name their pet (or skip and keep
      // 'Nori') before landing on Home -- see NamePetScreen's doc comment.
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const NamePetScreen()),
      );
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showMessage(e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showMessage('Unable to create your account. Please try again.');
    }
  }

  Widget? get _usernameSuffixIcon {
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

  String? get _usernameHelperText {
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

  Color? get _usernameHelperColor {
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
    return Scaffold(
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
                            borderRadius: BorderRadius.circular(AppRadius.lg),
                            border: Border.all(
                              color: AppColors.ink,
                              width: AppBorder.standard,
                            ),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const _SignUpHeader(),
                              const SizedBox(height: AppSpacing.stackMd),
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
                                onChanged: _onUsernameChanged,
                                suffixIcon: _usernameSuffixIcon,
                                helperText: _usernameHelperText,
                                helperColor: _usernameHelperColor,
                              ),
                              NoriTextField(
                                controller: _emailController,
                                label: 'Email',
                                hint: 'alex@example.com',
                                icon: Icons.mail,
                                keyboardType: TextInputType.emailAddress,
                                textInputAction: TextInputAction.next,
                                autofillHints: const [AutofillHints.email],
                              ),
                              NoriTextField(
                                controller: _passwordController,
                                label: 'Password',
                                hint: '••••••••',
                                icon: Icons.lock,
                                obscureText: true,
                                textInputAction: TextInputAction.next,
                                autofillHints: const [
                                  AutofillHints.newPassword,
                                ],
                              ),
                              NoriTextField(
                                controller: _confirmPasswordController,
                                label: 'Confirm Password',
                                hint: '••••••••',
                                icon: Icons.password,
                                obscureText: true,
                                textInputAction: TextInputAction.done,
                                onSubmitted: (_) => _submit(),
                              ),
                              const SizedBox(height: AppSpacing.unit),
                              TactileButton(
                                label: 'Create Account',
                                icon: Icons.arrow_forward,
                                onPressed: _loading ? null : _submit,
                              ),
                              const SizedBox(height: AppSpacing.stackMd),
                              Wrap(
                                alignment: WrapAlignment.center,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Text(
                                    'Already have an account?',
                                    style: AppTextStyles.bodyMd.copyWith(
                                      color: AppColors.inkMuted,
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: _loading
                                        ? null
                                        : () => Navigator.pushReplacementNamed(
                                            context,
                                            '/login',
                                          ),
                                    child: const Text('Log In'),
                                  ),
                                ],
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
    );
  }
}

class _SignUpHeader extends StatelessWidget {
  const _SignUpHeader();

  @override
  Widget build(BuildContext context) {
    return Column(
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
        Text('Join Nori', style: AppTextStyles.headlineLgMobile),
        const SizedBox(height: AppSpacing.unit),
        Text(
          'Start building better habits today.',
          style: AppTextStyles.bodyMd.copyWith(color: AppColors.inkMuted),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
