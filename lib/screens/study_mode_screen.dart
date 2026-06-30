// lib/screens/study_mode_screen.dart
import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_chess_board/flutter_chess_board.dart' hide Color;
import '../models/game_model.dart';
import '../services/game_service.dart';
import '../utils/theme.dart';
import '../utils/web_theme.dart';

enum _PuzzleOutcome { pending, solved, revealed }

class _Puzzle {
  final ChessGame game;
  final MoveAnalysis mistake;
  final int halfMoveIndex; // 0-based index in game.moves, BEFORE the mistake
  final String fenBeforeMistake;

  _Puzzle({
    required this.game,
    required this.mistake,
    required this.halfMoveIndex,
    required this.fenBeforeMistake,
  });
}

class StudyModeScreen extends StatefulWidget {
  const StudyModeScreen({super.key});

  @override
  State<StudyModeScreen> createState() => _StudyModeScreenState();
}

class _StudyModeScreenState extends State<StudyModeScreen> {
  List<_Puzzle> _puzzles = [];
  int _index = 0;
  bool _loading = true;
  String _filter = 'blunder';
  final ChessBoardController _boardCtrl = ChessBoardController();

  _PuzzleOutcome _outcome = _PuzzleOutcome.pending;
  int _attempts = 0;
  Timer? _advanceTimer;

  @override
  void initState() {
    super.initState();
    _loadPuzzles();
  }

  @override
  void dispose() {
    _advanceTimer?.cancel();
    super.dispose();
  }

  // ── Data loading ─────────────────────────────────────────────────────────────

  Future<void> _loadPuzzles() async {
    setState(() {
      _loading = true;
      _puzzles = [];
    });
    final games = await GameService.getAllGames();
    final puzzles = <_Puzzle>[];

    for (final g in games) {
      if (g.analysis.isEmpty || g.moves.isEmpty) continue;
      for (final a in g.analysis) {
        if (_filter == 'blunder' && a.quality != 'blunder') continue;
        if (_filter == 'mistake' && a.quality != 'mistake') continue;
        if (_filter == 'both' &&
            a.quality != 'blunder' &&
            a.quality != 'mistake') continue;

        // Match the analysis move to its half-move index in the move list
        int halfIdx = -1;
        for (int i = 0; i < g.moves.length; i++) {
          if (g.moves[i] == a.move && (i ~/ 2) + 1 == a.moveNumber) {
            halfIdx = i;
            break;
          }
        }
        if (halfIdx < 0) continue;

        final fenBefore = _buildFen(g.moves, halfIdx);
        if (fenBefore == null) continue;

        puzzles.add(_Puzzle(
          game: g,
          mistake: a,
          halfMoveIndex: halfIdx,
          fenBeforeMistake: fenBefore,
        ));
      }
    }

    puzzles.shuffle();

    setState(() {
      _puzzles = puzzles;
      _index = 0;
      _loading = false;
      _outcome = _PuzzleOutcome.pending;
      _attempts = 0;
    });
    if (puzzles.isNotEmpty) _boardCtrl.loadFen(puzzles[0].fenBeforeMistake);
  }

  String? _buildFen(List<String> moves, int upToIndex) {
    try {
      final ctrl = ChessBoardController();
      for (int i = 0; i < upToIndex; i++) {
        ctrl.makeMoveWithNormalNotation(moves[i]);
      }
      return ctrl.getFen();
    } catch (_) {
      return null;
    }
  }

  // ── Puzzle navigation ─────────────────────────────────────────────────────────

  void _goTo(int newIdx) {
    _advanceTimer?.cancel();
    _boardCtrl.loadFen(_puzzles[newIdx].fenBeforeMistake);
    setState(() {
      _index = newIdx;
      _outcome = _PuzzleOutcome.pending;
      _attempts = 0;
    });
  }

  void _next() => _goTo((_index + 1) % _puzzles.length);
  void _prev() {
    if (_index > 0) _goTo(_index - 1);
  }

  // ── Move handling ─────────────────────────────────────────────────────────────

