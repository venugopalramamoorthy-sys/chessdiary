// lib/screens/web_landing_screen.dart
// Editorial redesign — Anton (condensed headline) + Lora (serif body),
// strict black / white / green palette, B&W chess-photo aesthetic.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/auth_service.dart';

// ── palette ───────────────────────────────────────────────────────────────────
class _C {
  static const black     = Color(0xFF0C0C0C);
  static const charcoal  = Color(0xFF1A1A1A);
  static const darkGrey  = Color(0xFF2E2E2E);
  static const midGrey   = Color(0xFF666666);
  static const silver    = Color(0xFFAAAAAA);
  static const white     = Color(0xFFFFFFFF);
  static const offWhite  = Color(0xFFF4F3EF);
  static const cream     = Color(0xFFE8E6DF);
  // Green accent — dark BG version (brighter) vs light BG version (deeper)
  static const greenDark = Color(0xFF66BB6A);   // on black
  static const greenLt   = Color(0xFF1B5E20);   // on white
  static const borderLt  = Color(0xFFD0CEC7);
}

// ── typography helpers ────────────────────────────────────────────────────────
TextStyle _anton(double size, {Color color = _C.white, double spacing = 1.5}) =>
    GoogleFonts.anton(fontSize: size, color: color,
        letterSpacing: spacing, height: 0.95);

TextStyle _lora(double size,
    {Color color = _C.midGrey,
    FontWeight weight = FontWeight.w400,
    FontStyle style = FontStyle.normal}) =>
    GoogleFonts.lora(fontSize: size, color: color,
        fontWeight: weight, fontStyle: style, height: 1.65);

// ── span model for mixed-colour headlines ─────────────────────────────────────
class _S {
  final String text;
  final bool green;   // highlight in accent
  final bool newline; // insert \n after this span
  const _S(this.text, {this.green = false, this.newline = false});
}

InlineSpan _headlineSpan(List<_S> spans, double size,
    {Color base = _C.white, Color accent = _C.greenDark}) {
  return TextSpan(
    children: spans.map((s) {
      final t = s.newline ? '${s.text}\n' : s.text;
      return TextSpan(
        text: t,
        style: _anton(size, color: s.green ? accent : base),
      );
    }).toList(),
  );
}

// ── root widget ───────────────────────────────────────────────────────────────
class WebLandingScreen extends StatefulWidget {
  const WebLandingScreen({super.key});
  @override
  State<WebLandingScreen> createState() => _State();
}

class _State extends State<WebLandingScreen> {
  final _scrollCtrl = ScrollController();
  final _authKey    = GlobalKey();

  bool _isLogin = true;
  bool _loading  = false;
  bool _gLoading = false;
  bool _obscure  = true;

  final _nameCtrl  = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl  = TextEditingController();

  @override
  void dispose() {
    _scrollCtrl.dispose();
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  void _scrollToAuth() {
    final ctx = _authKey.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(ctx,
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeInOutCubic);
  }

  Future<void> _submit() async {
    if (_emailCtrl.text.isEmpty || _passCtrl.text.isEmpty) return;
    if (!_isLogin && _nameCtrl.text.isEmpty) return;
    setState(() => _loading = true);
    try {
      if (_isLogin) {
        await AuthService.signIn(
            email: _emailCtrl.text.trim(), password: _passCtrl.text.trim());
      } else {
        await AuthService.signUp(
            name: _nameCtrl.text.trim(),
            email: _emailCtrl.text.trim(),
            password: _passCtrl.text.trim());
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(e.toString()),
            backgroundColor: Colors.red.shade700));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _googleSignIn() async {
    setState(() => _gLoading = true);
    try {
      await AuthService.signInWithGoogle();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Google sign-in failed: $e'),
            backgroundColor: Colors.red.shade700));
      }
    } finally {
      if (mounted) setState(() => _gLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.black,
      body: Stack(
        children: [
          // ── scrollable content ──────────────────────────────────────────
          SingleChildScrollView(
            controller: _scrollCtrl,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _HeaderBar(onSignIn: _scrollToAuth),
                _HeroSection(onSignIn: _scrollToAuth),
                _ProblemSection(),
                _StatsSection(),
                _FeaturesSection(),
                _AuthSection(
                  key: _authKey,
                  isLogin: _isLogin,
                  loading: _loading,
                  gLoading: _gLoading,
                  obscure: _obscure,
                  nameCtrl: _nameCtrl,
                  emailCtrl: _emailCtrl,
                  passCtrl: _passCtrl,
                  onToggleMode: () => setState(() => _isLogin = !_isLogin),
                  onToggleObscure: () => setState(() => _obscure = !_obscure),
                  onSubmit: _submit,
                  onGoogle: _googleSignIn,
                ),
                const _Footer(),
              ],
            ),
          ),
          // ── sticky right-edge tabs ──────────────────────────────────────
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            child: _StickyTabs(onSignIn: _scrollToAuth),
          ),
        ],
      ),
    );
  }
}

