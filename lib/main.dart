import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/theme/app_theme.dart';
import 'firebase_options.dart';
import 'screens/auth/login_screen.dart';
import 'screens/home/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  runApp(const InterfaceScanApp());
}

class InterfaceScanApp extends StatelessWidget {
  const InterfaceScanApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'InterfaceScan',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      // Listen to Firebase auth state — auto-navigate Login ↔ Home
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          // Still loading
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const _SplashScreen();
          }
          // Logged in → Home
          if (snapshot.hasData && snapshot.data != null) {
            return const HomeScreen();
          }
          // Not logged in → Login
          return const LoginScreen();
        },
      ),
    );
  }
}

// ── Splash / loading screen ───────────────────────────────────────────────────

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primary,
      body: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.image_search_rounded,
                size: 72, color: Colors.white),
            SizedBox(height: 16),
            Text(
              'InterfaceScan',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
