// lib/services/auth_service.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb, visibleForTesting;
import '../utils/google_sign_in_mobile.dart';

class AuthService {
  @visibleForTesting
  static FirebaseAuth? testAuth;
  @visibleForTesting
  static FirebaseFirestore? testDb;

  static FirebaseAuth get _auth => testAuth ?? FirebaseAuth.instance;
  static FirebaseFirestore get _db => testDb ?? FirebaseFirestore.instance;

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
          idToken: credentials['idToken'],
          // accessToken removed in google_sign_in v7; idToken alone is sufficient
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

  /// Permanently deletes the current user's account and all associated data.
  ///
  /// Firebase requires re-authentication before deletion. For email/password
  /// accounts, supply [password]. For Google accounts, leave it null — the
  /// method re-invokes the Google sign-in flow automatically.
  ///
  /// Throws on cancellation, wrong password, or network errors.
  static Future<void> deleteAccount({String? password}) async {
    final user = _auth.currentUser!;
    final uid  = user.uid;

    // ── Re-authenticate ────────────────────────────────────────────────────
    final providerId = user.providerData.isNotEmpty
        ? user.providerData.first.providerId
        : 'password';

    if (providerId == 'google.com') {
      if (kIsWeb) {
        final result = await _auth.signInWithPopup(GoogleAuthProvider());
        await user.reauthenticateWithCredential(result.credential!);
      } else {
        final credentials = await mobileGoogleSignIn();
        if (credentials == null) throw Exception('Google sign-in was cancelled');
        await user.reauthenticateWithCredential(
          GoogleAuthProvider.credential(idToken: credentials['idToken']),
        );
      }
    } else {
      if (password == null || password.isEmpty) {
        throw ArgumentError('Password is required to confirm deletion');
      }
      await user.reauthenticateWithCredential(
        EmailAuthProvider.credential(email: user.email!, password: password),
      );
    }

    // ── Delete Firestore data ──────────────────────────────────────────────
    // Games subcollection — batched to stay under Firestore's 500-doc limit.
    while (true) {
      final snap = await _db
          .collection('users')
          .doc(uid)
          .collection('games')
          .limit(500)
          .get();
      if (snap.docs.isEmpty) break;
      final batch = _db.batch();
      for (final doc in snap.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }

    // User profile document.
    await _db.collection('users').doc(uid).delete();

    // ── Delete Firebase Auth user ──────────────────────────────────────────
    await user.delete();

    if (!kIsWeb) {
      try {
        await mobileGoogleSignOut();
      } catch (_) {}
    }
  }
}