// ── header bar ────────────────────────────────────────────────────────────────
class _HeaderBar extends StatelessWidget {
  final VoidCallback onSignIn;
  const _HeaderBar({required this.onSignIn});

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 640;
    return Container(
      height: 60,
      color: _C.black,
      padding: EdgeInsets.symmetric(horizontal: narrow ? 20 : 48),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Wordmark
          RichText(
            text: TextSpan(children: [
              TextSpan(
                text: 'CHESS',
                style: _anton(18, color: _C.white, spacing: 3),
              ),
              TextSpan(
                text: 'DIARY',
                style: _anton(18, color: _C.greenDark, spacing: 3),
              ),
            ]),
          ),
          const SizedBox(width: 20),
          // Tagline — hidden on narrow
          if (!narrow)
            Text(
              'YOUR GAMES. YOUR PATTERNS. YOUR EDGE.',
              style: _lora(10,
                  color: _C.midGrey,
                  weight: FontWeight.w600,
                  style: FontStyle.italic),
            ),
          const Spacer(),
          // Sign in link
          _ArrowLink(
            label: 'Sign in',
            onTap: onSignIn,
            color: _C.silver,
            fontSize: 13,
          ),
        ],
      ),
    );
  }
}

// ── hero section ──────────────────────────────────────────────────────────────
class _HeroSection extends StatelessWidget {
  final VoidCallback onSignIn;
  const _HeroSection({required this.onSignIn});

  @override
  Widget build(BuildContext context) {
    final size  = MediaQuery.sizeOf(context);
    final h     = size.height.clamp(600.0, 860.0);
    final narrow = size.width < 700;
    final headSize = narrow ? 52.0 : (size.width < 1100 ? 72.0 : 96.0);

    return SizedBox(
      height: h,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // B&W chess art
          CustomPaint(painter: _ChessHeroPainter()),

          // Gradient overlays for text legibility
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerRight,
                end: Alignment.centerLeft,
                colors: [Colors.transparent, Color(0xDD0C0C0C)],
                stops: [0.35, 1.0],
              ),
            ),
          ),
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x660C0C0C), Colors.transparent, Color(0xBB0C0C0C)],
                stops: [0.0, 0.4, 1.0],
              ),
            ),
          ),

          // Content
          Padding(
            padding: EdgeInsets.symmetric(
                horizontal: narrow ? 24 : 56,
                vertical: 48),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Spacer(),
                // Eyebrow
                Text(
                  'PERSONAL CHESS INTELLIGENCE',
                  style: _lora(11,
                      color: _C.greenDark,
                      weight: FontWeight.w600,
                      style: FontStyle.italic),
                ),
                const SizedBox(height: 20),
                // Main headline with green phrase
                RichText(
                  text: _headlineSpan([
                    _S('KNOW YOUR ', newline: false),
                    _S('BLIND SPOTS.', green: true, newline: true),
                    _S('FIX THEM.'),
                  ], headSize),
                ),
                const SizedBox(height: 24),
                // Subheading
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Text(
                    'ChessDiary brings your paper scoresheets, Chess.com games, '
                    'and Lichess history into one place — then shows you exactly '
                    'where you keep losing.',
                    style: _lora(narrow ? 14 : 16, color: _C.silver),
                  ),
                ),
                const SizedBox(height: 36),
                _ArrowLink(
                  label: 'Start Your Journey',
                  onTap: onSignIn,
                  color: _C.white,
                  fontSize: 15,
                  bold: true,
                ),
                const SizedBox(height: 52),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── hero chess painter ────────────────────────────────────────────────────────
