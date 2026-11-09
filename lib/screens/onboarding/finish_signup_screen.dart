import 'package:flutter/material.dart';
import 'package:nori/data/app_data.dart';
import 'package:nori/data/username_repository.dart';
import 'package:nori/screens/onboarding/choose_username_screen.dart';
import 'package:nori/screens/onboarding/name_pet_screen.dart';
import 'package:nori/theme/app_theme.dart';
import 'package:nori/utils/remote_errors.dart';
import 'package:nori/widgets/load_error_view.dart';

/// Resumes sign-up for authenticated accounts without a claimed username.
/// Opened at startup to choose a username, save the profile and name the pet before Home.
class FinishSignUpScreen extends StatefulWidget {
  const FinishSignUpScreen({super.key});

  @override
  State<FinishSignUpScreen> createState() => _FinishSignUpScreenState();
}

class _FinishSignUpScreenState extends State<FinishSignUpScreen>
    with RemoteLoadState<FinishSignUpScreen> {
  /// Set once claimed, so a retry after a failed profile save doesn't ask
  /// for the username again.
  String? _username;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  Future<void> _run() async {
    final uid = AppData.auth.currentUserId;
    if (uid == null) {
      // Signed out meanwhile: nothing to finish.
      Navigator.pushNamedAndRemoveUntil(context, '/welcome', (route) => false);
      return;
    }
    final email = AppData.auth.currentEmail ?? '';

    if (_username == null) {
      // Interrupted after the claim but before the profile was saved: the name
      // is already theirs, so keep it instead of asking again (picking a
      // different one would leave two claims on this account). A failed lookup
      // shows the retry view rather than guessing.
      String? claimed;
      await guardedLoad(
        hasData: false,
        () async => claimed = await AppData.usernames.usernameForUid(uid),
      );
      if (!mounted || loadError != null) return;
      _username = claimed;
    }

    if (_username == null) {
      final chosen = await Navigator.push<String>(
        context,
        MaterialPageRoute(
          builder: (_) => ChooseUsernameScreen(
            uid: uid,
            email: email,
            suggestedUsername: suggestUsernameFromEmail(email),
          ),
        ),
      );
      // The screen has no back button; null only means it was torn down.
      if (chosen == null || !mounted) return;
      _username = chosen;
    }

    // A load, not an action: a failure leaves the retry view up (build)
    // instead of a snackbar over a blank screen.
    await guardedLoad(
      hasData: false,
      () => AppData.user.updateProfile(
        name: AppData.auth.currentDisplayName ?? email.split('@').first,
        username: _username,
        email: email,
      ),
    );
    if (!mounted || loadError != null) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const NamePetScreen()),
    );
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    final error = loadError;
    return Scaffold(
      backgroundColor: AppColors.linen,
      body: error != null
          ? LoadErrorView(error: error, onRetry: _run)
          : const Center(child: CircularProgressIndicator()),
    );
  }
}
