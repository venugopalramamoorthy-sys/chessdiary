// lib/screens/game_detail_screen.dart

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
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
import '../utils/web_theme.dart';

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

class _GameDetailScreenState extends State<GameDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  late ChessGame _game;
  bool _analyzing = false;
  _H2H? _h2h;

  final ChessBoardController _boardCtrl = ChessBoardController();
  int _replayIndex = 0;
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
    final h2hGames = all
        .where((g) => g.opponentName.trim().toLowerCase() == opp && g.id != _game.id)
        .toList();
    if (h2hGames.isEmpty) return;
    int w = 0, l = 0, d = 0;
    for (final g in h2hGames) {
      final r = g.resultDisplay;
      if (r == 'Win') w++;
      else if (r == 'Loss') l++;
      else d++;
    }
    final curR = _game.resultDisplay;
    if (curR == 'Win') w++;
    else if (curR == 'Loss') l++;
    else d++;
    if (mounted) setState(() => _h2h = _H2H(w, l, d));
  }

  @override
  Widget build(BuildContext context) {
    final web = kIsWeb;
    final result = _game.resultDisplay;
    final resultColor = web ? WT.resultColor(result) : AppTheme.resultColor(result);
    final oppName = _game.opponentName.isEmpty ? 'Unknown' : _game.opponentName;

    final tabBar = TabBar(
      controller: _tabs,
      labelColor: web ? WT.greenDark : AppTheme.primary,
      unselectedLabelColor: web ? WT.silver : AppTheme.textSecondary,
      indicatorColor: web ? WT.greenDark : AppTheme.primary,
      dividerColor: web ? WT.darkGrey : null,
      labelStyle: web ? WT.lora(12, color: WT.greenDark, weight: FontWeight.w600) : null,
      tabs: const [
        Tab(text: 'Overview'),
        Tab(text: 'Analysis'),
        Tab(text: 'Replay'),
      ],
    );

    return Scaffold(
      backgroundColor: web ? WT.offWhite : null,
      appBar: web
          ? webAppBar(
              context,
              title: 'vs $oppName',
              actions: [
                IconButton(
                    icon: const Icon(Icons.share_rounded, color: WT.silver),
                    tooltip: 'Export PGN',
                    onPressed: _exportPgn),
                IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, color: WT.silver),
                    onPressed: _deleteGame),
              ],
              bottom: tabBar,
            )
          : AppBar(
              title: Text('vs $oppName'),
              actions: [
                IconButton(
                    icon: const Icon(Icons.share_rounded),
                    tooltip: 'Export PGN',
                    onPressed: _exportPgn),
                IconButton(
                    icon: const Icon(Icons.delete_outline_rounded),
                    onPressed: _deleteGame),
              ],
              bottom: tabBar,
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
    final web = kIsWeb;
    return SingleChildScrollView(
      padding: EdgeInsets.all(web ? 24 : 20),
      child: Column(
        children: [
          // Result hero
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: web
                ? BoxDecoration(
                    color: WT.white,
                    border: Border(left: BorderSide(color: resultColor, width: 4)),
                    boxShadow: const [
                      BoxShadow(color: Color(0x06000000), blurRadius: 5, offset: Offset(0, 2))
                    ],
                  )
                : BoxDecoration(
                    gradient: LinearGradient(
                      colors: [resultColor.withValues(alpha: 0.3), resultColor.withValues(alpha: 0.05)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: resultColor.withValues(alpha: 0.4)),
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
                  style: web
                      ? WT.anton(28, color: resultColor, spacing: 2.0)
                      : TextStyle(
                          color: resultColor,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                        ),
                ),
                const SizedBox(height: 4),
                Text(
                  _game.result,
                  style: web
                      ? WT.bodySm(14)
                      : const TextStyle(color: AppTheme.textSecondary, fontSize: 16),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          _infoGrid(),

          if (_h2h != null && _h2h!.total > 1) ...[
            const SizedBox(height: 20),
            _h2hCard(),
          ],

          const SizedBox(height: 20),

          if (_game.notes != null && _game.notes!.isNotEmpty) ...[
            _notesCard(),
            const SizedBox(height: 12),
          ],
          if (_game.tags.isNotEmpty) ...[
            _tagsRow(),
            const SizedBox(height: 12),
          ],
          OutlinedButton.icon(
            onPressed: _editNotesAndTags,
            icon: const Icon(Icons.edit_note_rounded, size: 18),
            label: Text(_game.notes == null && _game.tags.isEmpty
                ? 'Add notes / tags'
                : 'Edit notes / tags'),
            style: OutlinedButton.styleFrom(
              foregroundColor: web ? WT.muted : AppTheme.textSecondary,
              side: BorderSide(color: web ? WT.border : AppTheme.surfaceAlt),
            ),
          ),

          const SizedBox(height: 20),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: web
                ? WT.cardDeco()
                : BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(16),
                  ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Moves',
                  style: web
                      ? WT.lora(13, color: WT.ink, weight: FontWeight.w600)
                      : const TextStyle(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: [
                    for (int i = 0; i < _game.moves.length; i++)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: web ? WT.cream : AppTheme.surfaceAlt,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          i % 2 == 0
                              ? '${i ~/ 2 + 1}. ${_game.moves[i]}'
                              : _game.moves[i],
                          style: TextStyle(
                            color: i % 2 == 0
                                ? (web ? WT.ink : AppTheme.textPrimary)
                                : (web ? WT.muted : AppTheme.textSecondary),
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
    final web = kIsWeb;
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
          decoration: web
              ? WT.cardDeco()
              : BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                children: [
                  Icon(item.$3, size: 13, color: web ? WT.muted : AppTheme.textSecondary),
                  const SizedBox(width: 4),
                  Text(item.$1,
                      style: web
                          ? WT.bodySm(11)
                          : const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                item.$2,
                style: web
                    ? WT.lora(12, color: WT.ink, weight: FontWeight.w600)
                    : const TextStyle(
                        color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _analysisTab() {
    final web = kIsWeb;
    if (_game.analysis.isEmpty) {
      if (web) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(40),
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
                Text('NO ANALYSIS YET',
                    style: WT.anton(18, color: WT.darkGrey, spacing: 2.0)),
                const SizedBox(height: 10),
                Text(
                  'Analyse this game with Stockfish engine for\ncentipawn-accurate move quality, blunders, and mistakes.',
                  textAlign: TextAlign.center,
                  style: WT.lora(13, color: WT.muted),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: _analyzing ? null : _analyzeGame,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: WT.greenLt,
                    foregroundColor: WT.white,
                    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                  ),
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
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('🔍', style: TextStyle(fontSize: 56)),
              const SizedBox(height: 16),
              const Text('No Analysis Yet',
                  style: TextStyle(
                      color: AppTheme.textPrimary, fontSize: 20, fontWeight: FontWeight.bold)),
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

    final blunders    = _game.analysis.where((a) => a.quality == 'blunder').length;
    final mistakes    = _game.analysis.where((a) => a.quality == 'mistake').length;
    final inaccuracies = _game.analysis.where((a) => a.quality == 'inaccuracy').length;
    final good        = _game.analysis.where((a) => a.quality == 'good' || a.quality == 'best').length;

    return SingleChildScrollView(
      padding: EdgeInsets.all(web ? 24 : 16),
      child: Column(
        children: [
          Row(
            children: [
              _statBubble('$good',         'Good',       web ? WT.win        : AppTheme.goodMove),
              _statBubble('$inaccuracies', 'Inaccuracy', web ? WT.inaccuracy : AppTheme.inaccuracy),
              _statBubble('$mistakes',     'Mistakes',   web ? WT.mistake    : AppTheme.mistake),
              _statBubble('$blunders',     'Blunders',   web ? WT.blunder    : AppTheme.blunder),
            ],
          ),
          const SizedBox(height: 16),

          if (_game.evalCurve.isNotEmpty) ...[
            _evalCurveCard(),
            const SizedBox(height: 16),
          ],

          ..._turningPoints().map((tp) => _turningPointTile(tp)),
          if (_turningPoints().isNotEmpty) const SizedBox(height: 8),

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
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Text(count, style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.bold)),
            Text(label, style: TextStyle(color: color.withValues(alpha: 0.8), fontSize: 10)),
          ],
        ),
      ),
    );
  }

  Widget _evalCurveCard() {
    final web = kIsWeb;
    final curve = _game.evalCurve;
    if (curve.isEmpty) return const SizedBox();

    final isPlayerWhite = _game.playerColor == 'white';
    final spots = curve.asMap().entries.map((e) {
      final val = isPlayerWhite ? e.value.toDouble() : -e.value.toDouble();
      return FlSpot(e.key.toDouble(), val.clamp(-800, 800));
    }).toList();

    final lineC = web ? WT.greenLt : AppTheme.primary;
    final gridC = web ? WT.border  : AppTheme.surfaceAlt;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: web
          ? WT.cardDeco()
          : BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Evaluation',
              style: web
                  ? WT.lora(13, color: WT.ink, weight: FontWeight.w600)
                  : const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 14)),
          const SizedBox(height: 4),
          Text("Positive = you're winning",
              style: web
                  ? WT.bodySm(10)
                  : const TextStyle(color: AppTheme.textSecondary, fontSize: 10)),
          const SizedBox(height: 12),
          SizedBox(
            height: 100,
            child: LineChart(LineChartData(
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                getDrawingHorizontalLine: (v) => FlLine(
                  color: v == 0
                      ? (web ? WT.muted.withValues(alpha: 0.5) : AppTheme.textSecondary.withValues(alpha: 0.5))
                      : gridC,
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
                  color: lineC,
                  barWidth: 2,
                  dotData: FlDotData(show: false),
                  belowBarData: BarAreaData(show: true, color: lineC.withValues(alpha: 0.08)),
                ),
              ],
            )),
          ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _turningPoints() {
    final curve = _game.evalCurve;
    if (curve.length < 6) return [];

    final isPlayerWhite = _game.playerColor == 'white';
    final blunderMoves = _game.analysis
        .where((a) => a.quality == 'blunder' || a.quality == 'mistake')
        .map((a) => a.moveNumber)
        .toSet();

    final points = <Map<String, dynamic>>[];
    const window = 6;
    const threshold = 150;

    for (int i = 0; i + window < curve.length; i++) {
      final before = isPlayerWhite ? curve[i].toDouble() : -curve[i].toDouble();
      final after  = isPlayerWhite ? curve[i + window].toDouble() : -curve[i + window].toDouble();
      final swing  = before - after;

      if (swing >= threshold) {
        final moveNum = i ~/ 2 + 1;
        final hasFlaggedMove = blunderMoves.any((m) => m >= moveNum && m <= moveNum + 3);
        if (!hasFlaggedMove) {
          points.add({'moveStart': moveNum, 'moveEnd': moveNum + 3, 'swing': swing.toInt()});
          break;
        }
      }
    }
    return points;
  }

  Widget _turningPointTile(Map<String, dynamic> tp) {
    final web = kIsWeb;
    final accentC = web ? WT.inaccuracy : AppTheme.secondary;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: web
          ? BoxDecoration(
              color: WT.white,
              border: Border(left: BorderSide(color: accentC, width: 3)),
              boxShadow: const [BoxShadow(color: Color(0x06000000), blurRadius: 5, offset: Offset(0, 2))],
            )
          : BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.secondary.withValues(alpha: 0.4)),
            ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: accentC.withValues(alpha: 0.15),
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
                  style: TextStyle(
                      color: accentC, fontWeight: FontWeight.w600, fontSize: 13),
                ),
                const SizedBox(height: 2),
                Text(
                  'Position drifted ${tp['swing']} centipawns against you across these moves — no single blunder, but a gradual slide.',
                  style: web
                      ? WT.bodySm(12)
                      : const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _analysisTile(MoveAnalysis a) {
    final web = kIsWeb;
    final color = web ? WT.qualityColor(a.quality) : AppTheme.qualityColor(a.quality);
    final icon  = AppTheme.qualityIcon(a.quality);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: web
          ? BoxDecoration(
              color: WT.white,
              border: Border(left: BorderSide(color: color, width: 3)),
              boxShadow: const [BoxShadow(color: Color(0x06000000), blurRadius: 5, offset: Offset(0, 2))],
            )
          : BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: color.withValues(alpha: 0.3)),
            ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
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
                      style: TextStyle(
                        color: web ? WT.ink : AppTheme.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        fontFamily: 'monospace',
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(a.quality,
                          style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    _phaseBadge(a.phase),
                    if (a.motif != null) ...[const SizedBox(width: 6), _motifBadge(a.motif!)],
                    if (a.timePressure) ...[const SizedBox(width: 6), _timePressureBadge()],
                  ],
                ),
                if (a.comment != null) ...[
                  const SizedBox(height: 6),
                  Text(a.comment!,
                      style: web
                          ? WT.bodySm(13)
                          : const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<MoveAnalysis> _attachTimePressure(List<MoveAnalysis> analysis, List<int> clocks) {
    final isWhitePlayer = _game.playerColor == 'white';
    return analysis.map((a) {
      if (a.quality != 'blunder' && a.quality != 'mistake') return a;
      final whiteIdx  = (a.moveNumber - 1) * 2;
      final blackIdx  = whiteIdx + 1;
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
    final web = kIsWeb;
    final color = phase == 'opening'
        ? const Color(0xFF4FC3F7)
        : phase == 'middlegame'
            ? (web ? WT.muted : AppTheme.secondary)
            : const Color(0xFFE57373);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(phase,
          style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600)),
    );
  }

  Widget _timePressureBadge() {
    final web = kIsWeb;
    final c = web ? WT.mistake : AppTheme.mistake;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: c.withValues(alpha: 0.3)),
      ),
      child: Text('⏰ <30s', style: TextStyle(color: c, fontSize: 10, fontWeight: FontWeight.w600)),
    );
  }

  Widget _motifBadge(String motif) {
    final web = kIsWeb;
    final c = web ? WT.blunder : AppTheme.blunder;
    final label = motif.replaceAll('_', ' ');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: c.withValues(alpha: 0.3)),
      ),
      child: Text(label, style: TextStyle(color: c, fontSize: 10, fontWeight: FontWeight.w600)),
    );
  }

  Future<void> _analyzeGame() async {
    if (_game.pgn.isEmpty && _game.moves.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('No moves to analyse'),
          backgroundColor: kIsWeb ? WT.loss : AppTheme.loss,
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
        analysis = await GeminiService.tagMotifs(pgn, analysis);
      } catch (_) {
        engineUsed = 'Gemini AI';
        analysis = await GeminiService.analyzeGame(pgn);
      }

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
          backgroundColor: kIsWeb ? WT.greenLt : AppTheme.primary,
        ));
      }
    } catch (e) {
      setState(() => _analyzing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Analysis failed: $e'),
            backgroundColor: kIsWeb ? WT.loss : AppTheme.loss,
          ),
        );
      }
    }
  }

  // ── Board Replay tab ─────────────────────────────────────────────────────

  Widget _replayTab() {
    final web = kIsWeb;
    if (_replayMoves.isEmpty) {
      return Center(
        child: Text('No moves to replay',
            style: web
                ? WT.bodySm(13)
                : const TextStyle(color: AppTheme.textSecondary)),
      );
    }

    final boardSize = MediaQuery.of(context).size.width;
    final orientation = _game.playerColor == 'black' ? PlayerColor.black : PlayerColor.white;

    String moveLabel = 'Start';
    if (_replayIndex > 0) {
      final moveNum = ((_replayIndex - 1) ~/ 2) + 1;
      final isWhite = (_replayIndex - 1) % 2 == 0;
      moveLabel = '$moveNum. ${isWhite ? "" : "..."}${_replayMoves[_replayIndex - 1]}';
    }

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

    final qualColor = currentAnalysis != null
        ? (web ? WT.qualityColor(currentAnalysis.quality) : AppTheme.qualityColor(currentAnalysis.quality))
        : null;

    return Column(
      children: [
        ChessBoard(
          controller: _boardCtrl,
          size: boardSize,
          enableUserMoves: false,
          boardColor: BoardColor.brown,
          boardOrientation: orientation,
        ),

        Container(
          color: web ? WT.white : AppTheme.surface,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Text(
                moveLabel,
                style: TextStyle(
                    color: web ? WT.ink : AppTheme.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    fontFamily: 'monospace'),
              ),
              if (currentAnalysis != null && qualColor != null) ...[
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: qualColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    currentAnalysis.quality,
                    style: TextStyle(
                        color: qualColor, fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
              const Spacer(),
              Text(
                '$_replayIndex / ${_replayMoves.length}',
                style: web
                    ? WT.bodySm(12)
                    : const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
              ),
            ],
          ),
        ),

        if (currentAnalysis?.comment != null)
          Container(
            width: double.infinity,
            color: web ? WT.cream : AppTheme.surfaceAlt,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              currentAnalysis!.comment!,
              style: web
                  ? WT.bodySm(12)
                  : const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
            ),
          ),

        Container(
          color: web ? WT.offWhite : AppTheme.background,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _navBtn(Icons.first_page_rounded, () => _replayStep(-_replayMoves.length), web),
              const SizedBox(width: 8),
              _navBtn(Icons.navigate_before_rounded, () => _replayStep(-1), web),
              const SizedBox(width: 8),
              _navBtn(Icons.navigate_next_rounded,   () => _replayStep(1), web),
              const SizedBox(width: 8),
              _navBtn(Icons.last_page_rounded, () => _replayStep(_replayMoves.length), web),
            ],
          ),
        ),

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
                        style: web
                            ? WT.bodySm(12)
                            : const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                  ),
                  _movePill(whiteIdx, web),
                  if (blackIdx < _replayMoves.length) _movePill(blackIdx, web),
                  const SizedBox(width: 4),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _navBtn(IconData icon, VoidCallback onTap, bool web) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 52,
        height: 52,
        decoration: web
            ? WT.cardDeco()
            : BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(14)),
        child: Icon(icon, color: web ? WT.ink : AppTheme.textPrimary, size: 28),
      ),
    );
  }

  Widget _movePill(int halfMoveIdx, bool web) {
    final isActive = halfMoveIdx + 1 == _replayIndex;
    final move = _replayMoves[halfMoveIdx];
    return GestureDetector(
      onTap: () => _replayStep(halfMoveIdx + 1 - _replayIndex),
      child: Container(
        margin: const EdgeInsets.only(right: 2),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: isActive
              ? (web ? WT.greenLt : AppTheme.primary)
              : (web ? WT.cream   : AppTheme.surfaceAlt),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          move,
          style: TextStyle(
            color: isActive
                ? Colors.white
                : (web ? WT.ink : AppTheme.textPrimary),
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
    final web = kIsWeb;
    final h = _h2h!;
    final opp = _game.opponentName;
    final winRate = h.total == 0 ? 0.0 : h.wins / h.total;
    final winC  = web ? WT.win  : AppTheme.win;
    final lossC = web ? WT.loss : AppTheme.loss;
    final drawC = web ? WT.draw : AppTheme.draw;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: web
          ? WT.cardDeco()
          : BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.people_rounded, color: web ? WT.muted : AppTheme.textSecondary, size: 16),
              const SizedBox(width: 6),
              Text(
                'vs $opp — ${h.total} game${h.total == 1 ? '' : 's'}',
                style: web
                    ? WT.lora(12, color: WT.ink, weight: FontWeight.w600)
                    : const TextStyle(
                        color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 13),
              ),
              const Spacer(),
              Text(
                '${(winRate * 100).toStringAsFixed(0)}% win',
                style: TextStyle(
                  color: winRate >= 0.5 ? winC : lossC,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _h2hBadge('${h.wins} W', winC),
              const SizedBox(width: 6),
              _h2hBadge('${h.losses} L', lossC),
              const SizedBox(width: 6),
              _h2hBadge('${h.draws} D', drawC),
            ],
          ),
          const SizedBox(height: 8),
          if (h.total > 0)
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Row(
                children: [
                  if (h.wins > 0)   Flexible(flex: h.wins,   child: Container(height: 6, color: winC)),
                  if (h.losses > 0) Flexible(flex: h.losses, child: Container(height: 6, color: lossC)),
                  if (h.draws > 0)  Flexible(flex: h.draws,  child: Container(height: 6, color: drawC)),
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
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label,
          style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }

  // ── Notes/Tags widgets ────────────────────────────────────────────────────

  Widget _notesCard() {
    final web = kIsWeb;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: web
          ? WT.cardDeco()
          : BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(14)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.notes_rounded, color: web ? WT.muted : AppTheme.textSecondary, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(_game.notes!,
                style: web
                    ? WT.lora(13, color: WT.ink)
                    : const TextStyle(color: AppTheme.textPrimary, fontSize: 13, height: 1.5)),
          ),
        ],
      ),
    );
  }

  Widget _tagsRow() {
    final web = kIsWeb;
    final accentC = web ? WT.greenLt : AppTheme.primary;
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: _game.tags.map((tag) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: accentC.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: accentC.withValues(alpha: 0.3)),
        ),
        child: Text('#$tag',
            style: TextStyle(color: accentC, fontSize: 12, fontWeight: FontWeight.w500)),
      )).toList(),
    );
  }

  Future<void> _editNotesAndTags() async {
    final web = kIsWeb;
    final notesCtrl = TextEditingController(text: _game.notes ?? '');
    final tagCtrl = TextEditingController();
    final tags = List<String>.from(_game.tags);

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: web ? WT.white : AppTheme.surface,
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
              Text('Notes & Tags',
                  style: web
                      ? WT.lora(16, color: WT.ink, weight: FontWeight.w700)
                      : const TextStyle(
                          color: AppTheme.textPrimary, fontSize: 17, fontWeight: FontWeight.bold)),
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
                    icon: Icon(Icons.add_circle_rounded,
                        color: web ? WT.greenLt : AppTheme.primary),
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
                    label: Text(tag,
                        style: TextStyle(
                            fontSize: 12,
                            color: web ? WT.ink : AppTheme.textPrimary)),
                    backgroundColor: web ? WT.cream : AppTheme.surfaceAlt,
                    deleteIcon: Icon(Icons.close, size: 14,
                        color: web ? WT.muted : AppTheme.textSecondary),
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
          SnackBar(
            content: Text('Export failed: $e'),
            backgroundColor: kIsWeb ? WT.loss : AppTheme.loss,
          ),
        );
      }
    }
  }

  Future<void> _deleteGame() async {
    final web = kIsWeb;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: web ? WT.white : AppTheme.surface,
        title: Text('Delete Game?',
            style: web
                ? WT.lora(16, color: WT.ink, weight: FontWeight.w700)
                : const TextStyle(color: AppTheme.textPrimary)),
        content: Text('This cannot be undone.',
            style: web
                ? WT.bodySm(13)
                : const TextStyle(color: AppTheme.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Delete',
                style: TextStyle(color: web ? WT.loss : AppTheme.loss)),
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