class _ChessHeroPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Base: very dark
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h),
        Paint()..color = const Color(0xFF080808));

    // Ambient gradient — warm light from upper-right
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, h),
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(0.7, -0.6),
          radius: 1.2,
          colors: [Color(0xFF252520), Color(0xFF080808)],
        ).createShader(Rect.fromLTWH(0, 0, w, h)),
    );

    // Perspective chessboard — shifted right
    _drawBoard(canvas, size);

    // King piece — foreground center-right
    _drawPiece(canvas, '♚',
        Offset(w * 0.63, h * 0.60), h * 0.46,
        const Color(0xFFCCCCCC));

    // Queen piece — further back, partially obscured by darkness
    _drawPiece(canvas, '♛',
        Offset(w * 0.42, h * 0.50), h * 0.26,
        const Color(0xFF505050));

    // Knight hint — far background
    _drawPiece(canvas, '♞',
        Offset(w * 0.78, h * 0.42), h * 0.18,
        const Color(0xFF303030));

    // Spotlight on king from upper right
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, h),
      Paint()
        ..shader = RadialGradient(
          center: Alignment(0.26, -0.2),
          radius: 0.7,
          colors: [
            const Color(0x18FFFFFF),
            Colors.transparent,
          ],
        ).createShader(Rect.fromLTWH(0, 0, w, h)),
    );

    // Heavy vignette — corners and bottom
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, h),
      Paint()
        ..shader = RadialGradient(
          center: Alignment(0.25, 0.1),
          radius: 0.85,
          colors: [Colors.transparent, const Color(0xCC080808)],
          stops: const [0.45, 1.0],
        ).createShader(Rect.fromLTWH(0, 0, w, h)),
    );

    // Left-side dark fade for text legibility
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, h),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [Color(0xBB080808), Colors.transparent],
          stops: [0.0, 0.55],
        ).createShader(Rect.fromLTWH(0, 0, w, h)),
    );

    // Bottom fade
    canvas.drawRect(
      Rect.fromLTWH(0, h * 0.65, w, h * 0.35),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, const Color(0xFF080808)],
        ).createShader(Rect.fromLTWH(0, h * 0.65, w, h * 0.35)),
    );
  }

  void _drawBoard(Canvas canvas, Size size) {
    const n    = 8;
    final cx   = size.width * 0.68;
    final bot  = size.height * 0.98;
    final top  = size.height * 0.22;
    final hwBt = size.width * 0.36;
    final hwTp = size.width * 0.16;

    for (int row = 0; row < n; row++) {
      final t0  = row / n;
      final t1  = (row + 1) / n;
      final y0  = _lerp(bot, top, t0);
      final y1  = _lerp(bot, top, t1);
      final hw0 = _lerp(hwBt, hwTp, t0);
      final hw1 = _lerp(hwBt, hwTp, t1);
      final fade = (1.0 - t0 * 0.7).clamp(0.0, 1.0);

      for (int col = 0; col < n; col++) {
        final c0 = col / n;
        final c1 = (col + 1) / n;
        final bl = Offset(cx - hw0 + c0 * hw0 * 2, y0);
        final br = Offset(cx - hw0 + c1 * hw0 * 2, y0);
        final tr = Offset(cx - hw1 + c1 * hw1 * 2, y1);
        final tl = Offset(cx - hw1 + c0 * hw1 * 2, y1);

        final light = (row + col).isEven;
        final base  = light ? 0x3E : 0x0C;
        final v     = (base * fade).round().clamp(0, 255);
        canvas.drawPath(
          Path()
            ..moveTo(bl.dx, bl.dy)
            ..lineTo(br.dx, br.dy)
            ..lineTo(tr.dx, tr.dy)
            ..lineTo(tl.dx, tl.dy)
            ..close(),
          Paint()..color = Color.fromARGB(255, v, v, v),
        );
      }
    }
  }

  void _drawPiece(Canvas canvas, String symbol, Offset center,
      double fontSize, Color color) {
    // Drop shadow pass
    _paintText(canvas, symbol, center + const Offset(5, 7),
        fontSize, const Color(0xCC000000));
    // Main pass
    _paintText(canvas, symbol, center, fontSize, color);
  }

  void _paintText(Canvas canvas, String text, Offset center,
      double fontSize, Color color) {
    final tp = TextPainter(
      text: TextSpan(
          text: text,
          style: TextStyle(fontSize: fontSize, color: color, height: 1.0)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

  double _lerp(double a, double b, double t) => a + (b - a) * t;

  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}

// ── problem section (off-white, inline green) ─────────────────────────────────
class _ProblemSection extends StatelessWidget {
  const _ProblemSection();

  @override
  Widget build(BuildContext context) {
    final w      = MediaQuery.sizeOf(context).width;
    final narrow = w < 700;
    final hPad   = narrow ? 28.0 : (w < 1100 ? 56.0 : 100.0);

    return Container(
      color: _C.offWhite,
      padding: EdgeInsets.symmetric(horizontal: hPad, vertical: narrow ? 72 : 104),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section label
          _SectionLabel('THE PROBLEM', dark: false),
          const SizedBox(height: 40),
          // Big headline
          RichText(
            text: _headlineSpan([
              _S('YOUR GAMES ARE', newline: true),
              _S('SCATTERED.', green: true, newline: true),
              _S('YOUR LOSSES ARE', newline: true),
              _S('UNEXPLAINED.', green: true),
            ], narrow ? 40.0 : 60.0,
                base: _C.black, accent: _C.greenLt),
          ),
          const SizedBox(height: 48),
          // Two-column body on wide screens
          narrow
              ? _problemBody()
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _problemBody(left: true)),
                    const SizedBox(width: 56),
                    Expanded(child: _problemBody(left: false)),
                  ],
                ),
        ],
      ),
    );
  }

  Widget _problemBody({bool left = true}) {
    if (left) {
      return RichText(
        text: TextSpan(
          style: _lora(16, color: _C.darkGrey),
          children: const [
            TextSpan(text: 'Paper scoresheets sit forgotten in your bag. '
                'Chess.com games live in one app. Lichess games in another. '
                'You finish a tournament round, lose a '),
            TextSpan(
                text: 'critical endgame',
                style: TextStyle(
                    color: _C.greenLt, fontWeight: FontWeight.w700)),
            TextSpan(text: ' you\'ve lost a dozen times before — '
                'and have no idea why it keeps happening.'),
          ],
        ),
      );
    } else {
      return RichText(
        text: TextSpan(
          style: _lora(16, color: _C.darkGrey),
          children: const [
            TextSpan(text: 'ChessDiary pulls everything into one place, reads your '),
            TextSpan(
                text: 'handwritten scoresheets with AI',
                style: TextStyle(
                    color: _C.greenLt, fontWeight: FontWeight.w700)),
            TextSpan(text: ', runs Stockfish analysis on every game, and surfaces '
                'the precise tactical patterns you keep missing.'),
          ],
        ),
      );
    }
  }
}