  void _onUserMove() {
    if (_outcome != _PuzzleOutcome.pending) return;
    final sanList = _boardCtrl.getSan();
    if (sanList.isEmpty) return;
    final moveSan = sanList.last;
    if (moveSan == null) return;
    _validateMove(moveSan);
  }

  void _validateMove(String moveSan) {
    final puzzle = _puzzles[_index];
    final bestMove = puzzle.mistake.bestMove;

    final bool isCorrect;
    if (bestMove != null && bestMove.isNotEmpty) {
      // Exact best move is known — only accept that
      isCorrect = moveSan == bestMove;
    } else {
      // No stored best move: any legal move other than the mistake is fine
      isCorrect = moveSan != puzzle.mistake.move;
    }

    if (isCorrect) {
      _handleCorrect();
    } else {
      _handleWrong();
    }
  }

  void _handleCorrect() {
    setState(() => _outcome = _PuzzleOutcome.solved);
    _advanceTimer = Timer(const Duration(milliseconds: 1500), () {
      if (mounted) _next();
    });
  }

  void _handleWrong() {
    _boardCtrl.undoMove();
    setState(() => _attempts++);
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.close_rounded, color: Colors.white, size: 16),
            const SizedBox(width: 8),
            Text(_attempts == 1
                ? 'Not quite — try again!'
                : 'Not quite — try again! ($_attempts attempts)'),
          ],
        ),
        backgroundColor: kIsWeb ? WT.blunderColor : AppTheme.blunder,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _reveal() {
    final puzzle = _puzzles[_index];
    final bestMove = puzzle.mistake.bestMove;
    if (bestMove != null && bestMove.isNotEmpty) {
      try {
        _boardCtrl.makeMoveWithNormalNotation(bestMove);
      } catch (_) {}
    }
    setState(() => _outcome = _PuzzleOutcome.revealed);
  }

  // ── Helpers ───────────────────────────────────────────────────────────────────

  bool get _isWhiteTurn {
    if (_puzzles.isEmpty || _index >= _puzzles.length) return true;
    final parts = _puzzles[_index].fenBeforeMistake.split(' ');
    return parts.length > 1 ? parts[1] == 'w' : true;
  }

  // ── Build ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final web = kIsWeb;
    return Scaffold(
      backgroundColor: web ? WT.scaffoldBg : null,
      appBar: web
          ? webAppBar(context, title: 'Study Mode', actions: [
              PopupMenuButton<String>(
                icon: const Icon(Icons.filter_list_rounded, color: WT.silver),
                onSelected: (v) {
                  setState(() => _filter = v);
                  _loadPuzzles();
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'blunder', child: Text('Blunders only')),
                  PopupMenuItem(value: 'mistake', child: Text('Mistakes only')),
                  PopupMenuItem(value: 'both', child: Text('Blunders + Mistakes')),
                ],
              ),
            ])
          : AppBar(
              title: const Text('Study Mode'),
              actions: [
                PopupMenuButton<String>(
                  icon: const Icon(Icons.filter_list_rounded),
                  onSelected: (v) {
                    setState(() => _filter = v);
                    _loadPuzzles();
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'blunder', child: Text('Blunders only')),
                    PopupMenuItem(value: 'mistake', child: Text('Mistakes only')),
                    PopupMenuItem(
                        value: 'both', child: Text('Blunders + Mistakes')),
                  ],
                ),
              ],
            ),
      body: _loading
          ? Center(
              child: CircularProgressIndicator(
                  color: web ? WT.greenAccent : AppTheme.primary))
          : _puzzles.isEmpty
              ? _emptyState()
              : _puzzleView(),
    );
  }

  Widget _puzzleView() {
    final web = kIsWeb;
    final puzzle = _puzzles[_index];
    final isBlunder = puzzle.mistake.quality == 'blunder';
    final qualityColor = web
        ? (isBlunder ? WT.blunderColor : WT.mistakeColor)
        : (isBlunder ? AppTheme.blunder : AppTheme.mistake);
    final screenWidth = MediaQuery.of(context).size.width;

    // Web: cap at 480 px and center; Android: full width
    final boardSize =
        web ? (screenWidth - 48).clamp(0.0, 480.0) : screenWidth;

    final orientation = puzzle.game.playerColor == 'black'
        ? PlayerColor.black
        : PlayerColor.white;

    final isInteractive = _outcome == _PuzzleOutcome.pending;
    final whiteTurn = _isWhiteTurn;

    // ── Reusable sub-widgets ────────────────────────────────────────────────

    final progressBar = LinearProgressIndicator(
      value: (_index + 1) / _puzzles.length,
      backgroundColor: web ? WT.altBg : AppTheme.surfaceAlt,
      color: web ? WT.greenAccent : AppTheme.primary,
    );

    final contextBanner = Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: qualityColor.withValues(alpha: 0.10),
      child: Row(
        children: [
          Icon(
              isBlunder ? Icons.cancel_rounded : Icons.warning_rounded,
              color: qualityColor,
              size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Move ${puzzle.mistake.moveNumber} was a ${puzzle.mistake.quality}'
              ' vs ${puzzle.game.opponentName.isEmpty ? "Unknown" : puzzle.game.opponentName}.'
              ' What should have been played?',
              style: TextStyle(color: qualityColor, fontSize: 13),
            ),
          ),
        ],
      ),
    );

    final board = ChessBoard(
      controller: _boardCtrl,
      size: boardSize,
      enableUserMoves: isInteractive,
      boardColor: BoardColor.brown,
      boardOrientation: orientation,
      onMove: _onUserMove,
    );

    final turnIndicator = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: whiteTurn ? Colors.white : const Color(0xFF2D2D2D),
              border: Border.all(
                color: web ? WT.borderColor : AppTheme.surfaceAlt,
                width: 1.5,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            whiteTurn ? 'White to move' : 'Black to move',
            style: TextStyle(
              color: web ? WT.mutedColor : AppTheme.textSecondary,
              fontSize: 12,
            ),
          ),
          const Spacer(),
          if (_attempts > 0)
            Text(
              '$_attempts attempt${_attempts == 1 ? '' : 's'}',
              style: TextStyle(
                color: web ? WT.mistakeColor : AppTheme.mistake,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
        ],
      ),
    );

    final puzzleCounter = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Text(
            'Puzzle ${_index + 1} of ${_puzzles.length}',
            style: TextStyle(
                color: web ? WT.mutedColor : AppTheme.textSecondary,
                fontSize: 12),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: qualityColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              puzzle.mistake.quality.toUpperCase(),
              style: TextStyle(
                  color: qualityColor,
                  fontSize: 11,
                  fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    // Status area: success banner, revealed explanation, or reveal button
    Widget statusArea;
    if (_outcome == _PuzzleOutcome.solved) {
      final successColor = web ? WT.winColor : AppTheme.goodMove;
      statusArea = Container(
        width: double.infinity,
        margin: web
            ? EdgeInsets.zero
            : const EdgeInsets.fromLTRB(16, 4, 16, 0),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        color: successColor.withValues(alpha: 0.12),
        child: Row(
          children: [
            Icon(Icons.check_circle_rounded, color: successColor, size: 18),
            const SizedBox(width: 8),
            Text(
              'Correct! Moving to next puzzle…',
              style: TextStyle(
                  color: successColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 13),
            ),
          ],
        ),
      );
    } else if (_outcome == _PuzzleOutcome.revealed) {
      statusArea = Container(
        width: double.infinity,
        margin: web
            ? EdgeInsets.zero
            : const EdgeInsets.fromLTRB(16, 4, 16, 0),
        padding: const EdgeInsets.all(14),
        decoration: web
            ? BoxDecoration(
                color: WT.cardBg,
                border:
                    Border(left: BorderSide(color: qualityColor, width: 3)),
                boxShadow: const [
                  BoxShadow(
                      color: Color(0x06000000),
                      blurRadius: 5,
                      offset: Offset(0, 2))
                ],
              )
            : BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: qualityColor.withValues(alpha: 0.3)),
              ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Played: ${puzzle.mistake.move}',
                  style: TextStyle(
                    color: qualityColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    fontFamily: 'monospace',
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: qualityColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(puzzle.mistake.quality,
                      style: TextStyle(
                          color: qualityColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            if (puzzle.mistake.comment != null) ...[
              const SizedBox(height: 8),
              Text(
                puzzle.mistake.comment!,
                style: TextStyle(
                  color: web ? WT.mutedColor : AppTheme.textSecondary,
                  fontSize: 13,
                ),
              ),
            ],
          ],
        ),
      );
    } else {
      // pending — show Reveal button
      statusArea = Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
        child: OutlinedButton.icon(
          onPressed: _reveal,
          icon: const Icon(Icons.visibility_rounded, size: 16),
          label: const Text('Reveal Answer'),
          style: OutlinedButton.styleFrom(
            foregroundColor: web ? WT.mutedColor : AppTheme.textSecondary,
            side: BorderSide(color: web ? WT.borderColor : AppTheme.surfaceAlt),
            minimumSize: const Size(double.infinity, 44),
          ),
        ),
      );
    }

    final navRow = Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _index > 0 ? _prev : null,
              icon: const Icon(Icons.navigate_before_rounded),
              label: const Text('Previous'),
              style: OutlinedButton.styleFrom(
                foregroundColor: web ? WT.mutedColor : AppTheme.textSecondary,
                side: BorderSide(color: web ? WT.borderColor : AppTheme.surfaceAlt),
                minimumSize: const Size(0, 46),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _next,
              icon: const Icon(Icons.navigate_next_rounded),
              label: Text(
                  _index + 1 >= _puzzles.length ? 'Restart' : 'Next'),
              style: ElevatedButton.styleFrom(
                backgroundColor: web ? WT.greenAccent : null,
                foregroundColor: web ? Colors.white : null,
                minimumSize: const Size(0, 46),
              ),
            ),
          ),
        ],
      ),
    );

    // ── Web layout ────────────────────────────────────────────────────────────
    if (web) {
      return SingleChildScrollView(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  progressBar,
                  const SizedBox(height: 12),
                  contextBanner,
                  const SizedBox(height: 12),
                  // SizedBox prevents CrossAxisAlignment.stretch from passing a wider-than-board constraint to ChessBoard, which caused top/bottom rank clipping on web.
              LayoutBuilder(
                builder: (_, constraints) {
                  final bSize = constraints.maxWidth.clamp(0.0, 480.0);
                  return Center(
                    child: SizedBox(
                      width: bSize,
                      height: bSize,
                      child: ChessBoard(
                        controller: _boardCtrl,
                        size: bSize,
                        enableUserMoves: isInteractive,
                        boardColor: BoardColor.brown,
                        boardOrientation: orientation,
                        onMove: _onUserMove,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 4),
              turnIndicator,
                  puzzleCounter,
                  const SizedBox(height: 8),
                  statusArea,
                  const SizedBox(height: 12),
                  navRow,
                ],
              ),
            ),
          ),
        ),
      );
    }

    // ── Android layout ────────────────────────────────────────────────────────
    return Column(
      children: [
        progressBar,
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              children: [
                contextBanner,
                board,
                turnIndicator,
                puzzleCounter,
                const SizedBox(height: 4),
                statusArea,
                navRow,
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _emptyState() {
    final web = kIsWeb;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('🎯', style: TextStyle(fontSize: 56)),
          const SizedBox(height: 16),
          Text(
            'No puzzles yet',
            style: web
                ? WT.lora(20, color: WT.textColor, weight: FontWeight.bold)
                : const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Analyse some games first to generate\npuzzles from your mistakes',
            textAlign: TextAlign.center,
            style: web
                ? WT.bodySm(14)
                : const TextStyle(color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              setState(() => _filter = 'both');
              _loadPuzzles();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: web ? WT.greenLt : null,
              foregroundColor: web ? Colors.white : null,
            ),
            child: const Text('Try all mistakes'),
          ),
        ],
      ),
    );
  }
}
