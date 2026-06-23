// lib/screens/game_detail_screen.dart

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_chess_board/flutter_chess_board.dart' show BoardColor, ChessBoard, ChessBoardController, PlayerColor;
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../models/game_model.dart';
import '../services/game_service.dart';
import '../services/gemini_service.dart';
import '../services/pgn_export_service.dart';
import '../services/stockfish_service.dart';
import '../utils/theme.dart';

class _H2H {
  final int wins, losses, draws;
  _H2H(this.wins, this.losses, this.draws);
  int get total => wins + losses + draws;
}

class GameDetailScreen extends StatefulWidget {
  final ChessGame game;

  const GameDetailScreen({super.key, required this.game});

  @override
  State<GameDetailScreen> createState() => _GameDetailScreenState();
}

class _GameDetailScreenState extends State<GameDetailScreen> with SingleTickerProviderStateMixin {
  late TabController _tabs;
  late ChessGame _game;
  bool _analyzing = false;
  _H2H? _h2h;

  // Board replay
  final ChessBoardController _boardCtrl = ChessBoardController();
  int _replayIndex = 0; // current half-move index (0 = start)
  List<String> _replayMoves = [];

  @override
  void initState() {
    super.initState();
    _game = widget.game;
    _tabs = TabController(length: 3, vsync: this);
    _loadH2H();
    _initReplay();
  }

  void _initReplay() {
    _replayMoves = List<String>.from(_game.moves);
    _replayIndex = 0;
    _boardCtrl.resetBoard();
  }

  void _replayStep(int delta) {
    final target = (_replayIndex + delta).clamp(0, _replayMoves.length);
    if (target == _replayIndex) return;
    if (target > _replayIndex) {
      for (int i = _replayIndex; i < target; i++) {
        try { _boardCtrl.makeMoveWithNormalNotation(_replayMoves[i]); } catch (_) {}
      }
    } else {
      _boardCtrl.resetBoard();
      for (int i = 0; i < target; i++) {
        try { _boardCtrl.makeMoveWithNormalNotation(_replayMoves[i]); } catch (_) {}
      }
    }
    setState(() => _replayIndex = target);
  }

  Future<void> _loadH2H() async {
    final opp = _game.opponentName.trim().toLowerCase();
    if (opp.isEmpty || opp == 'unknown') return;
    final all = await GameService.getAllGames();
    final h2hGames = all.where((g) =>
        g.opponentName.trim().toLowerCase() == opp && g.id != _game.id).toList();
    if (h2hGames.isEmpty) return;
    int w = 0, l = 0, d = 0;
    for (final g in h2hGames) {
      final r = g.resultDisplay;
      if (r == 'Win') w++;
      else if (r == 'Loss') l++;
      else d++;
    }
    // include current game
    final curR = _game.resultDisplay;
    if (curR == 'Win') w++;
    else if (curR == 'Loss') l++;
    else d++;
    if (mounted) setState(() => _h2h = _H2H(w, l, d));
  }

  @override
  Widget build(BuildContext context) {
    final result = _game.resultDisplay;
    final resultColor = AppTheme.resultColor(result);

    return Scaffold(
      appBar: AppBar(
        title: Text('vs ${_game.opponentName.isEmpty ? "Unknown" : _game.opponentName}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_rounded),
            tooltip: 'Export PGN',
            onPressed: _exportPgn,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded),
            onPressed: _deleteGame,
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          labelColor: AppTheme.primary,
          unselectedLabelColor: AppTheme.textSecondary,
          indicatorColor: AppTheme.primary,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Analysis'),
            Tab(text: 'Replay'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _overviewTab(result, resultColor),
          _analysisTab(),
          _replayTab(),
        ],
      ),
    );
  }