// ── stats section (black, green numbers) ─────────────────────────────────────
class _StatsSection extends StatelessWidget {
  const _StatsSection();

  static const _stats = [
    ('∞',      'GAMES SUPPORTED\nPAPER · ONLINE · PGN'),
    ('100%',   'STOCKFISH-POWERED\nNOT JUST AI GUESSWORK'),
    ('8',      'TACTICAL PATTERNS\nTRACKED PER GAME'),
    ('1',      'PLACE FOR EVERYTHING\nEVERY FORMAT UNIFIED'),
  ];

  @override
  Widget build(BuildContext context) {
    final w      = MediaQuery.sizeOf(context).width;
    final narrow = w < 700;
    final hPad   = narrow ? 28.0 : (w < 1100 ? 56.0 : 100.0);

    return Container(
      color: _C.charcoal,
      padding: EdgeInsets.symmetric(horizontal: hPad, vertical: narrow ? 72 : 104),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionLabel('WHAT WE TRACK', dark: true),
          const SizedBox(height: 56),
          // 2-column grid on wide, 1-col on narrow
          LayoutBuilder(builder: (_, c) {
            final cols = c.maxWidth > 600 ? 2 : 1;
            return Wrap(
              spacing: 0,
              runSpacing: 0,
              children: _stats.map((s) {
                final itemW = cols == 2
                    ? (c.maxWidth - 1) / 2
                    : c.maxWidth;
                return SizedBox(
                  width: itemW,
                  child: _StatItem(number: s.$1, label: s.$2),
                );
              }).toList(),
            );
          }),
          const SizedBox(height: 72),
          // Bottom note
          Center(
            child: Text(
              'Built by a student chess player, for chess players.',
              style: _lora(13,
                  color: _C.midGrey,
                  style: FontStyle.italic),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String number;
  final String label;
  const _StatItem({required this.number, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(0, 0, 48, 64),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(number, style: _anton(80, color: _C.greenDark, spacing: 0)),
          const SizedBox(height: 8),
          Text(label,
              style: _lora(11,
                  color: _C.silver,
                  weight: FontWeight.w600)),
          const SizedBox(height: 20),
          Container(width: 32, height: 1, color: _C.darkGrey),
        ],
      ),
    );
  }
}

// ── features section (alternating dark / light) ───────────────────────────────
class _FeaturesSection extends StatelessWidget {
  const _FeaturesSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: const [
        _FeaturePanel(
          number: '01',
          title: ['AI-POWERED', 'IMPORT'],
          greenWord: 'IMPORT',
          body: 'Photograph a handwritten scoresheet. Screenshot your phone screen. '
              'Paste a PGN. Gemini AI reads every format and extracts the moves '
              'automatically — no manual entry, no lost games.',
          dark: true,
        ),
        _FeaturePanel(
          number: '02',
          title: ['REAL ENGINE', 'ANALYSIS'],
          greenWord: 'ENGINE',
          body: 'Every game is run through Stockfish — the same engine world '
              'champions use. Not AI guesswork: precise centipawn scores, '
              'blunders flagged to the half-move, evaluation curves for the whole game.',
          dark: false,
        ),
        _FeaturePanel(
          number: '03',
          title: ['TACTICAL', 'PATTERN RECOGNITION'],
          greenWord: 'TACTICAL',
          body: 'ChessDiary identifies whether your blunders are forks, pins, '
              'back-rank threats, or hanging pieces. After 20 games, you\'ll '
              'know exactly which motif is costing you the most rating points.',
          dark: true,
        ),
      ],
    );
  }
}

