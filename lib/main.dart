import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/theme/app_theme.dart';
import 'firebase_options.dart';
import 'screens/auth/login_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/onboarding/onboarding_screen.dart';

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
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          // Loading — show splash
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const _SplashScreen();
          }
          // Not logged in → Login
          if (!snapshot.hasData || snapshot.data == null) {
            return const LoginScreen();
          }
          // Logged in — check if onboarding was shown
          return FutureBuilder<bool>(
            future: _onboardingDone(),
            builder: (ctx, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const _SplashScreen();
              }
              if (snap.data == true) {
                return const HomeScreen();
              }
              return const OnboardingScreen();
            },
          );
        },
      ),
    );
  }

  static Future<bool> _onboardingDone() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('onboarding_done') ?? false;
  }
}

// ── Splash screen ─────────────────────────────────────────────────────────────

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
            Icon(Icons.image_search_rounded, size: 72, color: Colors.white),
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
