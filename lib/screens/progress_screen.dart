import 'dart:math';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:percent_indicator/percent_indicator.dart';
import '../models/game_model.dart';
import '../services/chess_insights.dart';
import '../services/game_service.dart';
import '../services/gemini_service.dart';
import '../services/rating_service.dart';
import '../utils/theme.dart';

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  PlayerStats? _stats;
  _RichStats? _rich;
  CoachingInsights? _coaching;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final stats = await GameService.getPlayerStats();
      final rich = _RichStats.compute(stats.allGames);
      final ratings = await RatingService.getAllEntries();
      final coachingData = _buildCoachingData(stats, rich, ratings);
      final coaching = await GeminiService.getCoachingInsights(coachingData);
      if (mounted) {
        setState(() {
          _stats = stats;
          _rich = rich;
          _coaching = coaching;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  CoachingData _buildCoachingData(
      PlayerStats stats, _RichStats rich, List<RatingEntry> ratings) {
    // Opening best/worst (min 3 games)
    final openingRecs = ChessInsights.openingRecords(stats.allGames);
    final qualified = openingRecs.values.where((r) => r.total >= 3).toList();
    qualified.sort((a, b) => b.winRate.compareTo(a.winRate));
    final best = qualified.isNotEmpty ? qualified.first : null;
    final worst = qualified.length > 1 ? qualified.last : null;

    // Time control win rates
    final tcRecs = ChessInsights.timeControlRecords(stats.allGames);
    final winRateByTC = <String, double>{};
    final gamesByTC = <String, int>{};
    for (final e in tcRecs.entries) {
      if (e.value.total >= 3) {
        winRateByTC[e.key] = e.value.winRate;
        gamesByTC[e.key] = e.value.total;
      }
    }

    // Tactical blind spots
    final blindSpots = ChessInsights.tacticalBlindSpots(stats.allGames);

    // Endgame conversion
    final egResult = ChessInsights.endgameConversionRate(stats.allGames);

    // Recent form (last 10)
    final recent = stats.recentGames.take(10).toList();
    final recentWins = recent.where((g) => g.resultDisplay == 'Win').length;

    // Toughest opponent (min 2 games, lowest win rate)
    final oppMap = <String, _OppRecord>{};
    for (final g in stats.allGames) {
      final opp = g.opponentName.trim();
      if (opp.isEmpty || opp.toLowerCase() == 'unknown') continue;
      final r = oppMap.putIfAbsent(opp, () => _OppRecord());
      if (g.resultDisplay == 'Win') r.wins++;
      else if (g.resultDisplay == 'Loss') r.losses++;
      else r.draws++;
    }
    final qualified2 = oppMap.entries.where((e) => e.value.total >= 2).toList();
    qualified2.sort((a, b) => a.value.winRate.compareTo(b.value.winRate));
    final toughest = qualified2.isNotEmpty ? qualified2.first : null;

    // Rating trend
    int? latestRating, ratingChange;
    String? ratingType;
    if (ratings.length >= 1) {
      final sorted = List<RatingEntry>.from(ratings)
        ..sort((a, b) => a.date.compareTo(b.date));
      latestRating = sorted.last.rating;
      ratingType = sorted.last.type;
      if (sorted.length >= 2) {
        ratingChange = sorted.last.rating - sorted[sorted.length - 2].rating;
      }
    }

    return CoachingData(
      totalGames: stats.totalGames,
      totalAnalysedGames: stats.allGames.where((g) => g.analysis.isNotEmpty).length,
      overallWinRate: stats.winRate,
      whiteWinRate: (rich.whiteW + rich.whiteL + rich.whiteD) == 0
          ? 0 : rich.whiteW / (rich.whiteW + rich.whiteL + rich.whiteD),
      blackWinRate: (rich.blackW + rich.blackL + rich.blackD) == 0
          ? 0 : rich.blackW / (rich.blackW + rich.blackL + rich.blackD),
      whiteGames: rich.whiteW + rich.whiteL + rich.whiteD,
      blackGames: rich.blackW + rich.blackL + rich.blackD,
      winRateByTC: winRateByTC,
      gamesByTC: gamesByTC,
      bestOpening: best?.name,
      bestOpeningWinRate: best?.winRate,
      bestOpeningGames: best?.total,
      worstOpening: worst?.name,
      worstOpeningWinRate: worst?.winRate,
      worstOpeningGames: worst?.total,
      topMotif: blindSpots.isNotEmpty ? blindSpots.first.motif : null,
      topMotifCount: blindSpots.isNotEmpty ? blindSpots.first.count : null,
      endgameConversionRate: egResult.rate,
      endgameOpportunities: egResult.opportunities,
      flaggedBlunderCount: stats.allGames
          .expand((g) => g.analysis)
          .where((a) => a.quality == 'blunder' || a.quality == 'mistake')
          .length,
      tiltWinRate: rich.tiltGames >= 3 ? rich.tiltWinRate : null,
      normalWinRate: rich.tiltGames >= 3 ? rich.normalWinRate : null,
      tiltGames: rich.tiltGames,
      timePressureBlunderRate: rich.timePressureGames >= 3 ? rich.timePressureBlunderRate : null,
      normalBlunderRate: rich.timePressureGames >= 3 ? rich.normalBlunderRate : null,
      recentWins: recentWins,
      recentTotal: recent.length,
      latestRating: latestRating,
      ratingType: ratingType,
      ratingChange: ratingChange,
      toughestOpponent: toughest?.key,
      toughestOpponentWinRate: toughest?.value.winRate,
      toughestOpponentGames: toughest?.value.total,
      blunderStreakGames: rich.blunderStreakGames,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Progress'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _load),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : (_stats == null || _stats!.totalGames == 0)
              ? _emptyState()
              : SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _overallCard(),
                      const SizedBox(height: 16),
                      _formRow(),
                      const SizedBox(height: 16),
                      _winTrendCard(),
                      if (_rich!.ratingPoints.length >= 3) ...[
                        const SizedBox(height: 16),
                        _ratingTrendCard(),
                      ],
                      if (_rich!.errorTrend.length >= 3) ...[
                        const SizedBox(height: 16),
                        _errorTrendCard(),
                      ],
                      const SizedBox(height: 16),
                      _colorCard(),
                      if (_rich!.topOpenings.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        _openingsCard(),
                      ],
                      if (_rich!.mistakePatterns.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        _mistakePatternsCard(),
                      ],
                      const SizedBox(height: 16),
                      _strengthsWeaknessesCard(),
                      if (_rich!.tacticalBlindSpots.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        _tacticalBlindSpotsCard(),
                      ],
                      if (_rich!.endgameOpportunities >= 3) ...[
                        const SizedBox(height: 16),
                        _endgameConversionCard(),
                      ],
                      if (_rich!.timePressureGames >= 3) ...[
                        const SizedBox(height: 16),
                        _timePressureCard(),
                      ],
                      if (_rich!.tiltGames >= 3) ...[
                        const SizedBox(height: 16),
                        _tiltCard(),
                      ],
                      if (_rich!.blunderStreakGames > 0) ...[
                        const SizedBox(height: 16),
                        _blunderStreakCard(),
                      ],
                      const SizedBox(height: 16),
                      _coachingSection(),
                    ],
                  ),
                ),
    );
  }

  // ── Overall W/L/D ───────────────────────────────────────────────────────────

  Widget _overallCard() {
    final s = _stats!;
    return _Card(
      child: Column(
        children: [
          const Text('Overall Record',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularPercentIndicator(
                radius: 72,
                lineWidth: 10,
                percent: s.winRate.clamp(0.0, 1.0),
                center: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${(s.winRate * 100).toStringAsFixed(0)}%',
                      style: const TextStyle(
                          color: AppTheme.textPrimary, fontSize: 26, fontWeight: FontWeight.bold),
                    ),
                    const Text('Win rate',
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 10)),
                  ],
                ),
                progressColor: AppTheme.primary,
                backgroundColor: AppTheme.surfaceAlt,
                circularStrokeCap: CircularStrokeCap.round,
              ),
              const SizedBox(width: 32),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _statLine('${s.wins}', 'Wins', AppTheme.win),
                  const SizedBox(height: 10),
                  _statLine('${s.losses}', 'Losses', AppTheme.loss),
                  const SizedBox(height: 10),
                  _statLine('${s.draws}', 'Draws', AppTheme.draw),
                  const SizedBox(height: 10),
                  _statLine('${s.totalGames}', 'Total', AppTheme.textSecondary),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Row(
              children: [
                if (s.wins > 0) Flexible(flex: s.wins, child: Container(height: 8, color: AppTheme.win)),
                if (s.losses > 0) Flexible(flex: s.losses, child: Container(height: 8, color: AppTheme.loss)),
                if (s.draws > 0) Flexible(flex: s.draws, child: Container(height: 8, color: AppTheme.draw)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statLine(String value, String label, Color color) {
    return Row(
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
      ],
    );
  }

  // ── Form + streak row ────────────────────────────────────────────────────────

  Widget _formRow() {
    final recent = _stats!.recentGames.take(10).toList().reversed.toList();
    final streak = _rich!.currentStreak;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 3,
          child: _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Recent Form',
                    style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600)),
                const SizedBox(height: 10),
                Row(
                  children: recent.map((g) {
                    final r = g.resultDisplay;
                    final c = r == 'Win' ? AppTheme.win : r == 'Loss' ? AppTheme.loss : AppTheme.draw;
                    final l = r == 'Win' ? 'W' : r == 'Loss' ? 'L' : 'D';
                    return Expanded(
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 1.5),
                        height: 32,
                        decoration: BoxDecoration(
                          color: c.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(5),
                          border: Border.all(color: c.withOpacity(0.5)),
                        ),
                        child: Center(child: Text(l, style: TextStyle(color: c, fontWeight: FontWeight.bold, fontSize: 11))),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  streak > 0 ? '🔥 Win streak' : streak < 0 ? '📉 Losing streak' : '➖ No streak',
                  style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 13),
                ),
                const SizedBox(height: 6),
                Text(
                  streak != 0 ? '${streak.abs()} game${streak.abs() == 1 ? '' : 's'}' : '—',
                  style: TextStyle(
                    color: streak > 0 ? AppTheme.win : streak < 0 ? AppTheme.loss : AppTheme.textSecondary,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (_rich!.blunderStreakGames > 0)
                  Text('${_rich!.blunderStreakGames} games since last blunder',
                      style: const TextStyle(color: AppTheme.primary, fontSize: 10)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Win rate trend line chart ────────────────────────────────────────────────

  Widget _winTrendCard() {
    final points = _rich!.winRateTrend;
    if (points.length < 4) return const SizedBox();
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.trending_up_rounded, color: AppTheme.primary, size: 18),
              SizedBox(width: 8),
              Text('Win Rate Trend',
                  style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 15)),
              SizedBox(width: 6),
              Text('(rolling 10 games)', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 140,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 0.25,
                  getDrawingHorizontalLine: (_) => FlLine(color: AppTheme.surfaceAlt, strokeWidth: 1),
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 36,
                      interval: 0.25,
                      getTitlesWidget: (v, _) => Text(
                        '${(v * 100).toInt()}%',
                        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 10),
                      ),
                    ),
                  ),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                minY: 0,
                maxY: 1,
                lineBarsData: [
                  LineChartBarData(
                    spots: points
                        .asMap()
                        .entries
                        .map((e) => FlSpot(e.key.toDouble(), e.value))
                        .toList(),
                    isCurved: true,
                    color: AppTheme.primary,
                    barWidth: 2.5,
                    belowBarData: BarAreaData(
                      show: true,
                      color: AppTheme.primary.withOpacity(0.12),
                    ),
                    dotData: const FlDotData(show: false),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Rating trend chart ───────────────────────────────────────────────────────

  Widget _ratingTrendCard() {
    final pts = _rich!.ratingPoints;
    final minR = pts.map((p) => p.y).reduce(min) - 50;
    final maxR = pts.map((p) => p.y).reduce(max) + 50;
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.bar_chart_rounded, color: AppTheme.secondary, size: 18),
              SizedBox(width: 8),
              Text('Rating Trend',
                  style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 15)),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 140,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) => FlLine(color: AppTheme.surfaceAlt, strokeWidth: 1),
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 44,
                      getTitlesWidget: (v, _) => Text(
                        v.toInt().toString(),
                        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 10),
                      ),
                    ),
                  ),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                minY: minR,
                maxY: maxR,
                lineBarsData: [
                  LineChartBarData(
                    spots: pts,
                    isCurved: true,
                    color: AppTheme.secondary,
                    barWidth: 2.5,
                    belowBarData: BarAreaData(
                      show: true,
                      color: AppTheme.secondary.withOpacity(0.1),
                    ),
                    dotData: const FlDotData(show: false),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Error trend chart ────────────────────────────────────────────────────────

  Widget _errorTrendCard() {
    final pts = _rich!.errorTrend; // [{blunders, mistakes, inaccuracies} per game]
    final blunderSpots = pts.asMap().entries
        .map((e) => FlSpot(e.key.toDouble(), e.value['blunder']!.toDouble()))
        .toList();
    final mistakeSpots = pts.asMap().entries
        .map((e) => FlSpot(e.key.toDouble(), e.value['mistake']!.toDouble()))
        .toList();
    final maxY = (pts.map((p) => (p['blunder']! + p['mistake']! + p['inaccuracy']!)).reduce(max) + 1).toDouble();

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: AppTheme.mistake, size: 18),
              SizedBox(width: 8),
              Text('Mistakes Over Time',
                  style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 15)),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              _legendDot(AppTheme.blunder, 'Blunders'),
              const SizedBox(width: 16),
              _legendDot(AppTheme.mistake, 'Mistakes'),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 130,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) => FlLine(color: AppTheme.surfaceAlt, strokeWidth: 1),
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 24,
                      interval: maxY > 4 ? (maxY / 4).ceilToDouble() : 1,
                      getTitlesWidget: (v, _) => Text(
                        v.toInt().toString(),
                        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 10),
                      ),
                    ),
                  ),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                minY: 0,
                maxY: maxY,
                lineBarsData: [
                  LineChartBarData(
                    spots: blunderSpots,
                    isCurved: true,
                    color: AppTheme.blunder,
                    barWidth: 2,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(show: true, color: AppTheme.blunder.withOpacity(0.08)),
                  ),
                  LineChartBarData(
                    spots: mistakeSpots,
                    isCurved: true,
                    color: AppTheme.mistake,
                    barWidth: 2,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(show: true, color: AppTheme.mistake.withOpacity(0.06)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          if (_rich!.blunderTrend != null)
            Text(
              _rich!.blunderTrend!,
              style: TextStyle(
                color: _rich!.blunderTrend!.contains('fewer') ? AppTheme.win : AppTheme.textSecondary,
                fontSize: 12,
              ),
            ),
        ],
      ),
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
      ],
    );
  }

  // ── Color stats ──────────────────────────────────────────────────────────────

  Widget _colorCard() {
    final r = _rich!;
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('White vs Black',
              style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 15)),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _colorSide('♙ White', r.whiteW, r.whiteL, r.whiteD)),
              Container(width: 1, height: 80, color: AppTheme.surfaceAlt),
              Expanded(child: _colorSide('♟ Black', r.blackW, r.blackL, r.blackD)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _colorSide(String title, int w, int l, int d) {
    final total = w + l + d;
    final rate = total == 0 ? 0.0 : w / total;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        children: [
          Text(title, style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text('${(rate * 100).toStringAsFixed(0)}%',
              style: const TextStyle(color: AppTheme.primary, fontSize: 24, fontWeight: FontWeight.bold)),
          Text('win rate · $total games',
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Row(
              children: [
                if (w > 0) Flexible(flex: w, child: Container(height: 6, color: AppTheme.win)),
                if (l > 0) Flexible(flex: l, child: Container(height: 6, color: AppTheme.loss)),
                if (d > 0) Flexible(flex: d, child: Container(height: 6, color: AppTheme.draw)),
                if (total == 0) Expanded(child: Container(height: 6, color: AppTheme.surfaceAlt)),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text('$w W  $l L  $d D',
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 10)),
        ],
      ),
    );
  }

  // ── Top openings ─────────────────────────────────────────────────────────────

  Widget _openingsCard() {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.book_rounded, color: AppTheme.primary, size: 18),
              SizedBox(width: 8),
              Text('Top Openings',
                  style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 15)),
            ],
          ),
          const SizedBox(height: 14),
          ..._rich!.topOpenings.map((o) {
            final winPct = o.total == 0 ? 0.0 : o.wins / o.total;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(o.name,
                            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                            overflow: TextOverflow.ellipsis),
                      ),
                      Text('${o.wins}W ${o.losses}L ${o.draws}D',
                          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                      const SizedBox(width: 8),
                      Text('${(winPct * 100).toStringAsFixed(0)}%',
                          style: TextStyle(
                              color: winPct >= 0.5 ? AppTheme.win : AppTheme.loss,
                              fontSize: 12,
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 5),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Row(
                      children: [
                        if (o.wins > 0) Flexible(flex: o.wins, child: Container(height: 6, color: AppTheme.win)),
                        if (o.losses > 0) Flexible(flex: o.losses, child: Container(height: 6, color: AppTheme.loss)),
                        if (o.draws > 0) Flexible(flex: o.draws, child: Container(height: 6, color: AppTheme.draw)),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ── Mistake patterns ─────────────────────────────────────────────────────────

  Widget _mistakePatternsCard() {
    final patterns = _rich!.mistakePatterns;
    final maxCount = patterns.map((p) => p.count).reduce(max);
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.psychology_rounded, color: AppTheme.blunder, size: 18),
              SizedBox(width: 8),
              Text('Most Common Mistakes',
                  style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 15)),
            ],
          ),
          const SizedBox(height: 4),
          const Text('From games with saved analysis',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
          const SizedBox(height: 14),
          ...patterns.map((p) {
            final ratio = p.count / maxCount;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Text(p.icon, style: const TextStyle(fontSize: 16)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(p.label,
                                  style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13)),
                            ),
                            Text('${p.count}x',
                                style: const TextStyle(
                                    color: AppTheme.blunder, fontWeight: FontWeight.bold, fontSize: 12)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: ratio,
                            backgroundColor: AppTheme.surfaceAlt,
                            color: _qualityColor(p.quality),
                            minHeight: 6,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Color _qualityColor(String q) {
    if (q == 'blunder') return AppTheme.blunder;
    if (q == 'mistake') return AppTheme.mistake;
    return AppTheme.inaccuracy;
  }

  // ── Strengths & Weaknesses ───────────────────────────────────────────────────

  Widget _strengthsWeaknessesCard() {
    final sw = _rich!.strengthsWeaknesses;
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.insights_rounded, color: AppTheme.primary, size: 18),
              SizedBox(width: 8),
              Text('Strengths & Weaknesses',
                  style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 15)),
            ],
          ),
          const SizedBox(height: 14),
          ...sw.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.isStrength ? '💪' : '⚠️', style: const TextStyle(fontSize: 16)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        item.text,
                        style: TextStyle(
                          color: item.isStrength ? AppTheme.win : AppTheme.textPrimary,
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  // ── Blunder streak card ──────────────────────────────────────────────────────

  Widget _tacticalBlindSpotsCard() {
    final spots = _rich!.tacticalBlindSpots.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top = spots.take(5).toList();
    final maxCount = top.first.value;

    final motifEmoji = {
      'hanging_piece': '🎣', 'fork': '🍴', 'pin': '📌',
      'skewer': '🗡️', 'back_rank': '🏠', 'discovered_attack': '👁️',
      'deflection': '↪️', 'overloaded': '⚖️', 'sacrifice': '🎁',
      'endgame_technique': '♟️',
    };

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Text('🎯', style: TextStyle(fontSize: 18)),
              SizedBox(width: 8),
              Text('Tactical Blind Spots',
                  style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 15)),
            ],
          ),
          const SizedBox(height: 4),
          const Text('Motifs you miss most often (blunders + mistakes)',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
          const SizedBox(height: 14),
          ...top.map((e) {
            final ratio = e.value / maxCount;
            final emoji = motifEmoji[e.key] ?? '⚠️';
            final label = e.key.replaceAll('_', ' ');
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Text(emoji, style: const TextStyle(fontSize: 16)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(child: Text(label,
                                style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13))),
                            Text('${e.value}×',
                                style: const TextStyle(color: AppTheme.blunder,
                                    fontWeight: FontWeight.bold, fontSize: 12)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: ratio,
                            backgroundColor: AppTheme.surfaceAlt,
                            color: AppTheme.blunder,
                            minHeight: 6,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _endgameConversionCard() {
    final r = _rich!;
    final pct = (r.endgameConversionRate * 100).toStringAsFixed(0);
    final isGood = r.endgameConversionRate >= 0.6;
    final color = isGood ? AppTheme.win : AppTheme.loss;

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Text('♟️', style: TextStyle(fontSize: 18)),
              SizedBox(width: 8),
              Text('Endgame Conversion Rate',
                  style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 15)),
            ],
          ),
          const SizedBox(height: 4),
          Text('Games where you entered the endgame with clean play (${r.endgameOpportunities} opportunities)',
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
          const SizedBox(height: 16),
          Row(
            children: [
              Text('$pct%',
                  style: TextStyle(color: color, fontSize: 36, fontWeight: FontWeight.bold)),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  isGood
                      ? 'Strong endgame play — you convert your advantages well.'
                      : 'Room to improve — consider studying basic endgame techniques.',
                  style: TextStyle(color: color, fontSize: 13, height: 1.4),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: r.endgameConversionRate.clamp(0.0, 1.0),
              backgroundColor: AppTheme.surfaceAlt,
              color: color,
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _timePressureCard() {
    final r = _rich!;
    final worse = r.timePressureBlunderRate > r.normalBlunderRate + 0.5;
    final color = worse ? AppTheme.loss : AppTheme.win;
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Text('⏰', style: TextStyle(fontSize: 18)),
              SizedBox(width: 8),
              Text('Time Pressure Impact',
                  style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 15)),
            ],
          ),
          const SizedBox(height: 4),
          Text('Blunders + mistakes per 10 moves (${r.timePressureGames} games with clock data)',
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    Text(r.timePressureBlunderRate.toStringAsFixed(1),
                        style: TextStyle(color: color, fontSize: 26, fontWeight: FontWeight.bold)),
                    const Text('Under 30s\n(time pressure)',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                  ],
                ),
              ),
              Container(width: 1, height: 48, color: AppTheme.surfaceAlt),
              Expanded(
                child: Column(
                  children: [
                    Text(r.normalBlunderRate.toStringAsFixed(1),
                        style: const TextStyle(color: AppTheme.primary, fontSize: 26, fontWeight: FontWeight.bold)),
                    const Text('With time\nto think',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            worse
                ? '📉 Error rate spikes ${(r.timePressureBlunderRate - r.normalBlunderRate).toStringAsFixed(1)}× under time pressure — practise faster decision-making.'
                : '✅ You stay accurate under time pressure — good clock management.',
            style: TextStyle(color: color, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _tiltCard() {
    final r = _rich!;
    final diff = r.normalWinRate - r.tiltWinRate;
    final isTilting = diff > 0.05;
    final color = isTilting ? AppTheme.loss : AppTheme.win;
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(isTilting ? '😤' : '🧘', style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              const Text('Tilt Pattern',
                  style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 15)),
              const SizedBox(width: 6),
              const Text('(games within 24h of a loss)',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    Text('${(r.tiltWinRate * 100).toStringAsFixed(0)}%',
                        style: TextStyle(color: color, fontSize: 24, fontWeight: FontWeight.bold)),
                    Text('After a loss\n(${r.tiltGames} games)',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                  ],
                ),
              ),
              Container(width: 1, height: 48, color: AppTheme.surfaceAlt),
              Expanded(
                child: Column(
                  children: [
                    Text('${(r.normalWinRate * 100).toStringAsFixed(0)}%',
                        style: const TextStyle(color: AppTheme.primary, fontSize: 24, fontWeight: FontWeight.bold)),
                    const Text('Normal games',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            isTilting
                ? '📉 Win rate drops ${(diff * 100).toStringAsFixed(0)}% after a loss — consider a break before your next game.'
                : '✅ You handle losses well — no significant tilt detected.',
            style: TextStyle(color: isTilting ? AppTheme.loss : AppTheme.win, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _blunderStreakCard() {
    final n = _rich!.blunderStreakGames;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.primary.withOpacity(0.25), AppTheme.primary.withOpacity(0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primary.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          const Text('🏆', style: TextStyle(fontSize: 32)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Clean Game Streak',
                    style: TextStyle(
                        color: AppTheme.primary, fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(height: 4),
                Text(
                  '$n game${n == 1 ? '' : 's'} without a blunder!',
                  style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── AI Coach — 3 specific, stat-backed insight cards ─────────────────────────

  Widget _coachingSection() {
    final c = _coaching;

    // Loading state
    if (c == null) {
      return _Card(
        child: Row(
          children: const [
            SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary)),
            SizedBox(width: 12),
            Text('Generating coaching insights...', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
          ],
        ),
      );
    }

    // Not enough data
    if (!c.hasEnoughData) {
      return _Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Row(children: [
              Text('🤖', style: TextStyle(fontSize: 18)),
              SizedBox(width: 8),
              Text('AI Coach', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w600, fontSize: 15)),
            ]),
            SizedBox(height: 10),
            Text('Log and analyse at least 5 games to unlock personalised coaching insights.',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
          ],
        ),
      );
    }

    return Column(
      children: [
        Row(children: const [
          Text('🤖', style: TextStyle(fontSize: 18)),
          SizedBox(width: 8),
          Text('AI Coach', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w600, fontSize: 15)),
        ]),
        const SizedBox(height: 12),
        _insightCard(c.leak, '🔴', const Color(0xFF3D1A1A)),
        const SizedBox(height: 10),
        _insightCard(c.strength, '🟢', const Color(0xFF1A3D1A)),
        const SizedBox(height: 10),
        _insightCard(c.focus, '🎯', const Color(0xFF1A2D3D)),
      ],
    );
  }

  Widget _insightCard(InsightCard? card, String emoji, Color bgColor) {
    if (card == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Text('Not enough data yet for this insight.',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
      );
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bgColor.withOpacity(0.6),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.primary.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text(emoji, style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 8),
            Text(card.title,
                style: const TextStyle(
                    color: AppTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 13)),
          ]),
          const SizedBox(height: 8),
          Text(card.body,
              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13, height: 1.5)),
        ],
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Text('📈', style: TextStyle(fontSize: 64)),
          SizedBox(height: 16),
          Text('No data yet',
              style: TextStyle(color: AppTheme.textPrimary, fontSize: 20, fontWeight: FontWeight.bold)),
          SizedBox(height: 8),
          Text('Add some games to see your progress here',
              style: TextStyle(color: AppTheme.textSecondary)),
        ],
      ),
    );
  }
}

// ── Opponent record helper ────────────────────────────────────────────────────

class _OppRecord {
  int wins = 0, losses = 0, draws = 0;
  int get total => wins + losses + draws;
  double get winRate => total == 0 ? 0 : wins / total;
}

// ── Reusable card shell ──────────────────────────────────────────────────────

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: child,
      );
}

// ── Data models ──────────────────────────────────────────────────────────────

class _OpeningStat {
  final String name;
  int wins = 0, losses = 0, draws = 0;
  _OpeningStat(this.name);
  int get total => wins + losses + draws;
}

class _MistakePattern {
  final String label;
  final String icon;
  final String quality;
  int count;
  _MistakePattern(this.label, this.icon, this.quality, this.count);
}

class _SwItem {
  final String text;
  final bool isStrength;
  _SwItem(this.text, this.isStrength);
}

class _RichStats {
  final int currentStreak;
  final int whiteW, whiteL, whiteD;
  final int blackW, blackL, blackD;
  final List<double> winRateTrend;
  final List<FlSpot> ratingPoints;
  final List<Map<String, int>> errorTrend;
  final String? blunderTrend;
  final List<_OpeningStat> topOpenings;
  final List<_MistakePattern> mistakePatterns;
  final List<_SwItem> strengthsWeaknesses;
  final int blunderStreakGames;
  // Tilt pattern
  final double tiltWinRate;
  final double normalWinRate;
  final int tiltGames;
  // Endgame conversion
  final double endgameConversionRate;
  final int endgameOpportunities;
  // Tactical blind spots (motif → count)
  final Map<String, int> tacticalBlindSpots;
  // Time pressure
  final double timePressureBlunderRate;  // blunders/mistakes per game under time pressure
  final double normalBlunderRate;        // blunders/mistakes per game with time to spare
  final int timePressureGames;           // games that have clock data

  _RichStats({
    required this.currentStreak,
    required this.whiteW, required this.whiteL, required this.whiteD,
    required this.blackW, required this.blackL, required this.blackD,
    required this.winRateTrend,
    required this.ratingPoints,
    required this.errorTrend,
    required this.blunderTrend,
    required this.topOpenings,
    required this.mistakePatterns,
    required this.strengthsWeaknesses,
    required this.blunderStreakGames,
    required this.tiltWinRate,
    required this.normalWinRate,
    required this.tiltGames,
    required this.endgameConversionRate,
    required this.endgameOpportunities,
    required this.tacticalBlindSpots,
    required this.timePressureBlunderRate,
    required this.normalBlunderRate,
    required this.timePressureGames,
  });

  factory _RichStats.compute(List<ChessGame> games) {
    if (games.isEmpty) {
      return _RichStats(
        currentStreak: 0, whiteW: 0, whiteL: 0, whiteD: 0,
        blackW: 0, blackL: 0, blackD: 0, winRateTrend: [],
        ratingPoints: [], errorTrend: [], blunderTrend: null,
        topOpenings: [], mistakePatterns: [], strengthsWeaknesses: [],
        blunderStreakGames: 0,
        tiltWinRate: 0, normalWinRate: 0, tiltGames: 0,
        endgameConversionRate: 0, endgameOpportunities: 0,
        tacticalBlindSpots: {},
        timePressureBlunderRate: 0, normalBlunderRate: 0, timePressureGames: 0,
      );
    }

    // games is newest-first from Firestore; reverse for chronological charts
    final chrono = games.reversed.toList();

    // ── Streak ──
    int streak = 0;
    final first = games.first.resultDisplay;
    if (first == 'Win') {
      for (final g in games) { if (g.resultDisplay != 'Win') break; streak++; }
    } else if (first == 'Loss') {
      for (final g in games) { if (g.resultDisplay != 'Loss') break; streak--; }
    }

    // ── Color stats ──
    int wW = 0, wL = 0, wD = 0, bW = 0, bL = 0, bD = 0;
    for (final g in games) {
      final r = g.resultDisplay;
      if (g.playerColor == 'white') {
        if (r == 'Win') wW++; else if (r == 'Loss') wL++; else wD++;
      } else {
        if (r == 'Win') bW++; else if (r == 'Loss') bL++; else bD++;
      }
    }

    // ── Win rate trend (rolling window of 10) ──
    const window = 10;
    final winRateTrend = <double>[];
    for (int i = window - 1; i < chrono.length; i++) {
      final slice = chrono.sublist(i - window + 1, i + 1);
      final wins = slice.where((g) => g.resultDisplay == 'Win').length;
      winRateTrend.add(wins / window);
    }

    // ── Rating trend ──
    final ratingPoints = <FlSpot>[];
    int rIdx = 0;
    for (final g in chrono) {
      if (g.playerRating != null) {
        ratingPoints.add(FlSpot(rIdx.toDouble(), g.playerRating!.toDouble()));
        rIdx++;
      }
    }

    // ── Error trend (per-game counts, games with analysis only) ──
    final errorTrend = <Map<String, int>>[];
    for (final g in chrono) {
      if (g.analysis.isEmpty) continue;
      int blunders = 0, mistakes = 0, inaccuracies = 0;
      for (final m in g.analysis) {
        if (m.quality == 'blunder') blunders++;
        else if (m.quality == 'mistake') mistakes++;
        else if (m.quality == 'inaccuracy') inaccuracies++;
      }
      errorTrend.add({'blunder': blunders, 'mistake': mistakes, 'inaccuracy': inaccuracies});
    }

    // Compute blunder trend label
    String? blunderTrend;
    if (errorTrend.length >= 6) {
      final half = errorTrend.length ~/ 2;
      final early = errorTrend.sublist(0, half).map((e) => e['blunder']!).reduce((a, b) => a + b) / half;
      final late = errorTrend.sublist(half).map((e) => e['blunder']!).reduce((a, b) => a + b) / (errorTrend.length - half);
      if (late < early - 0.3) blunderTrend = '📉 Fewer blunders recently — you\'re improving!';
      else if (late > early + 0.3) blunderTrend = '📈 More blunders lately — focus on tactics';
    }

    // ── Blunder streak (consecutive games with 0 blunders, from analyzed games) ──
    int blunderStreak = 0;
    for (final g in games) {
      if (g.analysis.isEmpty) continue;
      if (g.analysis.any((m) => m.quality == 'blunder')) break;
      blunderStreak++;
    }

    // ── Openings ──
    final openingMap = <String, _OpeningStat>{};
    for (final g in games) {
      final op = g.opening;
      if (op == null || op.isEmpty) continue;
      final stat = openingMap.putIfAbsent(op, () => _OpeningStat(op));
      final r = g.resultDisplay;
      if (r == 'Win') stat.wins++; else if (r == 'Loss') stat.losses++; else stat.draws++;
    }
    final topOpenings = openingMap.values.toList()
      ..sort((a, b) => b.total.compareTo(a.total));

    // ── Mistake patterns from analysis ──
    final movePhaseCounts = <String, Map<String, int>>{
      'Opening (1-15)': {'blunder': 0, 'mistake': 0, 'inaccuracy': 0},
      'Middlegame (16-35)': {'blunder': 0, 'mistake': 0, 'inaccuracy': 0},
      'Endgame (36+)': {'blunder': 0, 'mistake': 0, 'inaccuracy': 0},
    };
    for (final g in games) {
      for (final m in g.analysis) {
        if (m.quality == 'blunder' || m.quality == 'mistake' || m.quality == 'inaccuracy') {
          final phase = m.moveNumber <= 15
              ? 'Opening (1-15)'
              : m.moveNumber <= 35
                  ? 'Middlegame (16-35)'
                  : 'Endgame (36+)';
          movePhaseCounts[phase]![m.quality] = (movePhaseCounts[phase]![m.quality] ?? 0) + 1;
        }
      }
    }
    final patterns = <_MistakePattern>[];
    for (final entry in movePhaseCounts.entries) {
      final blunders = entry.value['blunder'] ?? 0;
      final mistakes = entry.value['mistake'] ?? 0;
      final inaccuracies = entry.value['inaccuracy'] ?? 0;
      if (blunders > 0) patterns.add(_MistakePattern('Blunders in ${entry.key}', '❌', 'blunder', blunders));
      if (mistakes > 0) patterns.add(_MistakePattern('Mistakes in ${entry.key}', '⚠️', 'mistake', mistakes));
      if (inaccuracies > 0) patterns.add(_MistakePattern('Inaccuracies in ${entry.key}', '💛', 'inaccuracy', inaccuracies));
    }
    patterns.sort((a, b) => b.count.compareTo(a.count));

    // ── Strengths & weaknesses ──
    final sw = <_SwItem>[];
    if (topOpenings.isNotEmpty) {
      final best = topOpenings.where((o) => o.total >= 3).toList()
        ..sort((a, b) => (b.wins / b.total).compareTo(a.wins / a.total));
      final worst = topOpenings.where((o) => o.total >= 3).toList()
        ..sort((a, b) => (a.wins / a.total).compareTo(b.wins / b.total));
      if (best.isNotEmpty && best.first.wins / best.first.total >= 0.5) {
        sw.add(_SwItem('Best opening: ${best.first.name} (${(best.first.wins / best.first.total * 100).toStringAsFixed(0)}% win rate)', true));
      }
      if (worst.isNotEmpty && worst.first.wins / worst.first.total < 0.4) {
        sw.add(_SwItem('Struggling with: ${worst.first.name} (${(worst.first.wins / worst.first.total * 100).toStringAsFixed(0)}% win rate)', false));
      }
    }
    final whiteRate = (wW + wL + wD) == 0 ? 0.0 : wW / (wW + wL + wD);
    final blackRate = (bW + bL + bD) == 0 ? 0.0 : bW / (bW + bL + bD);
    if (whiteRate > blackRate + 0.1) {
      sw.add(_SwItem('Stronger as White (${(whiteRate * 100).toStringAsFixed(0)}%) than Black (${(blackRate * 100).toStringAsFixed(0)}%)', true));
    } else if (blackRate > whiteRate + 0.1) {
      sw.add(_SwItem('Stronger as Black (${(blackRate * 100).toStringAsFixed(0)}%) than White (${(whiteRate * 100).toStringAsFixed(0)}%)', true));
    }
    if (patterns.isNotEmpty) {
      final worstPhase = patterns.first;
      sw.add(_SwItem('Most errors in the ${worstPhase.label.split(' in ').last} — ${worstPhase.count} ${worstPhase.quality}s', false));
    }
    if (blunderStreak >= 3) {
      sw.add(_SwItem('$blunderStreak consecutive games without a blunder — great tactical focus!', true));
    }

    // ── Tactical blind spots ──
    final tacticalBlindSpots = <String, int>{};
    for (final g in games) {
      for (final a in g.analysis) {
        if (a.motif != null && a.motif!.isNotEmpty &&
            (a.quality == 'blunder' || a.quality == 'mistake')) {
          tacticalBlindSpots[a.motif!] = (tacticalBlindSpots[a.motif!] ?? 0) + 1;
        }
      }
    }

    // ── Endgame Conversion Rate ──
    // "Opportunity": game reached endgame phase (any analysed move at move 36+)
    //   AND no blunder/mistake before the endgame
    int endgameOpportunities = 0;
    int endgameWins = 0;
    for (final g in games) {
      if (g.analysis.isEmpty) continue;
      final hasEndgameMoves = g.analysis.any((a) => a.moveNumber >= 36);
      if (!hasEndgameMoves) continue;
      // Check: no blunder/mistake in opening or middlegame
      final cleanEarlyGame = !g.analysis.any((a) =>
          a.moveNumber < 36 &&
          (a.quality == 'blunder' || a.quality == 'mistake'));
      if (!cleanEarlyGame) continue;
      // Reached endgame from an equal/winning position with clean play
      endgameOpportunities++;
      if (g.resultDisplay == 'Win') endgameWins++;
    }

    // ── Time pressure blunder rate ──
    int tpBlunders = 0, tpMoves = 0;
    int normalBlunders = 0, normalMoves = 0;
    int timePressureGames = 0;
    for (final g in games) {
      if (g.analysis.isEmpty || g.clockSeconds.isEmpty) continue;
      timePressureGames++;
      for (final a in g.analysis) {
        if (a.quality == 'blunder' || a.quality == 'mistake') {
          if (a.timePressure) {
            tpBlunders++;
          } else {
            normalBlunders++;
          }
        }
        if (a.timePressure) tpMoves++;
        else normalMoves++;
      }
    }
    // Rate = blunders per 10 analysed moves (to make numbers comparable)
    final tpRate = tpMoves == 0 ? 0.0 : (tpBlunders / tpMoves) * 10;
    final normalRate = normalMoves == 0 ? 0.0 : (normalBlunders / normalMoves) * 10;

    // ── Tilt pattern ──
    // Sort chronologically to find games played within 24h of a loss
    final chronoSorted = List<ChessGame>.from(games)
      ..sort((a, b) => a.datePlayed.compareTo(b.datePlayed));

    int tiltWins = 0, tiltTotal = 0, normalWins = 0, normalTotal = 0;
    DateTime? lastLoss;
    for (final g in chronoSorted) {
      final isTilt = lastLoss != null &&
          g.datePlayed.difference(lastLoss!).inHours.abs() <= 24;
      final r = g.resultDisplay;
      if (isTilt) {
        tiltTotal++;
        if (r == 'Win') tiltWins++;
      } else {
        normalTotal++;
        if (r == 'Win') normalWins++;
      }
      if (r == 'Loss') lastLoss = g.datePlayed;
    }

    return _RichStats(
      currentStreak: streak,
      whiteW: wW, whiteL: wL, whiteD: wD,
      blackW: bW, blackL: bL, blackD: bD,
      winRateTrend: winRateTrend,
      ratingPoints: ratingPoints,
      errorTrend: errorTrend,
      blunderTrend: blunderTrend,
      topOpenings: topOpenings.take(5).toList(),
      mistakePatterns: patterns.take(6).toList(),
      strengthsWeaknesses: sw,
      blunderStreakGames: blunderStreak,
      tiltWinRate: tiltTotal == 0 ? 0 : tiltWins / tiltTotal,
      normalWinRate: normalTotal == 0 ? 0 : normalWins / normalTotal,
      tiltGames: tiltTotal,
      endgameConversionRate: endgameOpportunities == 0 ? 0 : endgameWins / endgameOpportunities,
      endgameOpportunities: endgameOpportunities,
      tacticalBlindSpots: tacticalBlindSpots,
      timePressureBlunderRate: tpRate,
      normalBlunderRate: normalRate,
      timePressureGames: timePressureGames,
    );
  }
}
