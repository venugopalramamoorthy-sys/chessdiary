// lib/screens/publish_report_screen.dart
//
// Publish an analysed game as a public web page (see public_report_service).
// Shows exactly what becomes public, collects the player's notes and a
// comment per critical moment, and requires explicit consent.

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_chess_board/flutter_chess_board.dart'
    show BoardColor, ChessBoard, ChessBoardController, PlayerColor;
import '../models/game_model.dart';
import '../services/public_report_service.dart';
import '../utils/theme.dart';
import '../utils/web_theme.dart';

class PublishReportScreen extends StatefulWidget {
  final ChessGame game;
  const PublishReportScreen({super.key, required this.game});

  /// Pops with the game's slug after publishing, or with '' after unpublishing.
  static Future<String?> open(BuildContext context, ChessGame game) =>
      Navigator.push<String>(
          context, MaterialPageRoute(builder: (_) => PublishReportScreen(game: game)));

  @override
  State<PublishReportScreen> createState() => _PublishReportScreenState();
}

class _PublishReportScreenState extends State<PublishReportScreen> {
  final _nameCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  late final List<ReportMoment> _moments;
  late final List<TextEditingController> _commentCtrls;
  late final List<ChessBoardController> _boards;
  bool _showOpponent = false;
  bool _showEvent = false;
  bool _consent = false;
  bool _loading = true;
  bool _saving = false;
  bool _wasApproved = false;
  String? _error;

  ChessGame get _game => widget.game;
  bool get _online => _game.source == 'chess.com' || _game.source == 'lichess';
  bool get _published => _game.publicSlug != null;

  @override
  void initState() {
    super.initState();
    _moments = PublicReportService.pickMoments(_game);
    _commentCtrls = List.generate(_moments.length, (_) => TextEditingController());
    _boards = [for (final m in _moments) ChessBoardController.fromFEN(m.fen)];
    for (final c in [_nameCtrl, _notesCtrl, ..._commentCtrls]) {
      c.addListener(() => setState(() {}));
    }
    _loadExisting();
  }