class _FeaturePanel extends StatelessWidget {
  final String number;
  final List<String> title;
  final String greenWord;
  final String body;
  final bool dark;
  const _FeaturePanel({
    required this.number,
    required this.title,
    required this.greenWord,
    required this.body,
    required this.dark,
  });

  @override
  Widget build(BuildContext context) {
    final w      = MediaQuery.sizeOf(context).width;
    final narrow = w < 800;
    final hPad   = narrow ? 28.0 : (w < 1100 ? 56.0 : 100.0);
    final bg     = dark ? _C.black : _C.offWhite;
    final accent = dark ? _C.greenDark : _C.greenLt;

    return Container(
      color: bg,
      padding: EdgeInsets.symmetric(horizontal: hPad, vertical: narrow ? 64 : 96),
      child: narrow
          ? _content(accent, narrow)
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left: number + chess motif
                SizedBox(
                  width: 200,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(number,
                          style: _anton(120,
                              color: dark
                                  ? _C.darkGrey
                                  : _C.cream,
                              spacing: 0)),
                      const SizedBox(height: 16),
                      Text('♟',
                          style: TextStyle(
                              fontSize: 32, color: accent)),
                    ],
                  ),
                ),
                const SizedBox(width: 48),
                // Right: text
                Expanded(child: _content(accent, narrow)),
              ],
            ),
    );
  }

  Widget _content(Color accent, bool narrow) {
    // Build headline with the green word
    final spans = title.asMap().entries.map((e) {
      final word = e.value;
      return _S(
        e.key == title.length - 1 ? word : '$word\n',
        green: word == greenWord,
      );
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: _headlineSpan(spans, narrow ? 36.0 : 50.0,
              base: dark ? _C.white : _C.black, accent: accent),
        ),
        const SizedBox(height: 24),
        Container(width: 40, height: 2, color: accent),
        const SizedBox(height: 24),
        Text(body,
            style: _lora(15,
                color: dark ? _C.silver : _C.midGrey)),
      ],
    );
  }
}

