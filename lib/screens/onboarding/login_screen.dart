import 'package:flutter/material.dart';
import 'package:nori/data/app_data.dart';
import 'package:nori/data/auth_repository.dart';
import 'package:nori/data/username_repository.dart';
import 'package:nori/screens/onboarding/choose_username_screen.dart';
import 'package:nori/screens/onboarding/name_pet_screen.dart';
import 'package:nori/theme/app_theme.dart';
import 'package:nori/widgets/loading_overlay.dart';
import 'package:nori/widgets/nori_card.dart';
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
      final user = await AppData.auth.logIn(email: email, password: password);
      // Point AppData.user (etc.) at this uid's real Firestore data before
      // touching it below — see AppData.bindToUser.
      AppData.bindToUser(user.id);
      // Keeps the stored email in sync with the login email, in case a
      // confirmed email change happened since the last sign-in. Name and
      // username are left alone: Edit Profile owns them in Firestore, and
      // the Auth display name this would copy is only set at sign-up, so
      // writing it here reverted every name edit on the next login.
      await AppData.user.updateProfile(email: user.email);
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showMessage(e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showMessage('Unable to sign in. Please try again.');
    }
  }

  Future<void> _handleGoogleSignIn() async {
    if (_loading) return;
    setState(() => _loading = true);

    try {
      final result = await AppData.auth.logInWithGoogle();
      await _completeGoogleSignIn(result);
    } on GoogleAccountLinkingRequired catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      await _resolveAccountLinking(e);
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      // A canceled picker isn't worth a scary error message.
      if (e.message != 'Sign-in was canceled.') _showMessage(e.message);
    } catch (error, stackTrace) {
      // Anything here is *not* a FirebaseAuthException (those are already
      // turned into AuthException with a real message above) — most
      // likely Firestore rejecting/failing the needsUsername lookup
      // (not enabled yet, or rules not deployed — see firestore.rules).
      // Logged instead of silently swallowed so that case is diagnosable
      // from the terminal/DevTools console instead of just this generic
      // snackbar.
      debugPrint('Google sign-in failed: $error');
      debugPrint('$stackTrace');
      if (!mounted) return;
      setState(() => _loading = false);
      _showMessage('Unable to sign in with Google. Please try again.');
    }
  }

  /// Finishes a Google sign-in/sign-up once we have a [GoogleSignInResult]
  /// — either straight from [AppData.auth.logInWithGoogle], or after
  /// [_resolveAccountLinking] connects an existing password account.
  /// Routes through [ChooseUsernameScreen] first when the account doesn't
  /// have a username claimed yet.
  Future<void> _completeGoogleSignIn(GoogleSignInResult result) async {
    // Point AppData.user (etc.) at this uid's real Firestore data before
    // touching it anywhere below — see AppData.bindToUser.
    AppData.bindToUser(result.user.id);
    var username = result.user.username;
    if (result.needsUsername) {
      if (!mounted) return;
      setState(() => _loading = false);
      final chosenUsername = await Navigator.push<String>(
        context,
        MaterialPageRoute(
          builder: (context) => ChooseUsernameScreen(
            uid: result.user.id,
            email: result.user.email,
            suggestedUsername: suggestUsernameFromEmail(result.user.email),
          ),
        ),
      );
      // No back button on that screen (see its class doc) — null here
      // only means the widget was somehow torn down mid-flow, not a
      // deliberate cancel. Either way there's no username to proceed with.
      if (chosenUsername == null || !mounted) return;
      username = chosenUsername;
      setState(() => _loading = true);
    }

    // Name and username only for a brand-new account — for a returning one
    // they'd overwrite what Edit Profile saved (see the email login above).
    final isNew = result.needsUsername;
    await AppData.user.updateProfile(
      name: isNew ? result.user.name : null,
      username: isNew ? username : null,
      email: result.user.email,
    );
    if (!mounted) return;
    if (result.needsUsername) {
      // Brand-new account (that's what routed it through the username
      // picker above) -- also offer the last onboarding step, naming the
      // pet. An existing Google account signing back in skips straight to
      // Home, same as before.
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const NamePetScreen()),
      );
      if (!mounted) return;
    }
    Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
  }

  /// Handles [GoogleAccountLinkingRequired]: that email already has a
  /// password-based Nori account, so this asks for that password and
  /// links the two via [AuthRepository.linkGoogleAccount] rather than
  /// just showing the raw Firebase error.
  Future<void> _resolveAccountLinking(GoogleAccountLinkingRequired e) async {
    final password = await showDialog<String>(
      context: context,
      builder: (_) => _LinkPasswordDialog(email: e.email),
    );
    if (password == null || password.isEmpty || !mounted) return;

    setState(() => _loading = true);
    try {
      final result = await AppData.auth.linkGoogleAccount(
        email: e.email,
        password: password,
        pendingCredential: e.pendingCredential,
      );
      await _completeGoogleSignIn(result);
    } on AuthException catch (err) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showMessage(err.message);
    } catch (error, stackTrace) {
      debugPrint('Google account linking failed: $error');
      debugPrint('$stackTrace');
      if (!mounted) return;
      setState(() => _loading = false);
      _showMessage('Unable to connect your account. Please try again.');
    }
  }

  Future<void> _forgotPassword() async {
    if (_loading) return;
    final email = await showDialog<String>(
      context: context,
      builder: (_) =>
          _ResetPasswordDialog(initialEmail: _emailController.text.trim()),
    );
    if (email == null || email.isEmpty || !mounted) return;

    try {
      await AppData.auth.sendPasswordResetEmail(email);
      if (!mounted) return;
      _showMessage('If $email has an account, a reset link is on its way.');
    } on AuthException catch (e) {
      if (!mounted) return;
      _showMessage(e.message);
    } catch (_) {
      if (!mounted) return;
      _showMessage('Unable to send the reset email. Please try again.');
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
                              const _LoginHeader(),
                              const SizedBox(height: AppSpacing.stackMd),
                              _socialButton(
                                label: 'Continue with Google',
                                icon: Icons.g_mobiledata,
                                onPressed: _loading
                                    ? null
                                    : _handleGoogleSignIn,
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
                                  onPressed: _loading ? null : _forgotPassword,
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
          if (_loading) const LoadingOverlay(),
        ],
      ),
    );
  }

  Widget _socialButton({
    required String label,
    required IconData icon,
    required VoidCallback? onPressed,
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
          side: const BorderSide(
            color: AppColors.ink,
            width: AppBorder.standard,
          ),
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

/// Asks for the existing account's password when Google sign-in hits an
/// email that already has one. Owns its controller so it's disposed with
/// the dialog, after the close animation — disposing right after
/// `showDialog` returns left the still-animating field on a dead controller.
class _LinkPasswordDialog extends StatefulWidget {
  const _LinkPasswordDialog({required this.email});

  final String email;

  @override
  State<_LinkPasswordDialog> createState() => _LinkPasswordDialogState();
}

class _LinkPasswordDialogState extends State<_LinkPasswordDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Account already exists'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${widget.email} already has a Nori account with a password. '
            'Enter that password to connect it to Google Sign-In.',
          ),
          const SizedBox(height: AppSpacing.gutter),
          TextField(
            controller: _controller,
            autofocus: true,
            obscureText: true,
            decoration: const InputDecoration(hintText: 'Password'),
            onSubmitted: (value) => Navigator.pop(context, value),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, _controller.text),
          child: const Text('Connect'),
        ),
      ],
    );
  }
}

/// "Forgot Password?" prompt, prefilled with whatever is in the email
/// field. Owns its controller for the same reason as [_LinkPasswordDialog]:
/// Cancel used to leave a red error box in place of the field.
class _ResetPasswordDialog extends StatefulWidget {
  const _ResetPasswordDialog({required this.initialEmail});

  final String initialEmail;

  @override
  State<_ResetPasswordDialog> createState() => _ResetPasswordDialogState();
}

class _ResetPasswordDialogState extends State<_ResetPasswordDialog> {
  late final _controller = TextEditingController(text: widget.initialEmail);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Reset your password'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        keyboardType: TextInputType.emailAddress,
        decoration: const InputDecoration(hintText: 'Email address'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, _controller.text.trim()),
          child: const Text('Send link'),
        ),
      ],
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
          style: AppTextStyles.bodyMd.copyWith(color: AppColors.inkMuted),
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
