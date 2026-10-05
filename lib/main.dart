import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kDebugMode, kIsWeb;
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
  // Online only (docs/BACKEND.md): with persistence on, direct Firestore
  // writes silently queue offline while Cloud Function calls fail, so half
  // the app would appear to work. Off, everything fails the same way and
  // RemoteLoadState's timeout surfaces it.
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: false,
  );
  // Not calling _connectToEmulatorsInDebug(): Valeria's side develops
  // directly against the live nori-pet project (docs/BACKEND.md, "Local
  // dev" — no Java runtime available for the emulator, and it was never
  // actually used for this project). The function is left below rather
  // than deleted in case Jimena wants to opt back in for her own machine.
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

/// Points every Firebase SDK at the Firebase Local Emulator Suite
/// whenever this is a debug build -- see docs/BACKEND.md, "Local dev":
/// "Use the Firebase Local Emulator Suite ... for both of you during
/// development -- never point local `flutter run` at the production
/// `nori-pet` project." Start the emulators first (`firebase
/// emulators:start --only functions,auth,firestore` from the repo
/// root, or `cd functions && npm run serve`) -- otherwise every call
/// below just fails to connect and every Firebase-backed screen shows
/// the generic "couldn't reach the server" error.
///
/// A release build never takes this branch -- `kDebugMode` is
/// compile-time false there, so a real APK always talks to the real
/// `nori-pet` project, never the emulators.
///
/// Currently unreferenced -- see the comment at its call site in main().
// ignore: unused_element
void _connectToEmulatorsInDebug() {
  if (!kDebugMode) return;

  // The emulators run on this same machine. An Android emulator (the
  // only mobile target -- see pubspec.yaml's flutter_launcher_icons)
  // reaches the host machine at the special alias 10.0.2.2, not
  // localhost/127.0.0.1 -- that would resolve to the Android emulator
  // itself, not this machine. Web (and anything else) shares this
  // machine's network namespace, so plain 'localhost' is correct
  // there. Ports match firebase.json's "emulators" block.
  final host = (!kIsWeb && defaultTargetPlatform == TargetPlatform.android)
      ? '10.0.2.2'
      : 'localhost';

  FirebaseFirestore.instance.useFirestoreEmulator(host, 8080);
  FirebaseAuth.instance.useAuthEmulator(host, 9099);
  FirebaseFunctions.instance.useFunctionsEmulator(host, 5001);
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
