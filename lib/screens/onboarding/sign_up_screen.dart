import 'package:flutter/material.dart';
import 'package:nori/data/app_data.dart';
import 'package:nori/theme/app_theme.dart';
import 'package:nori/widgets/loading_overlay.dart';
import 'package:nori/widgets/nori_text_field.dart';
import 'package:nori/widgets/tactile_button.dart';

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

  @override
  void dispose() {
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

    if (password != confirmPassword) {
      _showMessage('Passwords do not match.');
      return;
    }

    setState(() => _loading = true);

    try {
      await AppData.auth.signUp(
        name: name,
        username: username,
        email: email,
        password: password,
      );
      await AppData.user.updateProfile(
        name: name,
        username: username,
        email: email,
      );
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showMessage('Unable to create your account. Please try again.');
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
          style: AppTextStyles.bodyMd.copyWith(
            color: AppColors.inkMuted,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