  // Re-publishing starts from what is already public.
  Future<void> _loadExisting() async {
    final slug = _game.publicSlug;
    if (slug != null) {
      try {
        final r = await PublicReportService.fetch(slug);
        if (r != null) {
          _nameCtrl.text = r['authorName'] ?? '';
          _notesCtrl.text = r['notes'] ?? '';
          _showOpponent = r[_game.playerColor == 'black' ? 'whiteName' : 'blackName'] != 'Opponent';
          _showEvent = r['event'] != null;
          _wasApproved = r['approved'] == true;
          final byPly = {
            for (final m in (r['moments'] as List? ?? const [])) m['ply']: m['comment'] ?? '',
          };
          for (var i = 0; i < _moments.length; i++) {
            _commentCtrls[i].text = byPly[_moments[i].ply] ?? '';
          }
        }
      } catch (_) {
        // Fall through to an empty form; publishing again overwrites.
      }
    } else {
      _notesCtrl.text = _game.notes ?? '';
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  void dispose() {
    for (final c in [_nameCtrl, _notesCtrl, ..._commentCtrls]) {
      c.dispose();
    }
    super.dispose();
  }

  List<String> get _comments => _commentCtrls.map((c) => c.text).toList();
  int get _ownWords => PublicReportService.ownWords(_notesCtrl.text, _comments);
  int get _commented => _comments.where((c) => c.trim().isNotEmpty).length;
  bool get _meetsBar => PublicReportService.meetsIndexBar(_notesCtrl.text, _comments);

  String? _validate() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return 'Choose the name to show on the page.';
    if (name.contains('@')) return "Use a display name, not an email address.";
    final bad = PublicReportService.blockedWord([name, _notesCtrl.text, ..._comments]);
    if (bad != null) return 'Please remove "$bad" before publishing.';
    if (!_consent) return 'Tick the box to confirm this becomes a public page.';
    return null;
  }

  Future<void> _publish() async {
    final problem = _validate();
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    setState(() { _saving = true; _error = null; });
    try {
      final slug = await PublicReportService.publish(
        game: _game,
        authorName: _nameCtrl.text,
        showOpponentName: _showOpponent,
        showEvent: _showEvent,
        notes: _notesCtrl.text,
        moments: _moments,
        comments: _comments,
      );
      if (mounted) Navigator.pop(context, slug);
    } catch (e) {
      setState(() => _error = 'Could not publish: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _unpublish() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Unpublish this game?'),
        content: const Text('The public page and its link stop working. Your game stays in your library.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Unpublish')),
        ],
      ),
    );
    if (ok != true) return;
    setState(() { _saving = true; _error = null; });
    try {
      await PublicReportService.unpublish(_game);
      if (mounted) Navigator.pop(context, '');
    } catch (e) {
      setState(() => _error = 'Could not unpublish: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ── styling helpers (web editorial theme vs dark mobile theme) ──────────
  Color get _text => kIsWeb ? WT.textColor : AppTheme.textPrimary;
  Color get _muted => kIsWeb ? WT.mutedColor : AppTheme.textSecondary;
  Color get _accent => kIsWeb ? WT.greenAccent : AppTheme.primary;
  Color get _card => kIsWeb ? WT.cardBg : AppTheme.surface;
  Color get _border => kIsWeb ? WT.borderColor : AppTheme.surfaceAlt;

  TextStyle _body(double size, {Color? color, FontWeight weight = FontWeight.w400}) => kIsWeb
      ? WT.lora(size, color: color ?? _muted, weight: weight)
      : TextStyle(fontSize: size, color: color ?? _muted, fontWeight: weight, height: 1.45);

  Widget _heading(String text) => Padding(
        padding: const EdgeInsets.only(top: 28, bottom: 10),
        child: kIsWeb
            ? WebSectionLabel(text)
            : Text(text.toUpperCase(),
                style: TextStyle(color: _accent, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1.2)),
      );

  InputDecoration _input(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: _body(13),
        filled: true,
        fillColor: _card,
        isDense: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: _border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: _border)),
      );

  @override
  Widget build(BuildContext context) {
    final title = _published ? 'Update public page' : 'Publish to web';
    return Scaffold(
      backgroundColor: kIsWeb ? WT.scaffoldBg : AppTheme.background,
      appBar: kIsWeb
          ? webAppBar(context, title: title)
          : AppBar(title: Text(title), backgroundColor: AppTheme.surface, foregroundColor: AppTheme.textPrimary),
      body: _loading
          ? (kIsWeb ? const WebChessLoader() : const Center(child: CircularProgressIndicator()))
          : SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
                    children: [
                      Text(
                        'This creates a public page anyone with the link can read. Once reviewed, it can also '
                        'appear on chessdiary.app/games and in search results, with ads.',
                        style: _body(14, color: _text),
                      ),
                      if (_published) ...[
                        const SizedBox(height: 14),
                        _linkRow(PublicReportService.urlFor(_game.publicSlug!)),
                        if (_wasApproved)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text('Saving changes sends the page back for review before it is listed again.',
                                style: _body(12.5)),
                          ),
                      ],
                      _heading('What will be public'),
                      _bullet('The moves, the engine evaluations and the flagged moves.'),
                      _bullet(_online
                          ? 'The date you played. Your opponent is shown as "Opponent" unless you choose to show their username below.'
                          : 'The month you played, not the day. Your opponent is always shown as "Opponent" for over-the-board games.'),
                      _bullet('Ratings, opening and time control, if the game has them.'),
                      _bullet('Your notes and comments below, under the name you choose.'),
                      _bullet('Never public: your email, your account name, your opponent\'s real name, scoresheet photos.'),

                      _heading('Your name on the page'),
                      TextField(
                        controller: _nameCtrl,
                        maxLength: PublicReportService.maxNameChars,
                        style: _body(14, color: _text),
                        decoration: _input('A display name, e.g. KnightOwl'),
                      ),
                      if (_online && _game.opponentName.trim().isNotEmpty)
                        _switch('Show opponent\'s username (${_game.opponentName.trim()})', _showOpponent,
                            (v) => setState(() => _showOpponent = v)),
                      if ((_game.event ?? '').trim().isNotEmpty)
                        _switch('Show the event name (${_game.event!.trim()})', _showEvent,
                            (v) => setState(() => _showEvent = v)),

                      _heading('Your notes on the game'),
                      Text('What were you trying to do? Where did it go wrong, and what did you learn? '
                          'Separate paragraphs with a blank line.', style: _body(13)),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _notesCtrl,
                        minLines: 5,
                        maxLines: 14,
                        maxLength: PublicReportService.maxNotesChars,
                        style: _body(14, color: _text),
                        decoration: _input('Your notes'),
                      ),

                      _heading('Critical moments'),
                      Text('The engine\'s biggest swings in this game. Say what you were thinking when you played each move.',
                          style: _body(13)),
                      for (var i = 0; i < _moments.length; i++) _momentCard(i),

                      const SizedBox(height: 20),
                      _barStatus(),
                      const SizedBox(height: 16),
                      CheckboxListTile(
                        value: _consent,
                        onChanged: (v) => setState(() => _consent = v ?? false),
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        activeColor: _accent,
                        title: Text('I understand this becomes a public web page, and I can unpublish it at any time.',
                            style: _body(13.5, color: _text)),
                      ),
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(_error!, style: _body(13.5, color: kIsWeb ? WT.lossColor : AppTheme.loss)),
                        ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _saving ? null : _publish,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: kIsWeb ? WT.greenLt : AppTheme.primary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                              child: Text(_saving ? 'Saving…' : (_published ? 'Save changes' : 'Publish')),
                            ),
                          ),
                          if (_published) ...[
                            const SizedBox(width: 12),
                            OutlinedButton(
                              onPressed: _saving ? null : _unpublish,
                              style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18)),
                              child: const Text('Unpublish'),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _bullet(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(padding: const EdgeInsets.only(top: 1, right: 8), child: Text('•', style: _body(14, color: _accent))),
            Expanded(child: Text(text, style: _body(13.5))),
          ],
        ),
      );

  Widget _switch(String label, bool value, ValueChanged<bool> onChanged) => SwitchListTile(
        value: value,
        onChanged: onChanged,
        contentPadding: EdgeInsets.zero,
        activeThumbColor: _accent,
        title: Text(label, style: _body(13.5, color: _text)),
      );

  Widget _linkRow(String url) => Row(
        children: [
          Expanded(child: SelectableText(url, style: _body(13.5, color: _accent, weight: FontWeight.w600))),
          IconButton(
            tooltip: 'Copy link',
            icon: Icon(Icons.copy_rounded, size: 18, color: _muted),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: url));
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Link copied')));
            },
          ),
        ],
      );

  Widget _momentCard(int i) {
    final m = _moments[i];
    final n = m.ply ~/ 2 + 1;
    final label = '$n${m.ply.isEven ? '.' : '…'}${m.analysis.move}';
    final loss = m.analysis.centipawnLoss;
    final q = m.analysis.quality;
    final color = kIsWeb ? WT.qualityColor(q) : (q == 'blunder' ? AppTheme.blunder : q == 'mistake' ? AppTheme.mistake : AppTheme.inaccuracy);
    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(6),
        border: Border(left: BorderSide(color: color, width: 3)),
      ),
      child: LayoutBuilder(builder: (context, c) {
        final boardSize = c.maxWidth >= 520 ? 200.0 : c.maxWidth.clamp(0, 260).toDouble();
        final board = SizedBox(
          width: boardSize,
          height: boardSize,
          child: ChessBoard(
            controller: _boards[i],
            size: boardSize,
            enableUserMoves: false,
            boardColor: BoardColor.brown,
            boardOrientation: _game.playerColor == 'black' ? PlayerColor.black : PlayerColor.white,
          ),
        );
        final form = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$label  ·  ${q[0].toUpperCase()}${q.substring(1)}${loss != null && loss > 0 ? '  (−${(loss / 100).toStringAsFixed(1)})' : ''}',
                style: _body(14, color: _text, weight: FontWeight.w700)),
            if ((m.analysis.bestMove ?? '').isNotEmpty)
              Text('Stockfish preferred ${m.analysis.bestMove}', style: _body(12.5)),
            const SizedBox(height: 8),
            TextField(
              controller: _commentCtrls[i],
              minLines: 2,
              maxLines: 6,
              maxLength: PublicReportService.maxCommentChars,
              style: _body(13.5, color: _text),
              decoration: _input('What were you thinking here?'),
            ),
          ],
        );
        return c.maxWidth >= 520
            ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [board, const SizedBox(width: 16), Expanded(child: form)])
            : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Center(child: board), const SizedBox(height: 12), form]);
      }),
    );
  }

  Widget _barStatus() {
    final words = _ownWords;
    final ok = _meetsBar;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kIsWeb ? WT.altBg : AppTheme.surfaceAlt,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(ok ? 'Ready for review' : 'Shared by link only, for now',
              style: _body(14, color: _text, weight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(
            ok
                ? 'Your notes are detailed enough to be reviewed for listing on chessdiary.app/games and in search.'
                : 'To be considered for listing on chessdiary.app/games and in search, write at least '
                    '${PublicReportService.minOwnWords} words in total (you have $words) and comment on at least '
                    '${PublicReportService.minComments} moments (you have $_commented). You can publish now and add more later.',
            style: _body(13),
          ),
        ],
      ),
    );
  }
}
