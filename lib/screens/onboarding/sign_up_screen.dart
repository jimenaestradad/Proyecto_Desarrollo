import 'package:flutter/material.dart';
import 'package:nori/data/app_data.dart';
import 'package:nori/data/auth_repository.dart';
import 'package:nori/data/username_repository.dart';
import 'package:nori/screens/onboarding/name_pet_screen.dart';
import 'package:nori/screens/onboarding/username_availability.dart';
import 'package:nori/theme/app_theme.dart';
import 'package:nori/widgets/loading_overlay.dart';
import 'package:nori/widgets/nori_card.dart';
import 'package:nori/widgets/nori_text_field.dart';
import 'package:nori/widgets/tactile_button.dart';

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

  // What's already done, kept for the rest of this screen's lifetime so a
  // retry resumes where the last attempt stopped. Once the Firebase Auth
  // account exists, [_submit] must never call signUp() again for the same
  // person (it would fail with email-already-in-use): it picks up from the
  // first step that hasn't succeeded yet — claim the username, then write
  // the profile. Whatever got that far (a taken username, a profile write
  // that timed out right after sign-up) is retried from here.
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

    if (username.length < 3) {
      _showMessage('Username must be at least 3 characters.');
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
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showMessage(
        _createdUid == null
            ? 'Unable to create your account. Please try again.'
            : 'Your account was created, but setup didn’t finish. '
                  'Tap Create Account again to retry.',
      );
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
                          (constraints.maxHeight - (AppSpacing.stackMd * 2))
                              .clamp(0.0, double.infinity),
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 420),
                        child: NoriCard(
                          padding: const EdgeInsets.all(AppSpacing.stackMd),
                          radius: AppRadius.lg,
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
