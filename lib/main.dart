import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'data/app_data.dart';
import 'firebase_options.dart';
import 'navigation/nori_shell.dart';
import 'screens/onboarding/finish_signup_screen.dart';
import 'screens/onboarding/login_screen.dart';
import 'screens/onboarding/sign_up_screen.dart';
import 'screens/onboarding/welcome_screen.dart';
import 'theme/app_theme.dart';
import 'utils/account_setup.dart';
import 'widgets/reward_burst.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // Online only (docs/BACKEND.md): with persistence on, direct Firestore
  // writes silently queue offline while Cloud Function calls fail, so half
  // the app would appear to work. Off, everything fails the same way and
  // RemoteLoadState's timeout surfaces it.
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: false,
  );
  // Restore the persisted Auth session and bind its repositories before screens load.
  // The emulator connector below is currently unused; local development uses nori-pet.
  final currentUser = FirebaseAuth.instance.currentUser;
  var initialRoute = '/welcome';
  if (currentUser != null) {
    AppData.bindToUser(currentUser.uid);
    initialRoute = await isSignUpComplete(currentUser.uid)
        ? '/home'
        : '/finish-signup';
  }
  runApp(NoriApp(initialRoute: initialRoute));
}

class NoriApp extends StatefulWidget {
  const NoriApp({super.key, this.initialRoute = '/welcome'});

  final String initialRoute;

  @override
  State<NoriApp> createState() => _NoriAppState();
}

class _NoriAppState extends State<NoriApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  final _messengerKey = GlobalKey<ScaffoldMessengerState>();
  StreamSubscription<void>? _sessionLost;

  @override
  void initState() {
    super.initState();
    _sessionLost = AppData.auth.sessionLost.listen((_) => _onSessionLost());
  }

  @override
  void dispose() {
    _sessionLost?.cancel();
    super.dispose();
  }

  /// The session ended without the person asking (expired or revoked token,
  /// account disabled or deleted elsewhere). Every load after this would fail
  /// with a generic error, so go back to Login and say why. Log out and
  /// Delete account end the session on purpose and never get here.
  void _onSessionLost() {
    AppData.unbindUser();
    _navigatorKey.currentState?.pushNamedAndRemoveUntil(
      '/login',
      (route) => false,
    );
    _messengerKey.currentState
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('You were signed out. Please log in again.'),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      scaffoldMessengerKey: _messengerKey,
      title: 'Nori',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      scrollBehavior: AppScrollBehavior(),
      builder: (context, child) =>
          RewardBurst.trackPointer(child: child ?? const SizedBox.shrink()),
      initialRoute: widget.initialRoute,
      routes: {
        '/welcome': (context) => const WelcomeScreen(),
        '/signup': (context) => const SignUpScreen(),
        '/finish-signup': (context) =>
            const _SignedInOnly(child: FinishSignUpScreen()),
        '/login': (context) => const LoginScreen(),
        '/home': (context) => const _SignedInOnly(child: NoriShell()),
      },
      // Any other address (a typed URL) lands on the guarded app: Home when
      // signed in, Login when not.
      onUnknownRoute: (settings) => MaterialPageRoute<void>(
        settings: const RouteSettings(name: '/home'),
        builder: (_) => const _SignedInOnly(child: NoriShell()),
      ),
    );
  }
}

/// Wraps every screen that needs an account. A signed-out visitor (e.g.
/// someone typing an address into the browser bar) goes to Login instead of
/// seeing a screen whose every load fails.
class _SignedInOnly extends StatefulWidget {
  const _SignedInOnly({required this.child});

  final Widget child;

  @override
  State<_SignedInOnly> createState() => _SignedInOnlyState();
}

class _SignedInOnlyState extends State<_SignedInOnly> {
  late final bool _signedIn = FirebaseAuth.instance.currentUser != null;

  @override
  void initState() {
    super.initState();
    if (!_signedIn) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.pushReplacementNamed(context, '/login');
      });
    }
  }

  @override
  Widget build(BuildContext context) =>
      _signedIn ? widget.child : const Scaffold();
}