// ── auth section ──────────────────────────────────────────────────────────────
class _AuthSection extends StatelessWidget {
  final bool isLogin, loading, gLoading, obscure;
  final TextEditingController nameCtrl, emailCtrl, passCtrl;
  final VoidCallback onToggleMode, onToggleObscure, onSubmit, onGoogle;

  const _AuthSection({
    super.key,
    required this.isLogin,
    required this.loading,
    required this.gLoading,
    required this.obscure,
    required this.nameCtrl,
    required this.emailCtrl,
    required this.passCtrl,
    required this.onToggleMode,
    required this.onToggleObscure,
    required this.onSubmit,
    required this.onGoogle,
  });

  @override
  Widget build(BuildContext context) {
    final w      = MediaQuery.sizeOf(context).width;
    final narrow = w < 700;
    final hPad   = narrow ? 24.0 : (w < 1100 ? 56.0 : 100.0);

    return Container(
      color: _C.cream,
      padding: EdgeInsets.symmetric(horizontal: hPad, vertical: narrow ? 64 : 96),
      child: narrow
          ? _formColumn(context)
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left: headline
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      RichText(
                        text: _headlineSpan([
                          _S('READY TO', newline: true),
                          _S('START?', green: true),
                        ], 56.0,
                            base: _C.black, accent: _C.greenLt),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Free to use. No credit card. Your games stay private.',
                        style: _lora(14, color: _C.midGrey),
                      ),
                      const SizedBox(height: 32),
                      Row(
                        children: [
                          Container(width: 3, height: 3,
                              decoration: const BoxDecoration(
                                  color: _C.greenLt,
                                  shape: BoxShape.circle)),
                          const SizedBox(width: 10),
                          Text('Import from Chess.com & Lichess',
                              style: _lora(13, color: _C.midGrey)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Container(width: 3, height: 3,
                              decoration: const BoxDecoration(
                                  color: _C.greenLt,
                                  shape: BoxShape.circle)),
                          const SizedBox(width: 10),
                          Text('AI reads handwritten scoresheets',
                              style: _lora(13, color: _C.midGrey)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Container(width: 3, height: 3,
                              decoration: const BoxDecoration(
                                  color: _C.greenLt,
                                  shape: BoxShape.circle)),
                          const SizedBox(width: 10),
                          Text('Stockfish analysis on every game',
                              style: _lora(13, color: _C.midGrey)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 64),
                // Right: form
                SizedBox(width: 400, child: _formColumn(context)),
              ],
            ),
    );
  }

  Widget _formColumn(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          isLogin ? 'Welcome back.' : 'Create your account.',
          style: GoogleFonts.lora(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: _C.black),
        ),
        const SizedBox(height: 28),

        // Google button
        if (gLoading)
          const Center(
              child: CircularProgressIndicator(color: _C.greenLt))
        else
          OutlinedButton(
            onPressed: onGoogle,
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: _C.borderLt),
              backgroundColor: _C.white,
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('G',
                    style: GoogleFonts.lora(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: _C.black)),
                const SizedBox(width: 10),
                Text('Continue with Google',
                    style: _lora(14,
                        color: _C.black,
                        weight: FontWeight.w600)),
              ],
            ),
          ),

        const SizedBox(height: 20),
        Row(children: [
          const Expanded(child: Divider(color: _C.borderLt)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text('or', style: _lora(12, color: _C.midGrey)),
          ),
          const Expanded(child: Divider(color: _C.borderLt)),
        ]),
        const SizedBox(height: 20),

        if (!isLogin) ...[
          _LightField(
              ctrl: nameCtrl,
              label: 'Your name',
              icon: Icons.person_outline_rounded),
          const SizedBox(height: 12),
        ],
        _LightField(
            ctrl: emailCtrl,
            label: 'Email address',
            icon: Icons.email_outlined,
            type: TextInputType.emailAddress),
        const SizedBox(height: 12),
        _LightField(
          ctrl: passCtrl,
          label: 'Password',
          icon: Icons.lock_outline_rounded,
          obscure: obscure,
          suffix: IconButton(
            icon: Icon(
              obscure
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
              size: 18,
              color: _C.midGrey,
            ),
            onPressed: onToggleObscure,
          ),
        ),
        const SizedBox(height: 24),

        if (loading)
          const Center(child: CircularProgressIndicator(color: _C.greenLt))
        else
          ElevatedButton(
            onPressed: onSubmit,
            style: ElevatedButton.styleFrom(
              backgroundColor: _C.black,
              foregroundColor: _C.white,
              minimumSize: const Size.fromHeight(50),
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4)),
              textStyle: GoogleFonts.anton(fontSize: 14, letterSpacing: 2),
            ),
            child: Text(isLogin ? 'SIGN IN' : 'CREATE ACCOUNT'),
          ),

        const SizedBox(height: 16),
        Center(
          child: TextButton(
            onPressed: onToggleMode,
            child: Text(
              isLogin
                  ? "Don't have an account? Sign up →"
                  : 'Already have an account? Sign in →',
              style: _lora(13,
                  color: _C.greenLt,
                  weight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }
}

// ── footer ────────────────────────────────────────────────────────────────────
class _Footer extends StatelessWidget {
  const _Footer();

  void _open(String path) =>
      launchUrl(Uri.parse('https://chessdiary.app$path'));

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final narrow = w <= 600;
    return Container(
      color: _C.black,
      padding: EdgeInsets.symmetric(
          horizontal: narrow ? 24 : 48, vertical: 28),
      child: narrow
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: TextSpan(children: [
                    TextSpan(text: 'CHESS', style: _anton(12, color: _C.silver, spacing: 2)),
                    TextSpan(text: 'DIARY', style: _anton(12, color: _C.greenDark, spacing: 2)),
                  ]),
                ),
                const SizedBox(height: 14),
                _FooterLinks(onOpen: _open),
              ],
            )
          : Row(
              children: [
                RichText(
                  text: TextSpan(children: [
                    TextSpan(text: 'CHESS', style: _anton(12, color: _C.silver, spacing: 2)),
                    TextSpan(text: 'DIARY', style: _anton(12, color: _C.greenDark, spacing: 2)),
                  ]),
                ),
                const Spacer(),
                _FooterLinks(onOpen: _open),
              ],
            ),
    );
  }
}

