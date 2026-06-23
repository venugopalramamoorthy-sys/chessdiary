import 'package:flutter/material.dart';
import 'package:flutter_chess_board/flutter_chess_board.dart';
import '../models/game_model.dart';
import '../services/game_service.dart';
import '../utils/theme.dart';

class _Puzzle {
  final ChessGame game;
  final MoveAnalysis mistake;
  final int halfMoveIndex; // position BEFORE the mistake
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
  bool _revealed = false;
  String _filter = 'blunder'; // 'blunder', 'mistake', 'both'
  final ChessBoardController _boardCtrl = ChessBoardController();

  @override
  void initState() {
    super.initState();
    _loadPuzzles();
  }

  Future<void> _loadPuzzles() async {
    setState(() { _loading = true; _puzzles = []; });
    final games = await GameService.getAllGames();
    final puzzles = <_Puzzle>[];

    for (final g in games) {
      if (g.analysis.isEmpty || g.moves.isEmpty) continue;
      for (final a in g.analysis) {
        if (_filter == 'blunder' && a.quality != 'blunder') continue;
        if (_filter == 'mistake' && a.quality != 'mistake') continue;
        if (_filter == 'both' && a.quality != 'blunder' && a.quality != 'mistake') continue;

        // Reconstruct FEN before the mistake move
        // moveNumber in analysis = chess move number (1-based full moves)
        // halfMoveIndex = (moveNumber - 1) * 2 + (black move? 1 : 0)
        // We need to figure out whose move it was
        // The mistake move index in the moves list:
        // We try to find it by matching move text
        final moveSan = a.move;
        // Find this move in the game moves
        int halfIdx = -1;
        for (int i = 0; i < g.moves.length; i++) {
          if (g.moves[i] == moveSan) {
            // Rough check: move number should match
            final expectedMoveNum = (i ~/ 2) + 1;
            if (expectedMoveNum == a.moveNumber) {
              halfIdx = i;
              break;
            }
          }
        }
        if (halfIdx < 0) continue;

        // Rebuild FEN up to just before mistake
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

    // Shuffle
    puzzles.shuffle();

    setState(() {
      _puzzles = puzzles;
      _index = 0;
      _loading = false;
      _revealed = false;
    });
    if (puzzles.isNotEmpty) _loadPuzzle(0);
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

  void _loadPuzzle(int idx) {
    if (idx >= _puzzles.length) return;
    _boardCtrl.loadFen(_puzzles[idx].fenBeforeMistake);
    setState(() { _revealed = false; });
  }

  void _reveal() => setState(() => _revealed = true);

  void _next() {
    if (_index + 1 >= _puzzles.length) {
      setState(() => _index = 0);
    } else {
      setState(() => _index++);
    }
    _loadPuzzle(_index);
  }

  void _prev() {
    if (_index > 0) setState(() => _index--);
    _loadPuzzle(_index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Study Mode'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list_rounded),
            onSelected: (v) { setState(() => _filter = v); _loadPuzzles(); },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'blunder', child: Text('Blunders only')),
              PopupMenuItem(value: 'mistake', child: Text('Mistakes only')),
              PopupMenuItem(value: 'both', child: Text('Blunders + Mistakes')),
            ],
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : _puzzles.isEmpty
              ? _emptyState()
              : _puzzleView(),
    );
  }

  Widget _puzzleView() {
    final puzzle = _puzzles[_index];
    final isBlunder = puzzle.mistake.quality == 'blunder';
    final qualityColor = isBlunder ? AppTheme.blunder : AppTheme.mistake;
    final boardSize = MediaQuery.of(context).size.width;

    // Determine orientation: show from player's perspective
    final orientation = puzzle.game.playerColor == 'black'
        ? PlayerColor.black
        : PlayerColor.white;

    return Column(
      children: [
        // Progress bar
        LinearProgressIndicator(
          value: (_index + 1) / _puzzles.length,
          backgroundColor: AppTheme.surfaceAlt,
          color: AppTheme.primary,
        ),

        Expanded(
          child: SingleChildScrollView(
            child: Column(
              children: [
                // Context banner
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  color: qualityColor.withOpacity(0.12),
                  child: Row(
                    children: [
                      Icon(isBlunder ? Icons.cancel_rounded : Icons.warning_rounded,
                          color: qualityColor, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Move ${puzzle.mistake.moveNumber} was a ${puzzle.mistake.quality} in a game vs ${puzzle.game.opponentName.isEmpty ? "Unknown" : puzzle.game.opponentName}. What should have been played?',
                          style: TextStyle(color: qualityColor, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),

                // Board
                ChessBoard(
                  controller: _boardCtrl,
                  size: boardSize,
                  enableUserMoves: false,
                  boardColor: BoardColor.brown,
                  boardOrientation: orientation,
                ),

                // Puzzle number
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      Text(
                        'Puzzle ${_index + 1} of ${_puzzles.length}',
                        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: qualityColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          puzzle.mistake.quality.toUpperCase(),
                          style: TextStyle(color: qualityColor, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),

                // Reveal / answer
                if (!_revealed)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: ElevatedButton.icon(
                      onPressed: _reveal,
                      icon: const Icon(Icons.visibility_rounded),
                      label: const Text('Reveal Answer'),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 48),
                      ),
                    ),
                  )
                else ...[
                  // Show the mistake and engine comment
                  Container(
                    margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: qualityColor.withOpacity(0.4)),
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
                                  fontSize: 15,
                                  fontFamily: 'monospace'),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: qualityColor.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(puzzle.mistake.quality,
                                  style: TextStyle(color: qualityColor, fontSize: 11, fontWeight: FontWeight.w600)),
                            ),
                          ],
                        ),
                        if (puzzle.mistake.comment != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            puzzle.mistake.comment!,
                            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],

                // Navigation
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _index > 0 ? _prev : null,
                          icon: const Icon(Icons.navigate_before_rounded),
                          label: const Text('Previous'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.textSecondary,
                            side: const BorderSide(color: AppTheme.surfaceAlt),
                            minimumSize: const Size(0, 46),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _next,
                          icon: const Icon(Icons.navigate_next_rounded),
                          label: Text(_index + 1 >= _puzzles.length ? 'Restart' : 'Next'),
                          style: ElevatedButton.styleFrom(minimumSize: const Size(0, 46)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('🎯', style: TextStyle(fontSize: 56)),
          const SizedBox(height: 16),
          const Text('No puzzles yet',
              style: TextStyle(color: AppTheme.textPrimary, fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Analyse some games first to generate\npuzzles from your mistakes',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textSecondary)),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () { setState(() => _filter = 'both'); _loadPuzzles(); },
            child: const Text('Try all mistakes'),
          ),
        ],
      ),
    );
  }
}
