// lib/main.dart

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'utils/theme.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';

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
      theme: AppTheme.dark,
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('♟', style: TextStyle(fontSize: 56)),
                    SizedBox(height: 16),
                    CircularProgressIndicator(color: AppTheme.primary),
                  ],
                ),
              ),
            );
          }
          return snap.hasData ? const HomeScreen() : const LoginScreen();
        },
      ),
    );
  }
}
