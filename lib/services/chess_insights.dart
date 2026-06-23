/// Pure calculation functions extracted from widget files.
/// No Flutter/Firebase imports — fully unit-testable.
import '../models/game_model.dart';

class ChessInsights {
  // ── Phase classification ──────────────────────────────────────────────────

  static String phaseForMove(int moveNumber) {
    if (moveNumber <= 15) return 'opening';
    if (moveNumber <= 35) return 'middlegame';
    return 'endgame';
  }

  // ── Endgame Conversion Rate ───────────────────────────────────────────────
  //
  // A game "qualifies" when:
  //   - It has analysis data
  //   - There is at least one analysed move at move 36+
  //   - There are NO blunder/mistake in the opening or middlegame phases
  //
  // Rate = qualifying games where player won / total qualifying games.

  static EndgameConversionResult endgameConversionRate(List<ChessGame> games) {
    int opportunities = 0;
    int wins = 0;

    for (final g in games) {
      if (g.analysis.isEmpty) continue;
      final hasEndgameMoves = g.analysis.any((a) => a.moveNumber >= 36);
      if (!hasEndgameMoves) continue;
      final cleanEarlyGame = !g.analysis.any((a) =>
          a.moveNumber < 36 &&
          (a.quality == 'blunder' || a.quality == 'mistake'));
      if (!cleanEarlyGame) continue;
      opportunities++;
      if (g.resultDisplay == 'Win') wins++;
    }

    return EndgameConversionResult(
      opportunities: opportunities,
      wins: wins,
      rate: opportunities == 0 ? null : wins / opportunities,
    );
  }

  // ── Critical Moments (Turning Points) ────────────────────────────────────
  //
  // A turning point is a 6-half-move window where the eval shifts ≥150 cp
  // against the player, with no individually flagged blunder/mistake in
  // that window (otherwise it's already shown as a blunder tile).

  static List<CriticalMoment> detectTurningPoints({
    required List<int> evalCurve,
    required String playerColor,
    required Set<int> flaggedMoveNumbers,
    int windowHalfMoves = 6,
    int thresholdCp = 150,
  }) {
    if (evalCurve.length < windowHalfMoves + 1) return [];

    final isWhite = playerColor == 'white';
    final points = <CriticalMoment>[];

    for (int i = 0; i + windowHalfMoves < evalCurve.length; i++) {
      final before = isWhite ? evalCurve[i].toDouble() : -evalCurve[i].toDouble();
      final after = isWhite
          ? evalCurve[i + windowHalfMoves].toDouble()
          : -evalCurve[i + windowHalfMoves].toDouble();
      final swing = before - after; // positive = things got worse for player

      if (swing >= thresholdCp) {
        final moveNum = i ~/ 2 + 1;
        final hasFlagged = flaggedMoveNumbers
            .any((m) => m >= moveNum && m <= moveNum + windowHalfMoves ~/ 2);
        if (!hasFlagged) {
          points.add(CriticalMoment(
            moveStart: moveNum,
            moveEnd: moveNum + windowHalfMoves ~/ 2,
            swingCp: swing.toInt(),
          ));
          break; // one per game for now
        }
      }
    }
    return points;
  }

  // ── Tactical Blind Spots ─────────────────────────────────────────────────
  //
  // Aggregates motifs from blunders/mistakes across all analysed games,
  // returning a list sorted by frequency (highest first).

  static List<BlindSpot> tacticalBlindSpots(List<ChessGame> games) {
    final counts = <String, int>{};
    for (final g in games) {
      for (final a in g.analysis) {
        if (a.motif == null) continue;
        if (a.quality != 'blunder' && a.quality != 'mistake') continue;
        counts[a.motif!] = (counts[a.motif!] ?? 0) + 1;
      }
    }
    final spots = counts.entries
        .map((e) => BlindSpot(motif: e.key, count: e.value))
        .toList()
      ..sort((a, b) => b.count.compareTo(a.count));
    return spots;
  }

  // ── Per-opening win rate ──────────────────────────────────────────────────

  static Map<String, OpeningRecord> openingRecords(List<ChessGame> games) {
    final records = <String, OpeningRecord>{};
    for (final g in games) {
      final op = g.opening;
      if (op == null || op.isEmpty) continue;
      final r = records.putIfAbsent(op, () => OpeningRecord(op));
      switch (g.resultDisplay) {
        case 'Win':
          r.wins++;
          break;
        case 'Loss':
          r.losses++;
          break;
        default:
          r.draws++;
      }
    }
    return records;
  }

  // ── Per-time-control win rate ─────────────────────────────────────────────

  static Map<String, OpeningRecord> timeControlRecords(List<ChessGame> games) {
    final records = <String, OpeningRecord>{};
    for (final g in games) {
      final tc = g.timeControl ?? 'unknown';
      final r = records.putIfAbsent(tc, () => OpeningRecord(tc));
      switch (g.resultDisplay) {
        case 'Win':
          r.wins++;
          break;
        case 'Loss':
          r.losses++;
          break;
        default:
          r.draws++;
      }
    }
    return records;
  }
}

// ── Value objects ─────────────────────────────────────────────────────────

class EndgameConversionResult {
  final int opportunities;
  final int wins;
  final double? rate; // null = no data (0 qualifying games)

  const EndgameConversionResult({
    required this.opportunities,
    required this.wins,
    required this.rate,
  });
}

class CriticalMoment {
  final int moveStart;
  final int moveEnd;
  final int swingCp;
  const CriticalMoment({
    required this.moveStart,
    required this.moveEnd,
    required this.swingCp,
  });
}

class BlindSpot {
  final String motif;
  final int count;
  const BlindSpot({required this.motif, required this.count});
}

class OpeningRecord {
  final String name;
  int wins = 0, losses = 0, draws = 0;
  OpeningRecord(this.name);

  int get total => wins + losses + draws;
  double get winRate => total == 0 ? 0.0 : wins / total;

  /// Opening needs review: ≥3 games AND < 40% win rate.
  bool get needsReview => total >= 3 && winRate < 0.4;
}
