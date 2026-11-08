import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nori/data/app_data.dart';
import 'package:nori/data/auth_repository.dart';
import 'package:nori/data/username_repository.dart';
import 'package:nori/screens/onboarding/name_pet_screen.dart';
import 'package:nori/screens/onboarding/username_availability.dart';
import 'package:nori/theme/app_theme.dart';
import 'package:nori/utils/app_log.dart';
import 'package:nori/utils/validators.dart';
import 'package:nori/widgets/auth_card_screen.dart';
import 'package:nori/widgets/nori_text_field.dart';
import 'package:nori/widgets/tactile_button.dart';
import 'package:nori/widgets/password_rules.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen>
    with UsernameAvailability<SignUpScreen> {
  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();

  @override
  TextEditingController get usernameController => _usernameController;
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _loading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // Remember completed sign-up steps so retries resume at username/profile writes.
  // Once the Auth account exists, calling signUp again would fail with email-already-in-use.
  String? _createdUid;

  /// The email the account was created with: the profile must keep matching
  /// it even if the field is edited before a retry.
  String? _createdEmail;

  /// Set once the username claim succeeded; later retries reuse it.
  String? _claimedUsername;

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
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

    final problem =
        validateName(name) ??
        validateUsername(username) ??
        validateEmail(email) ??
        validateNewPassword(password);
    if (problem != null) {
      _showMessage(problem);
      return;
    }

    if (password != confirmPassword) {
      _showMessage('Passwords do not match.');
      return;
    }

    if (usernameStatus == UsernameStatus.taken) {
      _showMessage('That username is already taken — please choose another.');
      return;
    }

    setState(() => _loading = true);

    try {
      if (_createdUid == null) {
        final user = await AppData.auth.signUp(
          name: name,
          username: username,
          email: email,
          password: password,
        );
        _createdUid = user.id;
        _createdEmail = email;
      }
      final uid = _createdUid!;

      // Point AppData.user (etc.) at this uid's real Firestore data before
      // touching it below — see AppData.bindToUser. Safe to call again on
      // a retry (rebinding to the same uid is a no-op in practice).
      AppData.bindToUser(uid);

      if (_claimedUsername == null) {
        try {
          await AppData.usernames.claim(username: username, uid: uid);
          _claimedUsername = username;
        } on UsernameTakenException {
          if (!mounted) return;
          setState(() {
            _loading = false;
            usernameStatus = UsernameStatus.taken;
          });
          _showMessage(
            'That username was just taken — pick another one to finish creating your account.',
          );
          return;
        }
      }

      await AppData.user.updateProfile(
        name: name,
        username: _claimedUsername,
        email: _createdEmail,
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
    } catch (error, stackTrace) {
      logError(
        _createdUid == null ? 'signUp' : 'signUp (post-account setup)',
        error,
        stackTrace,
      );
      if (!mounted) return;
      setState(() => _loading = false);
      _showMessage(
        _createdUid == null
            ? 'Unable to create your account. Please try again.'
            : 'Your account was created, but setup didn’t finish. '
                  'Tap Create account again to retry.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthCardScreen(
      loading: _loading,
      children: [
        const _SignUpHeader(),
        const SizedBox(height: AppSpacing.stackMd),
        NoriTextField(
          controller: _nameController,
          label: 'Full name',
          hint: 'Alex Human',
          icon: Icons.person,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.name],
          inputFormatters: [LengthLimitingTextInputFormatter(nameMaxLength)],
        ),
        NoriTextField(
          controller: _usernameController,
          label: 'Username',
          hint: 'alex_habits',
          icon: Icons.alternate_email,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.username],
          inputFormatters: usernameInputFormatters,
          onChanged: onUsernameChanged,
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
          autofillHints: const [AutofillHints.newPassword],
        ),
        Padding(
          padding: const EdgeInsets.only(
            left: AppSpacing.gutter,
            bottom: AppSpacing.gutter,
          ),
          child: PasswordRules(controller: _passwordController),
        ),
        NoriTextField(
          controller: _confirmPasswordController,
          label: 'Confirm password',
          hint: '••••••••',
          icon: Icons.password,
          obscureText: true,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _submit(),
        ),
        const SizedBox(height: AppSpacing.unit),
        TactileButton(
          label: 'Create account',
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
              style: AppTextStyles.bodyMd.copyWith(color: AppColors.inkMuted),
            ),
            TextButton(
              onPressed: _loading
                  ? null
                  : () => Navigator.pushReplacementNamed(context, '/login'),
              child: const Text('Log in'),
            ),
          ],
        ),
      ],
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
