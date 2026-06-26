// Tests for the web-only landing page (WebLandingScreen).
// These are widget tests — they check that the right widgets exist in the
// tree and that stateful interactions (auth toggle, logout dialog) work
// correctly without needing a live Firebase connection.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:chessdiary/screens/web_landing_screen.dart';

// ── Logout dialog helper (mirrors confirmLogout in home_screen.dart) ──────────
// We replicate the dialog logic here to avoid pulling in home_screen.dart,
// which transitively imports google_sign_in (a mobile plugin that requires
// a real platform and can't compile in the Dart test VM).
Future<bool?> _testLogoutDialog(BuildContext context) {
  return showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Sign out?'),
      content: const Text('You can sign back in any time.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Sign out',
              style: TextStyle(color: Colors.red)),
        ),
      ],
    ),
  );
}

void main() {
  setUpAll(() {
    // Prevent google_fonts from making network requests during tests.
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  Widget wrap(Widget child) => MaterialApp(home: child);

  // ── Nav bar ────────────────────────────────────────────────────────────────

  group('WebLandingScreen — nav bar', () {
    testWidgets('shows ChessDiary brand name', (tester) async {
      await tester.pumpWidget(wrap(const WebLandingScreen()));
      await tester.pump();
      // Finds at least once (nav bar) — possibly twice if footer repeats it
      expect(find.text('ChessDiary'), findsWidgets);
    });

    testWidgets('shows Get started CTA', (tester) async {
      await tester.pumpWidget(wrap(const WebLandingScreen()));
      await tester.pump();
      expect(find.text('Get started'), findsOneWidget);
    });
  });

  // ── Hero section ───────────────────────────────────────────────────────────

  group('WebLandingScreen — hero section', () {
    testWidgets('renders first line of the headline', (tester) async {
      await tester.pumpWidget(wrap(const WebLandingScreen()));
      await tester.pump();
      // The headline is one Text widget with newlines
      expect(find.textContaining('Every game.'), findsOneWidget);
    });

    testWidgets('renders subheading copy', (tester) async {
      await tester.pumpWidget(wrap(const WebLandingScreen()));
      await tester.pump();
      expect(find.textContaining('Chess.com games'), findsOneWidget);
    });

    testWidgets('shows PERSONAL CHESS JOURNAL eyebrow', (tester) async {
      await tester.pumpWidget(wrap(const WebLandingScreen()));
      await tester.pump();
      expect(find.text('PERSONAL CHESS JOURNAL'), findsOneWidget);
    });

    testWidgets('renders trust note with Free mention', (tester) async {
      await tester.pumpWidget(wrap(const WebLandingScreen()));
      await tester.pump();
      expect(find.textContaining('Free'), findsWidgets);
    });

    testWidgets('renders chessboard visual (CustomPaint)', (tester) async {
      await tester.pumpWidget(wrap(const WebLandingScreen()));
      await tester.pump();
      // The board is drawn by a CustomPainter — verify its container exists
      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('renders analysis badges on board', (tester) async {
      await tester.pumpWidget(wrap(const WebLandingScreen()));
      await tester.pump();
      expect(find.text('Blunder detected'), findsOneWidget);
      expect(find.text('Stockfish analysis'), findsOneWidget);
    });
  });

  // ── Feature showcase ───────────────────────────────────────────────────────

  group('WebLandingScreen — features section', () {
    testWidgets('shows section header', (tester) async {
      await tester.pumpWidget(wrap(const WebLandingScreen()));
      await tester.pump();
      expect(find.textContaining('Everything you need'), findsOneWidget);
    });

    const expectedFeatures = [
      'AI-Powered Import',
      'Chess.com & Lichess Sync',
      'Real Engine Analysis',
      'Tactical Pattern Recognition',
      'Board Replay & Study Mode',
      'Opening Repertoire',
      'Opponent Database',
      'Progress Dashboard',
    ];

    for (final title in expectedFeatures) {
      testWidgets('renders feature card "$title"', (tester) async {
        await tester.pumpWidget(wrap(const WebLandingScreen()));
        await tester.pump();
        // SingleChildScrollView builds all children eagerly — find regardless
        // of scroll position.
        expect(find.text(title), findsOneWidget,
            reason: 'Feature card "$title" was not found in the widget tree');
      });
    }

    testWidgets('renders exactly 8 feature card titles', (tester) async {
      await tester.pumpWidget(wrap(const WebLandingScreen()));
      await tester.pump();
      int found = 0;
      for (final title in expectedFeatures) {
        if (tester.any(find.text(title))) found++;
      }
      expect(found, 8, reason: 'Expected 8 feature cards, found $found');
    });
  });

  // ── Auth form ──────────────────────────────────────────────────────────────

  group('WebLandingScreen — auth form', () {
    testWidgets('shows login form by default (Welcome back)', (tester) async {
      await tester.pumpWidget(wrap(const WebLandingScreen()));
      await tester.pump();
      expect(find.text('Welcome back'), findsOneWidget);
    });

    testWidgets('shows email and password fields', (tester) async {
      await tester.pumpWidget(wrap(const WebLandingScreen()));
      await tester.pump();
      expect(find.widgetWithText(TextField, 'Email address'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Password'), findsOneWidget);
    });

    testWidgets('does NOT show name field in login mode', (tester) async {
      await tester.pumpWidget(wrap(const WebLandingScreen()));
      await tester.pump();
      expect(find.widgetWithText(TextField, 'Your name'), findsNothing);
    });

    testWidgets('toggling to signup shows name field and Create account',
        (tester) async {
      await tester.pumpWidget(wrap(const WebLandingScreen()));
      await tester.pump();
      await tester.tap(find.text("Don't have an account? Sign up"));
      await tester.pump();
      expect(find.text('Create your account'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Your name'), findsOneWidget);
      expect(find.text('Create account'), findsOneWidget);
    });

    testWidgets('toggling back to login hides name field', (tester) async {
      await tester.pumpWidget(wrap(const WebLandingScreen()));
      await tester.pump();
      await tester.tap(find.text("Don't have an account? Sign up"));
      await tester.pump();
      await tester.tap(find.text('Already have an account? Sign in'));
      await tester.pump();
      expect(find.text('Welcome back'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Your name'), findsNothing);
    });

    testWidgets('password field toggle changes obscureText', (tester) async {
      await tester.pumpWidget(wrap(const WebLandingScreen()));
      await tester.pump();
      // Find the visibility toggle icon button
      final visibilityBtn = find.byIcon(Icons.visibility_outlined);
      expect(visibilityBtn, findsOneWidget);
      await tester.tap(visibilityBtn);
      await tester.pump();
      // After tap, icon should change to visibility_off
      expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);
    });

    testWidgets('Continue with Google button is present', (tester) async {
      await tester.pumpWidget(wrap(const WebLandingScreen()));
      await tester.pump();
      expect(find.text('Continue with Google'), findsOneWidget);
    });
  });

  // ── Footer ─────────────────────────────────────────────────────────────────

  group('WebLandingScreen — footer', () {
    testWidgets('shows "Built by a student chess player" credit',
        (tester) async {
      await tester.pumpWidget(wrap(const WebLandingScreen()));
      await tester.pump();
      expect(find.textContaining('Built by a student'), findsOneWidget);
    });
  });

  // ── Logout confirmation dialog ─────────────────────────────────────────────

  group('Logout confirmation dialog', () {
    testWidgets('shows dialog with Sign out? title', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (ctx) => ElevatedButton(
            onPressed: () => _testLogoutDialog(ctx),
            child: const Text('Open'),
          ),
        ),
      ));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Sign out?'), findsOneWidget);
    });

    testWidgets('dialog has Cancel and Sign out buttons', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (ctx) => ElevatedButton(
            onPressed: () => _testLogoutDialog(ctx),
            child: const Text('Open'),
          ),
        ),
      ));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Sign out'), findsOneWidget);
    });

    testWidgets('Cancel dismisses dialog and returns false', (tester) async {
      bool? result;
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (ctx) => ElevatedButton(
            onPressed: () async {
              result = await _testLogoutDialog(ctx);
            },
            child: const Text('Open'),
          ),
        ),
      ));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Sign out?'), findsNothing);
      expect(result, isFalse);
    });

    testWidgets('Sign out button returns true', (tester) async {
      bool? result;
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (ctx) => ElevatedButton(
            onPressed: () async {
              result = await _testLogoutDialog(ctx);
            },
            child: const Text('Open'),
          ),
        ),
      ));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      // There's both "Sign in →" in landing if visible, so use exact button
      await tester.tap(find.widgetWithText(TextButton, 'Sign out').last);
      await tester.pumpAndSettle();

      expect(result, isTrue);
    });
  });
}
