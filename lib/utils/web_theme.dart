// lib/utils/web_theme.dart
// Canonical editorial design system for all post-login web screens.
// Palette, typography, and widgets match the landing page's editorial style.

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ── palette ───────────────────────────────────────────────────────────────────
// Matches _C in web_landing_screen.dart exactly.
class WT {
  // Base scale
  static const black    = Color(0xFF0C0C0C);
  static const charcoal = Color(0xFF1A1A1A);
  static const darkGrey = Color(0xFF2E2E2E);
  static const silver   = Color(0xFFAAAAAA);
  static const white    = Color(0xFFFFFFFF);
  static const offWhite = Color(0xFFF4F3EF);
  static const cream    = Color(0xFFE8E6DF);

  // Aliases for backward compat with screens already using old names
  static const bg     = offWhite;
  static const bgAlt  = cream;
  static const ink    = Color(0xFF0C0C0C);
  static const muted  = Color(0xFF666666);
  static const card   = white;
  static const border = Color(0xFFD0CEC7);

  // Green – two strengths for different backgrounds
  static const greenLt   = Color(0xFF1B5E20); // on light/white
  static const greenDark = Color(0xFF66BB6A); // on dark/black
  static const accent    = greenLt;           // backward compat
  static const accentLt  = greenDark;         // backward compat

  // Result / quality – tuned for light backgrounds
  static const win        = Color(0xFF1B5E20);
  static const loss       = Color(0xFF7F0000);
  static const draw       = Color(0xFF424242);
  static const blunder    = Color(0xFF7F0000);
  static const mistake    = Color(0xFFBF360C);
  static const inaccuracy = Color(0xFF9E6B00);

  // ── helpers ──────────────────────────────────────────────────────────────
  static bool isWide(BuildContext ctx) =>
      kIsWeb && MediaQuery.sizeOf(ctx).width >= 1100;

  static Color resultColor(String result) {
    switch (result) {
      case 'Win':  return win;
      case 'Loss': return loss;
      default:     return draw;
    }
  }

  static Color qualityColor(String q) {
    switch (q) {
      case 'blunder':    return blunder;
      case 'mistake':    return mistake;
      case 'inaccuracy': return inaccuracy;
      case 'best':
      case 'good':       return win;
      default:           return muted;
    }
  }

  // ── typography ────────────────────────────────────────────────────────────
  /// Condensed bold headline font — always all-caps by convention.
  static TextStyle anton(double size,
          {Color color = white, double spacing = 1.5}) =>
      GoogleFonts.anton(
          fontSize: size, color: color, letterSpacing: spacing, height: 0.95);

  /// Elegant serif body font.
  static TextStyle lora(double size,
          {Color color = const Color(0xFF666666),
          FontWeight weight = FontWeight.w400,
          FontStyle style = FontStyle.normal}) =>
      GoogleFonts.lora(
          fontSize: size,
          color: color,
          fontWeight: weight,
          fontStyle: style,
          height: 1.65);

  // Kept for backward compat — now delegates to Lora.
  static TextStyle labelSm(double size,
          {Color? color, FontWeight weight = FontWeight.w600}) =>
      lora(size, color: color ?? ink, weight: weight);

  static TextStyle bodySm(double size, {Color? color}) =>
      lora(size, color: color ?? muted);

  // ── card decoration ───────────────────────────────────────────────────────
  static BoxDecoration cardDeco({bool hovered = false, Color? accentBorder}) =>
      BoxDecoration(
        color: hovered ? cream : card,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
            color: accentBorder != null
                ? accentBorder.withValues(alpha: hovered ? 0.45 : 0.2)
                : border),
        boxShadow: [
          BoxShadow(
            color: Color(hovered ? 0x0E000000 : 0x06000000),
            blurRadius: hovered ? 14 : 5,
            offset: const Offset(0, 2),
          ),
        ],
      );
}

// ── sticky-tab data model ─────────────────────────────────────────────────────
class WebTabItem {
  final String label;
  final Color bgColor;
  final VoidCallback onTap;
  const WebTabItem(this.label, this.bgColor, this.onTap);
}

