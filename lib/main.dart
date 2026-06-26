// lib/main.dart

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_options.dart';
import 'utils/theme.dart';
import 'utils/web_theme.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/web_landing_screen.dart';

const _kWebDarkPrefKey = 'web_dark_mode';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Restore saved web dark-mode preference before first frame
  if (kIsWeb) {
    final prefs = await SharedPreferences.getInstance();
    WT.webDark.value = prefs.getBool(_kWebDarkPrefKey) ?? false;
  }

  runApp(const ChessDiaryApp());
}

class ChessDiaryApp extends StatelessWidget {
  const ChessDiaryApp({super.key});

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) {
      return MaterialApp(
        title: 'ChessDiary',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark,
        home: StreamBuilder<User?>(
          stream: FirebaseAuth.instance.authStateChanges(),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return Scaffold(
                body: Center(
                  child: CircularProgressIndicator(color: AppTheme.primary),
                ),
              );
            }
            return snap.hasData ? const HomeScreen() : const LoginScreen();
          },
        ),
      );
    }

    // Web: re-build MaterialApp when dark mode is toggled
    return ValueListenableBuilder<bool>(
      valueListenable: WT.webDark,
      builder: (context, isDark, _) {
        return MaterialApp(
          title: 'ChessDiary',
          debugShowCheckedModeBanner: false,
          theme: isDark ? AppTheme.webDark : AppTheme.light,
          home: StreamBuilder<User?>(
            stream: FirebaseAuth.instance.authStateChanges(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return Scaffold(
                  backgroundColor: WT.scaffoldBg,
                  body: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('♟',
                            style: TextStyle(
                                fontSize: 56, color: WT.mutedColor)),
                        const SizedBox(height: 16),
                        CircularProgressIndicator(color: WT.greenAccent),
                      ],
                    ),
                  ),
                );
              }
              if (snap.hasData) return const HomeScreen();
              return const WebLandingScreen();
            },
          ),
        );
      },
    );
  }
}
