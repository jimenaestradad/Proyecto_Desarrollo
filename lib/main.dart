import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'firebase_options.dart';
import 'navigation/nori_shell.dart';
import 'screens/onboarding/login_screen.dart';
import 'screens/onboarding/sign_up_screen.dart';
import 'screens/onboarding/welcome_screen.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const NoriApp());
}

class NoriApp extends StatelessWidget {
  const NoriApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Nori',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      initialRoute: '/welcome',
      routes: {
        '/welcome': (context) => const WelcomeScreen(),
        '/signup': (context) => const SignUpScreen(),
        '/login': (context) => const LoginScreen(),
        '/home': (context) => const NoriShell(),
      },
    );
  }
}
