// lib/services/auth_service.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../utils/google_sign_in_mobile.dart';

class AuthService {
  static final _auth = FirebaseAuth.instance;
  static final _db = FirebaseFirestore.instance;

  static User? get currentUser => _auth.currentUser;
  static Stream<User?> get authStateChanges => _auth.authStateChanges();

  static Future<UserCredential> signUp({
    required String email,
    required String password,
    required String name,
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    await cred.user!.updateDisplayName(name);
    await _db.collection('users').doc(cred.user!.uid).set({
      'name': name,
      'email': email,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return cred;
  }

  static Future<UserCredential> signIn({
    required String email,
    required String password,
  }) async {
    return await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  static Future<UserCredential?> signInWithGoogle() async {
    UserCredential cred;
    if (kIsWeb) {
      // On web Firebase handles the OAuth popup directly — no google_sign_in needed.
      cred = await _auth.signInWithPopup(GoogleAuthProvider());
    } else {
      final credentials = await mobileGoogleSignIn();
      if (credentials == null) return null;
      cred = await _auth.signInWithCredential(
        GoogleAuthProvider.credential(
          accessToken: credentials['accessToken'],
          idToken: credentials['idToken'],
        ),
      );
    }
    final user = cred.user!;
    final doc = _db.collection('users').doc(user.uid);
    if (!(await doc.get()).exists) {
      await doc.set({
        'name': user.displayName ?? '',
        'email': user.email ?? '',
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
    return cred;
  }

  static Future<void> signOut() async {
    if (!kIsWeb) await mobileGoogleSignOut();
    await _auth.signOut();
  }

  static Future<void> resetPassword(String email) async =>
      await _auth.sendPasswordResetEmail(email: email);
}