  Widget _overviewTab(String result, Color resultColor) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Result hero
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [resultColor.withOpacity(0.3), resultColor.withOpacity(0.05)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: resultColor.withOpacity(0.4)),
            ),
            child: Column(
              children: [
                Text(
                  result == 'Win' ? '🏆' : result == 'Loss' ? '😞' : '🤝',
                  style: const TextStyle(fontSize: 48),
                ),
                const SizedBox(height: 8),
                Text(
                  result.toUpperCase(),
                  style: TextStyle(
                    color: resultColor,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _game.result,
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 16),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Info grid
          _infoGrid(),

          // Head-to-head
          if (_h2h != null && _h2h!.total > 1) ...[
            const SizedBox(height: 20),
            _h2hCard(),
          ],

          const SizedBox(height: 20),

          // Notes & Tags
          if (_game.notes != null && _game.notes!.isNotEmpty) ...[
            _notesCard(),
            const SizedBox(height: 12),
          ],
          if (_game.tags.isNotEmpty) ...[
            _tagsRow(),
            const SizedBox(height: 12),
          ],
          // Edit notes/tags button
          OutlinedButton.icon(
            onPressed: _editNotesAndTags,
            icon: const Icon(Icons.edit_note_rounded, size: 18),
            label: Text(_game.notes == null && _game.tags.isEmpty
                ? 'Add notes / tags'
                : 'Edit notes / tags'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.textSecondary,
              side: const BorderSide(color: AppTheme.surfaceAlt),
            ),
          ),

          const SizedBox(height: 20),

          // Moves list
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Moves', style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                )),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: [
                    for (int i = 0; i < _game.moves.length; i++)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceAlt,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          i % 2 == 0
                              ? '${i ~/ 2 + 1}. ${_game.moves[i]}'
                              : _game.moves[i],
                          style: TextStyle(
                            color: i % 2 == 0 ? AppTheme.textPrimary : AppTheme.textSecondary,
                            fontSize: 12,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoGrid() {
    final items = [
      ('Date', DateFormat('d MMM yyyy').format(_game.datePlayed), Icons.calendar_today_rounded),
      ('Source', _game.source, Icons.source_rounded),
      ('Played as', _game.playerColor, Icons.person_rounded),
      ('Total Moves', '${_game.totalMoves}', Icons.format_list_numbered_rounded),
      if (_game.opening != null) ('Opening', _game.opening!, Icons.book_rounded),
      if (_game.event != null) ('Event', _game.event!, Icons.emoji_events_rounded),
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 2.4,
      children: items.map((item) {
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                children: [
                  Icon(item.$3, size: 13, color: AppTheme.textSecondary),
                  const SizedBox(width: 4),
                  Text(item.$1, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                item.$2,
                style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _analysisTab() {
    if (_game.analysis.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('🔍', style: TextStyle(fontSize: 56)),
              const SizedBox(height: 16),
              const Text(
                'No Analysis Yet',
                style: TextStyle(color: AppTheme.textPrimary, fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Analyse this game with Stockfish engine for centipawn-accurate move quality, blunders, and mistakes.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _analyzing ? null : _analyzeGame,
                icon: _analyzing
                    ? const SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.auto_awesome_rounded),
                label: Text(_analyzing ? 'Analysing...' : 'Analyse with AI'),
              ),
            ],
          ),
        ),
      );
    }

    // Blunder/mistake counts
    final blunders = _game.analysis.where((a) => a.quality == 'blunder').length;
    final mistakes = _game.analysis.where((a) => a.quality == 'mistake').length;
    final inaccuracies = _game.analysis.where((a) => a.quality == 'inaccuracy').length;
    final good = _game.analysis.where((a) => a.quality == 'good' || a.quality == 'best').length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Summary row
          Row(
            children: [
              _statBubble('$good', 'Good', AppTheme.goodMove),
              _statBubble('$inaccuracies', 'Inaccuracy', AppTheme.inaccuracy),
              _statBubble('$mistakes', 'Mistakes', AppTheme.mistake),
              _statBubble('$blunders', 'Blunders', AppTheme.blunder),
            ],
          ),
          const SizedBox(height: 16),

          // Eval curve chart
          if (_game.evalCurve.isNotEmpty) ...[
            _evalCurveCard(),
            const SizedBox(height: 16),
          ],

          // Turning points (from eval curve)
          ..._turningPoints().map((tp) => _turningPointTile(tp)),
          if (_turningPoints().isNotEmpty) const SizedBox(height: 8),

          // Move-by-move
          ..._game.analysis.map((a) => _analysisTile(a)),
        ],
      ),
    );
  }

  Widget _statBubble(String count, String label, Color color) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Text(count, style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.bold)),
            Text(label, style: TextStyle(color: color.withOpacity(0.8), fontSize: 10)),
          ],
        ),
      ),
    );
  }

  // ── Eval curve chart ─────────────────────────────────────────────────────

  Widget _evalCurveCard() {
    final curve = _game.evalCurve;
    if (curve.isEmpty) return const SizedBox();

    final isPlayerWhite = _game.playerColor == 'white';
    final spots = curve.asMap().entries.map((e) {
      // Flip if player is black so positive = player is winning
      final val = isPlayerWhite ? e.value.toDouble() : -e.value.toDouble();
      return FlSpot(e.key.toDouble(), val.clamp(-800, 800));
    }).toList();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Evaluation',
              style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 14)),
          const SizedBox(height: 4),
          const Text('Positive = you\'re winning',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 10)),
          const SizedBox(height: 12),
          SizedBox(
            height: 100,
            child: LineChart(LineChartData(
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                getDrawingHorizontalLine: (v) => FlLine(
                  color: v == 0 ? AppTheme.textSecondary.withOpacity(0.5) : AppTheme.surfaceAlt,
                  strokeWidth: v == 0 ? 1.5 : 0.5,
                ),
                horizontalInterval: 200,
              ),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              borderData: FlBorderData(show: false),
              minY: -800,
              maxY: 800,
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  color: AppTheme.primary,
                  barWidth: 2,
                  dotData: FlDotData(show: false),
                  belowBarData: BarAreaData(
                    show: true,
                    color: AppTheme.primary.withOpacity(0.08),
                  ),
                ),
              ],
            )),
          ),
        ],
      ),
    );
  }

  // ── Turning points ────────────────────────────────────────────────────────

  // A turning point is where the eval swings ≥150cp against the player
  // over a 3-half-move window, without a single flagged blunder in that window
  List<Map<String, dynamic>> _turningPoints() {
    final curve = _game.evalCurve;
    if (curve.length < 6) return [];

    final isPlayerWhite = _game.playerColor == 'white';
    final blunderMoves = _game.analysis
        .where((a) => a.quality == 'blunder' || a.quality == 'mistake')
        .map((a) => a.moveNumber)
        .toSet();

    final points = <Map<String, dynamic>>[];
    const window = 6; // 3 full moves = 6 half-moves
    const threshold = 150;

    for (int i = 0; i + window < curve.length; i++) {
      final before = isPlayerWhite ? curve[i].toDouble() : -curve[i].toDouble();
      final after = isPlayerWhite ? curve[i + window].toDouble() : -curve[i + window].toDouble();
      final swing = before - after; // positive = things got worse for player

      if (swing >= threshold) {
        final moveNum = i ~/ 2 + 1;
        // Skip if there's a flagged blunder in this window (already shown)
        final hasFlaggedMove = blunderMoves.any((m) => m >= moveNum && m <= moveNum + 3);
        if (!hasFlaggedMove) {
          points.add({
            'moveStart': moveNum,
            'moveEnd': moveNum + 3,
            'swing': swing.toInt(),
          });
          // Skip ahead to avoid overlapping windows
          break; // show max 1 turning point per analysis for brevity
        }
      }
    }
    return points;
  }

  Widget _turningPointTile(Map<String, dynamic> tp) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.secondary.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppTheme.secondary.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Center(child: Text('⚠️', style: TextStyle(fontSize: 18))),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Critical Moment — Moves ${tp['moveStart']}–${tp['moveEnd']}',
                  style: const TextStyle(color: AppTheme.secondary, fontWeight: FontWeight.w600, fontSize: 13),
                ),
                const SizedBox(height: 2),
                Text(
                  'Position drifted ${tp['swing']} centipawns against you across these moves — no single blunder, but a gradual slide.',
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _analysisTile(MoveAnalysis a) {
    final color = AppTheme.qualityColor(a.quality);
    final icon = AppTheme.qualityIcon(a.quality);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Move ${a.moveNumber}: ${a.move}',
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        fontFamily: 'monospace',
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        a.quality,
                        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
                // Phase, motif, time-pressure badges
                const SizedBox(height: 4),
                Row(
                  children: [
                    _phaseBadge(a.phase),
                    if (a.motif != null) ...[
                      const SizedBox(width: 6),
                      _motifBadge(a.motif!),
                    ],
                    if (a.timePressure) ...[
                      const SizedBox(width: 6),
                      _timePressureBadge(),
                    ],
                  ],
                ),
                if (a.comment != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    a.comment!,
                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Time pressure ────────────────────────────────────────────────────────

  /// Attaches timePressure=true to mistakes/blunders made with < 30s on clock.
  /// The clock list has one value per half-move (0 = white's first move).
  /// We check BOTH the player's half-move and the move before (since we don't
  /// always know which color made each flagged move from analysis alone).
  List<MoveAnalysis> _attachTimePressure(List<MoveAnalysis> analysis, List<int> clocks) {
    final isWhitePlayer = _game.playerColor == 'white';
    return analysis.map((a) {
      if (a.quality != 'blunder' && a.quality != 'mistake') return a;
      // Determine half-move index for this move number
      // White's move at full-move N → half-move (N-1)*2
      // Black's move at full-move N → half-move (N-1)*2 + 1
      final whiteIdx = (a.moveNumber - 1) * 2;
      final blackIdx = whiteIdx + 1;
      // Check the player's half-move index
      final playerIdx = isWhitePlayer ? whiteIdx : blackIdx;
      if (playerIdx >= clocks.length) return a;
      final secs = clocks[playerIdx];
      if (secs < 30) {
        return MoveAnalysis(
          moveNumber: a.moveNumber,
          move: a.move,
          quality: a.quality,
          comment: a.comment,
          centipawnLoss: a.centipawnLoss,
          motif: a.motif,
          timePressure: true,
        );
      }
      return a;
    }).toList();
  }

  Widget _phaseBadge(String phase) {
    final color = phase == 'opening'
        ? const Color(0xFF4FC3F7)
        : phase == 'middlegame'
            ? AppTheme.secondary
            : const Color(0xFFE57373);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(phase, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600)),
    );
  }

  Widget _timePressureBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppTheme.mistake.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppTheme.mistake.withOpacity(0.3)),
      ),
      child: const Text('⏰ <30s', style: TextStyle(color: AppTheme.mistake, fontSize: 10, fontWeight: FontWeight.w600)),
    );
  }

  Widget _motifBadge(String motif) {
    final label = motif.replaceAll('_', ' ');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppTheme.blunder.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppTheme.blunder.withOpacity(0.3)),
      ),
      child: Text(label, style: const TextStyle(color: AppTheme.blunder, fontSize: 10, fontWeight: FontWeight.w600)),
    );
  }

  Future<void> _analyzeGame() async {
    if (_game.pgn.isEmpty && _game.moves.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No moves to analyse'),
          backgroundColor: AppTheme.loss,
        ),
      );
      return;
    }

    setState(() => _analyzing = true);

    try {
      final pgn = _game.pgn.isNotEmpty ? _game.pgn : _game.moves.join(' ');

      List<MoveAnalysis> analysis;
      List<int> evalCurve = [];
      String engineUsed = 'Stockfish';
      try {
        final result = await StockfishService.analyzeGame(pgn);
        analysis = result.analysis;
        evalCurve = result.evalCurve;
        // Tag tactical motifs using Gemini (best-effort, non-blocking)
        analysis = await GeminiService.tagMotifs(pgn, analysis);
      } catch (_) {
        engineUsed = 'Gemini AI';
        analysis = await GeminiService.analyzeGame(pgn);
      }

      // Attach time-pressure flag from stored clock data
      if (_game.clockSeconds.isNotEmpty) {
        analysis = _attachTimePressure(analysis, _game.clockSeconds);
      }

      final updated = _game.copyWith(analysis: analysis, evalCurve: evalCurve);

      await GameService.updateGame(_game.id, updated);

      setState(() {
        _game = updated;
        _analyzing = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Analysis complete ($engineUsed)'),
          backgroundColor: AppTheme.primary,
        ));
      }
    } catch (e) {
      setState(() => _analyzing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Analysis failed: $e'), backgroundColor: AppTheme.loss),
        );
      }
    }
  }

  // ── Board Replay tab ─────────────────────────────────────────────────────

  Widget _replayTab() {
    if (_replayMoves.isEmpty) {
      return const Center(
        child: Text('No moves to replay',
            style: TextStyle(color: AppTheme.textSecondary)),
      );
    }

    final boardSize = MediaQuery.of(context).size.width;
    final orientation = _game.playerColor == 'black'
        ? PlayerColor.black
        : PlayerColor.white;

    // Current move label
    String moveLabel = 'Start';
    if (_replayIndex > 0) {
      final moveNum = ((_replayIndex - 1) ~/ 2) + 1;
      final isWhite = (_replayIndex - 1) % 2 == 0;
      moveLabel = '$moveNum. ${isWhite ? "" : "..."}${_replayMoves[_replayIndex - 1]}';
    }

    // Quality of current move (if analysis exists)
    MoveAnalysis? currentAnalysis;
    if (_game.analysis.isNotEmpty && _replayIndex > 0) {
      final moveNum = ((_replayIndex - 1) ~/ 2) + 1;
      try {
        currentAnalysis = _game.analysis.firstWhere(
          (a) => a.moveNumber == moveNum,
          orElse: () => _game.analysis.first,
        );
      } catch (_) {}
    }

    return Column(
      children: [
        // Board
        ChessBoard(
          controller: _boardCtrl,
          size: boardSize,
          enableUserMoves: false,
          boardColor: BoardColor.brown,
          boardOrientation: orientation,
        ),

        // Move info bar
        Container(
          color: AppTheme.surface,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Text(
                moveLabel,
                style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    fontFamily: 'monospace'),
              ),
              if (currentAnalysis != null) ...[
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.qualityColor(currentAnalysis.quality).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    currentAnalysis.quality,
                    style: TextStyle(
                        color: AppTheme.qualityColor(currentAnalysis.quality),
                        fontSize: 11,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ],
              const Spacer(),
              Text(
                '$_replayIndex / ${_replayMoves.length}',
                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
              ),
            ],
          ),
        ),

        // Comment if available
        if (currentAnalysis?.comment != null)
          Container(
            width: double.infinity,
            color: AppTheme.surfaceAlt,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              currentAnalysis!.comment!,
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
            ),
          ),

        // Navigation controls
        Container(
          color: AppTheme.background,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _navBtn(Icons.first_page_rounded, () => _replayStep(-_replayMoves.length)),
              const SizedBox(width: 8),
              _navBtn(Icons.navigate_before_rounded, () => _replayStep(-1)),
              const SizedBox(width: 8),
              _navBtn(Icons.navigate_next_rounded, () => _replayStep(1)),
              const SizedBox(width: 8),
              _navBtn(Icons.last_page_rounded, () => _replayStep(_replayMoves.length)),
            ],
          ),
        ),

        // Move list scroll
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            scrollDirection: Axis.horizontal,
            itemCount: (_replayMoves.length / 2).ceil(),
            itemBuilder: (_, i) {
              final whiteIdx = i * 2;
              final blackIdx = whiteIdx + 1;
              return Row(
                children: [
                  Container(
                    margin: const EdgeInsets.only(right: 2),
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                    child: Text('${i + 1}.',
                        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                  ),
                  _movePill(whiteIdx),
                  if (blackIdx < _replayMoves.length) _movePill(blackIdx),
                  const SizedBox(width: 4),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _navBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(icon, color: AppTheme.textPrimary, size: 28),
      ),
    );
  }

  Widget _movePill(int halfMoveIdx) {
    final isActive = halfMoveIdx + 1 == _replayIndex;
    final move = _replayMoves[halfMoveIdx];
    return GestureDetector(
      onTap: () => _replayStep(halfMoveIdx + 1 - _replayIndex),
      child: Container(
        margin: const EdgeInsets.only(right: 2),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? AppTheme.primary : AppTheme.surfaceAlt,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          move,
          style: TextStyle(
            color: isActive ? Colors.white : AppTheme.textPrimary,
            fontSize: 12,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            fontFamily: 'monospace',
          ),
        ),
      ),
    );
  }

  // ── Head-to-head ─────────────────────────────────────────────────────────

  Widget _h2hCard() {
    final h = _h2h!;
    final opp = _game.opponentName;
    final winRate = h.total == 0 ? 0.0 : h.wins / h.total;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.people_rounded, color: AppTheme.textSecondary, size: 16),
              const SizedBox(width: 6),
              Text(
                'vs $opp — ${h.total} game${h.total == 1 ? '' : 's'}',
                style: const TextStyle(
                    color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 13),
              ),
              const Spacer(),
              Text(
                '${(winRate * 100).toStringAsFixed(0)}% win',
                style: TextStyle(
                  color: winRate >= 0.5 ? AppTheme.win : AppTheme.loss,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _h2hBadge('${h.wins} W', AppTheme.win),
              const SizedBox(width: 6),
              _h2hBadge('${h.losses} L', AppTheme.loss),
              const SizedBox(width: 6),
              _h2hBadge('${h.draws} D', AppTheme.draw),
            ],
          ),
          const SizedBox(height: 8),
          if (h.total > 0)
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Row(
                children: [
                  if (h.wins > 0) Flexible(flex: h.wins, child: Container(height: 6, color: AppTheme.win)),
                  if (h.losses > 0) Flexible(flex: h.losses, child: Container(height: 6, color: AppTheme.loss)),
                  if (h.draws > 0) Flexible(flex: h.draws, child: Container(height: 6, color: AppTheme.draw)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _h2hBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }

  // ── Notes/Tags widgets ────────────────────────────────────────────────────

  Widget _notesCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.notes_rounded, color: AppTheme.textSecondary, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(_game.notes!,
                style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13, height: 1.5)),
          ),
        ],
      ),
    );
  }

  Widget _tagsRow() {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: _game.tags.map((tag) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: AppTheme.primary.withOpacity(0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.primary.withOpacity(0.3)),
        ),
        child: Text('#$tag',
            style: const TextStyle(color: AppTheme.primary, fontSize: 12, fontWeight: FontWeight.w500)),
      )).toList(),
    );
  }

  Future<void> _editNotesAndTags() async {
    final notesCtrl = TextEditingController(text: _game.notes ?? '');
    final tagCtrl = TextEditingController();
    final tags = List<String>.from(_game.tags);

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(builder: (ctx, setModal) {
        return Padding(
          padding: EdgeInsets.only(
              left: 20, right: 20, top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Notes & Tags',
                  style: TextStyle(color: AppTheme.textPrimary, fontSize: 17, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              TextField(
                controller: notesCtrl,
                maxLines: 4,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Notes',
                  hintText: 'e.g. nervous in time pressure...',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: tagCtrl,
                      decoration: const InputDecoration(labelText: 'Add tag'),
                      onSubmitted: (v) {
                        final t = v.trim();
                        if (t.isNotEmpty && !tags.contains(t)) {
                          setModal(() { tags.add(t); tagCtrl.clear(); });
                        }
                      },
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle_rounded, color: AppTheme.primary),
                    onPressed: () {
                      final t = tagCtrl.text.trim();
                      if (t.isNotEmpty && !tags.contains(t)) {
                        setModal(() { tags.add(t); tagCtrl.clear(); });
                      }
                    },
                  ),
                ],
              ),
              if (tags.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6, runSpacing: 6,
                  children: tags.map((tag) => Chip(
                    label: Text(tag, style: const TextStyle(fontSize: 12, color: AppTheme.textPrimary)),
                    backgroundColor: AppTheme.surfaceAlt,
                    deleteIcon: const Icon(Icons.close, size: 14, color: AppTheme.textSecondary),
                    onDeleted: () => setModal(() => tags.remove(tag)),
                  )).toList(),
                ),
              ],
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () async {
                  final updated = _game.copyWith(
                    notes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
                    tags: tags,
                  );
                  await GameService.updateGame(_game.id, updated);
                  setState(() => _game = updated);
                  if (mounted) Navigator.pop(ctx);
                },
                child: const Text('Save'),
              ),
            ],
          ),
        );
      }),
    );
  }

  // ── PGN Export ────────────────────────────────────────────────────────────

  Future<void> _exportPgn() async {
    try {
      final path = await PgnExportService.exportGame(_game);
      if (path != null) {
        await Share.shareXFiles(
          [XFile(path)],
          text: 'Game vs ${_game.opponentName}',
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e'), backgroundColor: AppTheme.loss),
        );
      }
    }
  }

  Future<void> _deleteGame() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('Delete Game?', style: TextStyle(color: AppTheme.textPrimary)),
        content: const Text('This cannot be undone.', style: TextStyle(color: AppTheme.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: AppTheme.loss)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await GameService.deleteGame(_game.id);
      if (mounted) Navigator.pop(context);
    }
  }
}
