import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Manages per-platform username bindings in Firestore.
///
/// Data lives at users/{uid}.linkedAccounts.{platform}.
/// Platform keys: [chessCom], [lichess].
class AccountLinkService {
  static const chessCom = 'chessCom';
  static const lichess  = 'lichess';

  static DocumentReference<Map<String, dynamic>> _userDoc() {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    return FirebaseFirestore.instance.collection('users').doc(uid);
  }

  /// Returns the bound username for [platform], or null if not linked.
  static Future<String?> getLinkedUsername(String platform) async {
    try {
      final snap = await _userDoc().get();
      if (!snap.exists) return null;
      final accounts = snap.data()?['linkedAccounts'] as Map<String, dynamic>?;
      return accounts?[platform] as String?;
    } catch (_) {
      return null;
    }
  }

  /// Stores [username] as the bound identity for [platform].
  /// Call after the first successful import to lock the account.
  static Future<void> linkAccount(String platform, String username) async {
    await _userDoc().set(
      {'linkedAccounts': {platform: username}},
      SetOptions(merge: true),
    );
  }

  /// Clears the Firestore binding for [platform].
  /// Game deletion runs separately via [deleteLinkedGames].
  static Future<void> unlinkAccount(String platform) async {
    await _userDoc().update({'linkedAccounts.$platform': FieldValue.delete()});
  }

  /// Deletes all Firestore games imported from [platform] by [username].
  /// STUB — wired up after UX is confirmed.
  static Future<void> deleteLinkedGames(
      String platform, String username) async {
    // TODO: batch-delete games where source == platform && player == username
  }
}