// ── body wrapper — Stack-based sticky right-edge tabs ─────────────────────────
/// Wrap a Scaffold's body with this to add persistent vertical tabs.
/// The Positioned element sits outside any inner scroll view, so it stays
/// fixed in screen space regardless of scroll position.
class WebBodyWithTabs extends StatelessWidget {
  final Widget child;
  final List<WebTabItem> tabs;
  const WebBodyWithTabs(
      {super.key, required this.child, required this.tabs});

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb || tabs.isEmpty ||
        MediaQuery.sizeOf(context).width < 640) return child;
    return Stack(
      children: [
        child,
        Positioned(
          right: 0,
          top: 0,
          bottom: 0,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (int i = 0; i < tabs.length; i++) ...[
                if (i > 0) const SizedBox(height: 3),
                _WebVerticalTab(item: tabs[i]),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _WebVerticalTab extends StatefulWidget {
  final WebTabItem item;
  const _WebVerticalTab({required this.item});

  @override
  State<_WebVerticalTab> createState() => _WebVerticalTabState();
}

class _WebVerticalTabState extends State<_WebVerticalTab> {
  bool _h = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _h = true),
      onExit:  (_) => setState(() => _h = false),
      child: GestureDetector(
        onTap: widget.item.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 130),
          color: _h
              ? widget.item.bgColor.withValues(alpha: 0.80)
              : widget.item.bgColor,
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 15),
          child: RotatedBox(
            quarterTurns: 1,
            child: Text(widget.item.label,
                style: WT.anton(10, color: WT.white, spacing: 2.0)),
          ),
        ),
      ),
    );
  }
}

// ── editorial AppBar ──────────────────────────────────────────────────────────
/// Black AppBar with Anton title, optional bottom widget.
/// Use on every post-login web screen.
AppBar webAppBar(
  BuildContext context, {
  required String title,
  List<Widget> actions = const [],
  PreferredSizeWidget? bottom,
  bool automaticallyImplyLeading = true,
}) {
  return AppBar(
    backgroundColor: WT.black,
    foregroundColor: WT.white,
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    automaticallyImplyLeading: automaticallyImplyLeading,
    iconTheme: const IconThemeData(color: WT.silver, size: 18),
    title: Text(title.toUpperCase(),
        style: WT.anton(14, color: WT.white, spacing: 2.0)),
    actions: actions,
    bottom: bottom ??
        PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: WT.darkGrey),
        ),
    shape: bottom != null ? null : InputBorder.none,
  );
}

// ── stat grid — large number / serif label ────────────────────────────────────
class WebStatItem {
  final String number;
  final String label;
  const WebStatItem(this.number, this.label);
}

class WebStatGrid extends StatelessWidget {
  final List<WebStatItem> items;
  final bool onDark;
  const WebStatGrid(
      {super.key, required this.items, this.onDark = false});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (_, c) {
      final cols = c.maxWidth > 540 ? 2 : 1;
      final w = cols == 2 ? (c.maxWidth - 1) / 2 : c.maxWidth;
      return Wrap(
        children: items
            .map((s) => SizedBox(width: w, child: _StatCell(s, onDark)))
            .toList(),
      );
    });
  }
}

class _StatCell extends StatelessWidget {
  final WebStatItem item;
  final bool onDark;
  const _StatCell(this.item, this.onDark);

  @override
  Widget build(BuildContext context) {
    final numC = onDark ? WT.greenDark : WT.greenLt;
    final lblC = onDark ? WT.silver    : WT.muted;
    final divC = onDark ? WT.darkGrey  : WT.border;
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 0, 40, 44),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(item.number, style: WT.anton(58, color: numC, spacing: 0)),
          const SizedBox(height: 5),
          Text(item.label,
              style: WT.lora(11, color: lblC, weight: FontWeight.w600)),
          const SizedBox(height: 12),
          Container(width: 24, height: 1, color: divC),
        ],
      ),
    );
  }
}

// ── section label ─────────────────────────────────────────────────────────────
class WebSectionLabel extends StatelessWidget {
  final String text;
  final bool onDark;
  const WebSectionLabel(this.text, {super.key, this.onDark = false});