class _FooterLinks extends StatelessWidget {
  final void Function(String path) onOpen;
  const _FooterLinks({required this.onOpen});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 20,
      runSpacing: 8,
      children: [
        _FooterLink('Privacy Policy', () => onOpen('/privacy')),
        _FooterLink('Delete My Account', () => onOpen('/delete-account')),
        Text('© 2026 ChessDiary', style: _lora(11, color: _C.silver)),
      ],
    );
  }
}

class _FooterLink extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  const _FooterLink(this.label, this.onTap);

  @override
  State<_FooterLink> createState() => _FooterLinkState();
}

class _FooterLinkState extends State<_FooterLink> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit:  (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Text(
          widget.label,
          style: _lora(11,
              color: _hovered ? _C.white : _C.silver,
              weight: FontWeight.w600),
        ),
      ),
    );
  }
}

// ── sticky right-edge tabs ────────────────────────────────────────────────────
class _StickyTabs extends StatelessWidget {
  final VoidCallback onSignIn;
  const _StickyTabs({required this.onSignIn});

  @override
  Widget build(BuildContext context) {
    // Hide on narrow screens to avoid crowding
    if (MediaQuery.sizeOf(context).width < 700) return const SizedBox();
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.max,
      children: [
        _VerticalTab(
          label: 'YOUR STATS',
          bgColor: _C.greenLt,
          onTap: () {},
        ),
        const SizedBox(height: 3),
        _VerticalTab(
          label: 'SIGN IN',
          bgColor: _C.black,
          onTap: onSignIn,
          borderColor: _C.darkGrey,
        ),
      ],
    );
  }
}

