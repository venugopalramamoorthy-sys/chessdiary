// Tests for the account-deletion flow:
//   • AuthService.deleteAccount — service-layer behaviour
//   • DeleteAccountScreen      — UI/widget behaviour
//
// Both use injected test doubles via AuthService.testAuth / AuthService.testDb
// so no live Firebase connection is needed.

import 'package:chessdiary/screens/delete_account_screen.dart';
import 'package:chessdiary/services/auth_service.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' show FirebaseAuthException, UserInfo;
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mock_exceptions/mock_exceptions.dart';

// Helper: creates a UserInfo with a given providerId for MockUser.providerData.
// Subclasses UserInfo to access the @protected fromJson constructor legally.
class _ProviderInfo extends UserInfo {
  _ProviderInfo(String providerId)
      : super.fromJson({
          'providerId': providerId,
          'uid': 'provider-uid',
          'email': null,
          'displayName': null,
          'photoUrl': null,
          'phoneNumber': null,
          'isAnonymous': false,
          'isEmailVerified': true,
          'tenantId': null,
          'refreshToken': null,
          'creationTimestamp': null,
          'lastSignInTimestamp': null,
        });
}

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  tearDown(() {
    AuthService.testAuth = null;
    AuthService.testDb = null;
  });

  // ── Service-layer tests ──────────────────────────────────────────────────────

  group('AuthService.deleteAccount — email/password account', () {
    const email = 'user@test.com';
    // Unique uid per test — MockUser uses EquatableMixin (value equality), so
    // two instances with the same uid share mock_exceptions state. A fresh uid
    // each time keeps each test's throw configuration isolated.
    var _uidSeq = 0;

    late String uid;
    late MockFirebaseAuth auth;
    late FakeFirebaseFirestore db;

    setUp(() {
      uid = 'test-uid-${_uidSeq++}';
      final user = MockUser(uid: uid, email: email);
      auth = MockFirebaseAuth(signedIn: true, mockUser: user);
      db = FakeFirebaseFirestore();
      AuthService.testAuth = auth;
      AuthService.testDb = db;
    });

    test('throws ArgumentError when password is null', () {
      expect(
        () => AuthService.deleteAccount(password: null),
        throwsArgumentError,
      );
    });

    test('throws ArgumentError when password is empty string', () {
      expect(
        () => AuthService.deleteAccount(password: ''),
        throwsArgumentError,
      );
    });

    test('deletes all game documents from Firestore', () async {
      final gamesRef =
          db.collection('users').doc(uid).collection('games');
      await gamesRef.add({'moves': 'e4 e5', 'result': '1-0'});
      await gamesRef.add({'moves': 'd4 d5', 'result': '0-1'});

      await AuthService.deleteAccount(password: 'correct');

      expect((await gamesRef.get()).docs, isEmpty);
    });

    test('deletes user profile document from Firestore', () async {
      await db
          .collection('users')
          .doc(uid)
          .set({'name': 'Test', 'email': email});

      await AuthService.deleteAccount(password: 'correct');

      final doc = await db.collection('users').doc(uid).get();
      expect(doc.exists, false);
    });

    test('calls Firebase Auth user.delete() after Firestore data is gone',
        () async {
      // Seed data so we can confirm it's cleared before delete() is reached.
      final gamesRef =
          db.collection('users').doc(uid).collection('games');
      await gamesRef.add({'moves': 'e4'});

      // Configure user.delete() to throw — if deleteAccount() calls it,
      // we'll catch the exception; if it never calls it, no exception surfaces.
      whenCalling(Invocation.method(#delete, []))
          .on(auth.currentUser!)
          .thenThrow(FirebaseAuthException(code: 'requires-recent-login'));

      await expectLater(
        AuthService.deleteAccount(password: 'correct'),
        throwsA(isA<FirebaseAuthException>()
            .having((e) => e.code, 'code', 'requires-recent-login')),
      );

      // Firestore data must already be gone at the point delete() was called.
      expect((await gamesRef.get()).docs, isEmpty);
    });

    test('handles >500 games — batched deletion leaves no documents', () async {
      final gamesRef =
          db.collection('users').doc(uid).collection('games');
      await Future.wait(List.generate(501, (i) => gamesRef.add({'n': i})));

      expect((await gamesRef.get()).docs.length, 501);

      await AuthService.deleteAccount(password: 'correct');

      expect((await gamesRef.get()).docs, isEmpty);
    });
  });

  // Isolated group so the mock_exceptions throw registration doesn't bleed
  // into later tests — each group gets its own MockUser instance.
  group('AuthService.deleteAccount — wrong password / repeat deletion', () {
    late MockFirebaseAuth auth;
    late FakeFirebaseFirestore db;

    setUp(() {
      final user = MockUser(uid: 'isolated-uid-${DateTime.now().microsecondsSinceEpoch}',
          email: 'x@test.com');
      auth = MockFirebaseAuth(signedIn: true, mockUser: user);
      db = FakeFirebaseFirestore();
      AuthService.testAuth = auth;
      AuthService.testDb = db;
    });

    test('propagates FirebaseAuthException on wrong password', () {
      whenCalling(Invocation.method(#reauthenticateWithCredential, []))
          .on(auth.currentUser!)
          .thenThrow(FirebaseAuthException(code: 'wrong-password'));

      expect(
        () => AuthService.deleteAccount(password: 'wrong'),
        throwsA(isA<FirebaseAuthException>()
            .having((e) => e.code, 'code', 'wrong-password')),
      );
    });

    test('second call after deletion propagates auth error (not silent crash)',
        () async {
      // First deletion succeeds normally.
      await AuthService.deleteAccount(password: 'correct');

      // Simulate the post-deletion state: re-auth now throws because
      // the account no longer exists on the Firebase side.
      whenCalling(Invocation.method(#reauthenticateWithCredential, []))
          .on(auth.currentUser!)
          .thenThrow(FirebaseAuthException(code: 'user-not-found'));

      await expectLater(
        AuthService.deleteAccount(password: 'correct'),
        throwsA(isA<FirebaseAuthException>()
            .having((e) => e.code, 'code', 'user-not-found')),
      );
    });
  });

  // ── Widget tests ─────────────────────────────────────────────────────────────

  group('DeleteAccountScreen — email/password user', () {
    setUp(() {
      final user = MockUser(uid: 'u1', email: 'u@test.com');
      AuthService.testAuth = MockFirebaseAuth(signedIn: true, mockUser: user);
      AuthService.testDb = FakeFirebaseFirestore();
    });

    Widget wrap(Widget child) => MaterialApp(home: child);

    testWidgets('shows password entry field', (tester) async {
      await tester.pumpWidget(wrap(const DeleteAccountScreen()));
      await tester.pump();
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Enter your password to confirm'), findsOneWidget);
    });

    testWidgets('shows all 5 items that will be deleted', (tester) async {
      await tester.pumpWidget(wrap(const DeleteAccountScreen()));
      await tester.pump();
      expect(find.text('All games in your library'), findsOneWidget);
      expect(
          find.text(
              'Move sequences, analysis results, and coaching tips'),
          findsOneWidget);
      expect(find.text('Your account profile and email address'),
          findsOneWidget);
      expect(
          find.text('Linked Chess.com / Lichess account connections'),
          findsOneWidget);
      expect(find.text('Your sign-in credentials'), findsOneWidget);
    });

    testWidgets('shows data-retention notice', (tester) async {
      await tester.pumpWidget(wrap(const DeleteAccountScreen()));
      await tester.pump();
      expect(
        find.textContaining(
            'Anonymised crash-report data retained by Firebase'),
        findsOneWidget,
      );
    });

    testWidgets('delete button label is correct', (tester) async {
      await tester.pumpWidget(wrap(const DeleteAccountScreen()));
      await tester.pump();
      expect(find.text('Delete my account'), findsOneWidget);
    });

    testWidgets('Cancel button pops the route', (tester) async {
      final navKey = GlobalKey<NavigatorState>();
      await tester.pumpWidget(MaterialApp(
        navigatorKey: navKey,
        home: const Scaffold(body: Text('home')),
      ));

      navKey.currentState!.push(
        MaterialPageRoute(builder: (_) => const DeleteAccountScreen()),
      );
      await tester.pumpAndSettle();

      expect(find.byType(DeleteAccountScreen), findsOneWidget);

      // Cancel sits below the fold on the 800×600 test canvas — scroll to it.
      await tester.ensureVisible(find.text('Cancel'));
      await tester.pump();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('home'), findsOneWidget);
      expect(find.byType(DeleteAccountScreen), findsNothing);
    });
  });

  group('DeleteAccountScreen — Google account', () {
    setUp(() {
      final googleUser = MockUser(
        uid: 'g-uid',
        email: 'g@gmail.com',
        providerData: [_ProviderInfo('google.com')],
      );
      AuthService.testAuth =
          MockFirebaseAuth(signedIn: true, mockUser: googleUser);
      AuthService.testDb = FakeFirebaseFirestore();
    });

    Widget wrap(Widget child) => MaterialApp(home: child);

    testWidgets('shows Google re-confirm note instead of password field',
        (tester) async {
      await tester.pumpWidget(wrap(const DeleteAccountScreen()));
      await tester.pump();

      expect(find.byType(TextField), findsNothing);
      expect(
        find.textContaining(
            "You'll be asked to re-confirm with your Google account"),
        findsOneWidget,
      );
    });

    testWidgets('still shows the full deletion list', (tester) async {
      await tester.pumpWidget(wrap(const DeleteAccountScreen()));
      await tester.pump();
      expect(find.text('All games in your library'), findsOneWidget);
      expect(find.text('Your sign-in credentials'), findsOneWidget);
    });

    testWidgets('delete button label references Google', (tester) async {
      await tester.pumpWidget(wrap(const DeleteAccountScreen()));
      await tester.pump();
      expect(find.text('Confirm with Google & Delete'), findsOneWidget);
    });
  });
}
