import 'package:flutter/material.dart';
import 'package:nori/data/app_data.dart';
import 'package:nori/theme/app_theme.dart';
import 'package:nori/widgets/tactile_button.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _loading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
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

    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      _showMessage('Please enter your email and password.');
      return;
    }

    setState(() => _loading = true);

    try {
      await AppData.auth.logIn(email: email, password: password);
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showMessage('Unable to sign in. Please try again.');
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
                              const _LoginHeader(),
                              const SizedBox(height: AppSpacing.stackMd),
                              _socialButton(
                                label: 'Continue with Google',
                                icon: Icons.g_mobiledata,
                                onPressed: () => _showMessage('Coming soon'),
                              ),
                              const SizedBox(height: AppSpacing.stackMd),
                              const _Divider(),
                              const SizedBox(height: AppSpacing.stackMd),
                              _buildEmailField(),
                              const SizedBox(height: AppSpacing.gutter),
                              _buildPasswordField(),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: () => _showMessage('Coming soon'),
                                  child: const Text('Forgot Password?'),
                                ),
                              ),
                              const SizedBox(height: AppSpacing.unit),
                              TactileButton(
                                label: 'Sign In',
                                icon: Icons.arrow_forward,
                                onPressed: _loading ? null : _submit,
                              ),
                              const SizedBox(height: AppSpacing.stackLg),
                              Wrap(
                                alignment: WrapAlignment.center,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Text(
                                    "Don't have an account?",
                                    style: AppTextStyles.bodyMd.copyWith(
                                      color: AppColors.inkMuted,
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: _loading
                                        ? null
                                        : () => Navigator.pushReplacementNamed(
                                            context,
                                            '/signup',
                                          ),
                                    child: const Text('Sign Up'),
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
          if (_loading) const _LoadingOverlay(),
        ],
      ),
    );
  }

  Widget _socialButton({
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 24),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          backgroundColor: AppColors.linenAlt,
          foregroundColor: AppColors.ink,
          minimumSize: const Size.fromHeight(48),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.stackMd,
            vertical: AppSpacing.stackSm,
          ),
          textStyle: AppTextStyles.labelLg,
          side: const BorderSide(color: AppColors.ink, width: AppBorder.standard),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.full),
          ),
        ),
      ),
    );
  }

  Widget _buildEmailField() {
    return TextField(
      controller: _emailController,
      keyboardType: TextInputType.emailAddress,
      textInputAction: TextInputAction.next,
      autofillHints: const [AutofillHints.email],
      style: AppTextStyles.bodyMd,
      decoration: _inputDecoration(hint: 'Email Address', icon: Icons.mail),
    );
  }

  Widget _buildPasswordField() {
    return TextField(
      controller: _passwordController,
      obscureText: _obscurePassword,
      enableSuggestions: false,
      autocorrect: false,
      textInputAction: TextInputAction.done,
      autofillHints: const [AutofillHints.password],
      onSubmitted: (_) => _submit(),
      style: AppTextStyles.bodyMd,
      decoration: _inputDecoration(
        hint: 'Password',
        icon: Icons.lock,
        suffixIcon: IconButton(
          tooltip: _obscurePassword ? 'Show password' : 'Hide password',
          onPressed: () {
            setState(() => _obscurePassword = !_obscurePassword);
          },
          icon: Icon(
            _obscurePassword ? Icons.visibility_off : Icons.visibility,
            color: AppColors.inkMuted,
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    final radius = BorderRadius.circular(AppRadius.md);
    final border = OutlineInputBorder(
      borderRadius: radius,
      borderSide: const BorderSide(
        color: AppColors.ink,
        width: AppBorder.standard,
      ),
    );

    return InputDecoration(
      hintText: hint,
      hintStyle: AppTextStyles.bodyMd.copyWith(color: AppColors.inkFaint),
      prefixIcon: Icon(icon, color: AppColors.ink),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: AppColors.linenAlt,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.gutter,
        vertical: AppSpacing.gutter,
      ),
      border: border,
      enabledBorder: border,
      focusedBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: const BorderSide(
          color: AppColors.ink,
          width: AppBorder.thick,
        ),
      ),
    );
  }
}

class _LoginHeader extends StatelessWidget {
  const _LoginHeader();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: AppColors.mossLight,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.ink, width: AppBorder.thick),
          ),
          child: const Icon(
            Icons.pets,
            color: AppColors.mossDark,
            size: 36,
          ),
        ),
        const SizedBox(height: AppSpacing.gutter),
        Text(
          'Welcome Back',
          style: AppTextStyles.headlineLgMobile.copyWith(
            color: AppColors.mossDark,
          ),
        ),
        const SizedBox(height: AppSpacing.unit),
        Text(
          'Sign in to continue your habit journey',
          style: AppTextStyles.bodyMd.copyWith(
            color: AppColors.inkMuted,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Divider(
            color: AppColors.ink.withValues(alpha: 0.35),
            thickness: AppBorder.thin,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
          child: Text(
            'Or',
            style: AppTextStyles.labelSm.copyWith(color: AppColors.inkMuted),
          ),
        ),
        Expanded(
          child: Divider(
            color: AppColors.ink.withValues(alpha: 0.35),
            thickness: AppBorder.thin,
          ),
        ),
      ],
    );
  }
}

class _LoadingOverlay extends StatelessWidget {
  const _LoadingOverlay();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: ColoredBox(
        color: AppColors.linen.withValues(alpha: 0.72),
        child: const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}