  @override
  Widget build(BuildContext context) {
    final c = onDark ? WT.greenDark : WT.greenLt;
    return Row(
      children: [
        Container(width: 16, height: 1, color: c),
        const SizedBox(width: 10),
        Text(text.toUpperCase(),
            style: WT.lora(10,
                color: c,
                weight: FontWeight.w700,
                style: FontStyle.italic)),
      ],
    );
  }
}

// ── arrow text link ───────────────────────────────────────────────────────────
class WebArrowLink extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  final Color? color;
  final double fontSize;
  const WebArrowLink(this.label, this.onTap,
      {super.key, this.color, this.fontSize = 14});

  @override
  State<WebArrowLink> createState() => _WebArrowLinkState();
}

class _WebArrowLinkState extends State<WebArrowLink> {
  bool _h = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _h = true),
      onExit:  (_) => setState(() => _h = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Text('${widget.label}  →',
            style: WT.lora(widget.fontSize,
                color: _h
                    ? WT.greenDark
                    : (widget.color ?? WT.greenLt),
                weight: FontWeight.w600)),
      ),
    );
  }
}

// ── ad rail ───────────────────────────────────────────────────────────────────
class WebAdRail extends StatelessWidget {
  const WebAdRail({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 160,
      color: WT.offWhite,
      child: Column(
        children: [
          Container(height: 1, color: WT.border),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 20, 10, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: const [
                  _AdSlot(height: 260),
                  SizedBox(height: 10),
                  _AdSlot(height: 240),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AdSlot extends StatelessWidget {
  final double height;
  const _AdSlot({required this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: WT.white,
        border: Border.all(color: WT.border),
      ),
      child: Center(
        child: RotatedBox(
          quarterTurns: 1,
          child: Text('AD SPACE',
              style: WT.lora(9,
                  color: WT.border,
                  weight: FontWeight.w600,
                  style: FontStyle.italic)),
        ),
      ),
    );
  }
}

// ── chess loader ──────────────────────────────────────────────────────────────
class WebChessLoader extends StatelessWidget {
  final String? message;
  const WebChessLoader({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('♟',
              style: TextStyle(
                  fontSize: 36,
                  color: WT.muted.withValues(alpha: 0.35))),
          const SizedBox(height: 20),
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
                strokeWidth: 1.5, color: WT.greenLt),
          ),
          if (message != null) ...[
            const SizedBox(height: 14),
            Text(message!,
                style: WT.lora(13,
                    color: WT.muted,
                    style: FontStyle.italic)),
          ],
        ],
      ),
    );
  }
}

// ── empty state ───────────────────────────────────────────────────────────────
class WebEmptyState extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget? action;
  const WebEmptyState({
    super.key,
    required this.title,
    required this.subtitle,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(56),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('♟  ♛  ♞',
                style: TextStyle(
                    fontSize: 28,
                    color: WT.muted.withValues(alpha: 0.18),
                    letterSpacing: 10)),
            const SizedBox(height: 28),
            Container(width: 28, height: 1, color: WT.border),
            const SizedBox(height: 22),
            Text(title.toUpperCase(),
                style: WT.anton(20, color: WT.darkGrey, spacing: 2.0),
                textAlign: TextAlign.center),
            const SizedBox(height: 10),
            Text(subtitle,
                style: WT.lora(14, color: WT.muted),
                textAlign: TextAlign.center),
            if (action != null) ...[
              const SizedBox(height: 22),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

// ── insight card (editorial version for coaching) ─────────────────────────────
class WebInsightCard extends StatelessWidget {
  final String title;
  final String body;
  final Color accentColor;
  const WebInsightCard({
    super.key,
    required this.title,
    required this.body,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: WT.white,
        border: Border(left: BorderSide(color: accentColor, width: 3)),
        boxShadow: const [
          BoxShadow(
              color: Color(0x06000000), blurRadius: 5, offset: Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title.toUpperCase(),
              style: WT.anton(12, color: WT.darkGrey, spacing: 1.5)),
          const SizedBox(height: 7),
          Text(body, style: WT.lora(13, color: WT.muted)),
        ],
      ),
    );
  }
}
