// lib/main.dart

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'firebase_options.dart';
import 'utils/theme.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/web_landing_screen.dart';
import 'utils/web_theme.dart' show WT;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const ChessDiaryApp());
}

class ChessDiaryApp extends StatelessWidget {
  const ChessDiaryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ChessDiary',
      debugShowCheckedModeBanner: false,
      theme: kIsWeb ? AppTheme.light : AppTheme.dark,
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return Scaffold(
              backgroundColor: kIsWeb ? WT.bg : AppTheme.background,
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('♟',
                        style: TextStyle(
                            fontSize: 56,
                            color: kIsWeb ? WT.muted : AppTheme.primary)),
                    const SizedBox(height: 16),
                    CircularProgressIndicator(
                        color: kIsWeb ? WT.accent : AppTheme.primary),
                  ],
                ),
              ),
            );
          }
          if (snap.hasData) return const HomeScreen();
          return kIsWeb ? const WebLandingScreen() : const LoginScreen();
        },
      ),
    );
  }
}
