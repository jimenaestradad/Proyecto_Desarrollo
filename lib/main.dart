import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'data/app_data.dart';
import 'firebase_options.dart';
import 'navigation/nori_shell.dart';
import 'screens/onboarding/login_screen.dart';
import 'screens/onboarding/sign_up_screen.dart';
import 'screens/onboarding/welcome_screen.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // Firebase Auth restores a signed-in session from local storage on
  // startup — checking it here is what makes "stay logged in between app
  // launches" (Auth > Persistencia de sesión) work, instead of always
  // dropping the person back on Welcome. Also points AppData.user (etc.)
  // at that uid's real Firestore data before any screen can read it —
  // see AppData.bindToUser.
  final currentUser = FirebaseAuth.instance.currentUser;
  if (currentUser != null) {
    AppData.bindToUser(currentUser.uid);
  }
  runApp(NoriApp(initialRoute: currentUser != null ? '/home' : '/welcome'));
}

class NoriApp extends StatelessWidget {
  const NoriApp({super.key, this.initialRoute = '/welcome'});

  final String initialRoute;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Nori',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      scrollBehavior: AppScrollBehavior(),
      initialRoute: initialRoute,
      routes: {
        '/welcome': (context) => const WelcomeScreen(),
        '/signup': (context) => const SignUpScreen(),
        '/login': (context) => const LoginScreen(),
        '/home': (context) => const NoriShell(),
      },
    );
  }
}