class _VerticalTab extends StatefulWidget {
  final String label;
  final Color bgColor;
  final Color? borderColor;
  final VoidCallback onTap;
  const _VerticalTab({
    required this.label,
    required this.bgColor,
    required this.onTap,
    this.borderColor,
  });

  @override
  State<_VerticalTab> createState() => _VerticalTabState();
}

class _VerticalTabState extends State<_VerticalTab> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit:  (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          color: _hovered
              ? widget.bgColor.withValues(alpha: 0.85)
              : widget.bgColor,
          // Border on left side only
          child: Container(
            decoration: widget.borderColor != null
                ? BoxDecoration(
                    border: Border(
                        left: BorderSide(color: widget.borderColor!, width: 1)))
                : null,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 18),
            // RotatedBox quarter=1 → 90° CW, text reads bottom-to-top
            child: RotatedBox(
              quarterTurns: 1,
              child: Text(
                widget.label,
                style: _anton(11,
                    color: _C.white, spacing: 2.5),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── shared: arrow text link ───────────────────────────────────────────────────
class _ArrowLink extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  final Color color;
  final double fontSize;
  final bool bold;
  const _ArrowLink({
    required this.label,
    required this.onTap,
    required this.color,
    required this.fontSize,
    this.bold = false,
  });

  @override
  State<_ArrowLink> createState() => _ArrowLinkState();
}

class _ArrowLinkState extends State<_ArrowLink> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit:  (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 150),
          style: _lora(widget.fontSize,
              color: _hovered
                  ? _C.greenDark
                  : widget.color,
              weight: widget.bold ? FontWeight.w700 : FontWeight.w500),
          child: Text('${widget.label}  →'),
        ),
      ),
    );
  }
}

// ── shared: section eyebrow label ────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String text;
  final bool dark; // true = dark background (white label)
  const _SectionLabel(this.text, {required this.dark});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 20, height: 1,
          color: dark ? _C.greenDark : _C.greenLt,
        ),
        const SizedBox(width: 12),
        Text(
          text,
          style: _lora(11,
              color: dark ? _C.greenDark : _C.greenLt,
              weight: FontWeight.w700,
              style: FontStyle.italic),
        ),
      ],
    );
  }
}

// ── light-background text field ───────────────────────────────────────────────
class _LightField extends StatelessWidget {
  final TextEditingController ctrl;
  final String label;
  final IconData icon;
  final bool obscure;
  final TextInputType? type;
  final Widget? suffix;

  const _LightField({
    required this.ctrl,
    required this.label,
    required this.icon,
    this.obscure = false,
    this.type,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: ctrl,
      obscureText: obscure,
      keyboardType: type,
      style: _lora(14, color: _C.black),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: _lora(13, color: _C.midGrey),
        prefixIcon: Icon(icon, size: 18, color: _C.midGrey),
        suffixIcon: suffix,
        filled: true,
        fillColor: _C.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
            borderSide: const BorderSide(color: _C.borderLt)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
            borderSide: const BorderSide(color: _C.borderLt)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
            borderSide: const BorderSide(color: _C.greenLt, width: 1.5)),
      ),
    );
  }
}
