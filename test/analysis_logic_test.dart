import 'package:flutter_test/flutter_test.dart';
import 'package:chessdiary/models/game_model.dart';
import 'package:chessdiary/services/chess_insights.dart';

// Helper: build a minimal ChessGame
ChessGame _game({
  String result = '1-0',
  String color = 'white',
  String? opening,
  String? timeControl,
  List<MoveAnalysis> analysis = const [],
  List<int> evalCurve = const [],
}) =>
    ChessGame(
      id: 'test',
      playerName: 'Me',
      opponentName: 'Opp',
      result: result,
      playerColor: color,
      moves: [],
      pgn: '',
      datePlayed: DateTime(2024),
      source: 'paper',
      opening: opening,
      analysis: analysis,
      evalCurve: evalCurve,
      timeControl: timeControl,
    );

MoveAnalysis _move(int num, String quality, {String? motif}) =>
    MoveAnalysis(moveNumber: num, move: 'e4', quality: quality, motif: motif);

void main() {
  // ── Phase classification ────────────────────────────────────────────────

  group('ChessInsights.phaseForMove', () {
    test('move 1 → opening', () => expect(ChessInsights.phaseForMove(1), 'opening'));
    test('move 15 → opening', () => expect(ChessInsights.phaseForMove(15), 'opening'));
    test('move 16 → middlegame', () => expect(ChessInsights.phaseForMove(16), 'middlegame'));
    test('move 35 → middlegame', () => expect(ChessInsights.phaseForMove(35), 'middlegame'));
    test('move 36 → endgame', () => expect(ChessInsights.phaseForMove(36), 'endgame'));
    test('move 100 → endgame', () => expect(ChessInsights.phaseForMove(100), 'endgame'));
    test('boundary 15/16 is correctly split', () {
      expect(ChessInsights.phaseForMove(15), isNot('middlegame'));
      expect(ChessInsights.phaseForMove(16), isNot('opening'));
    });
  });

  // ── Endgame Conversion Rate ─────────────────────────────────────────────

  group('ChessInsights.endgameConversionRate', () {
    test('zero games → rate is null (no data, no divide-by-zero)', () {
      final r = ChessInsights.endgameConversionRate([]);
      expect(r.rate, isNull);
      expect(r.opportunities, 0);
    });

    test('no games with endgame moves → rate is null', () {
      final games = [
        _game(result: '1-0', analysis: [_move(10, 'good'), _move(20, 'good')]),
      ];
      final r = ChessInsights.endgameConversionRate(games);
      expect(r.rate, isNull);
    });

    test('game with blunder before endgame does NOT qualify', () {
      final games = [
        _game(
          result: '1-0',
          analysis: [_move(14, 'blunder'), _move(40, 'good')],
        ),
      ];
      final r = ChessInsights.endgameConversionRate(games);
      expect(r.opportunities, 0);
      expect(r.rate, isNull);
    });

    test('game with clean play reaching endgame and winning → 100%', () {
      final games = [
        _game(
          result: '1-0',
          analysis: [_move(10, 'good'), _move(40, 'good')],
        ),
      ];
      final r = ChessInsights.endgameConversionRate(games);
      expect(r.opportunities, 1);
      expect(r.wins, 1);
      expect(r.rate, 1.0);
    });

    test('2 qualifying games: 1 win 1 loss → 50%', () {
      final games = [
        _game(result: '1-0', analysis: [_move(10, 'good'), _move(40, 'good')]),
        _game(result: '0-1', analysis: [_move(12, 'good'), _move(38, 'inaccuracy')]),
      ];
      final r = ChessInsights.endgameConversionRate(games);
      expect(r.opportunities, 2);
      expect(r.wins, 1);
      expect(r.rate, closeTo(0.5, 0.001));
    });

    test('game without analysis does not count', () {
      final games = [_game(result: '1-0')]; // no analysis
      final r = ChessInsights.endgameConversionRate(games);
      expect(r.opportunities, 0);
    });
  });

  // ── Critical Moment detection ───────────────────────────────────────────

  group('ChessInsights.detectTurningPoints', () {
    test('empty eval curve → no turning points', () {
      final pts = ChessInsights.detectTurningPoints(
        evalCurve: [],
        playerColor: 'white',
        flaggedMoveNumbers: {},
      );
      expect(pts, isEmpty);
    });

    test('flat eval → no turning points', () {
      final curve = List.filled(20, 50);
      final pts = ChessInsights.detectTurningPoints(
        evalCurve: curve,
        playerColor: 'white',
        flaggedMoveNumbers: {},
      );
      expect(pts, isEmpty);
    });

    test('≥150cp drift in window → turning point detected', () {
      // White starts at +200, drops to +20 over 6 half-moves = swing of 180
      final curve = [200, 180, 150, 100, 60, 30, 20, 20, 20, 20];
      final pts = ChessInsights.detectTurningPoints(
        evalCurve: curve,
        playerColor: 'white',
        flaggedMoveNumbers: {},
      );
      expect(pts, isNotEmpty);
      expect(pts.first.swingCp, greaterThanOrEqualTo(150));
    });

    test('drift < 150cp → no turning point', () {
      final curve = [200, 190, 180, 170, 160, 155, 152, 150, 148, 145];
      final pts = ChessInsights.detectTurningPoints(
        evalCurve: curve,
        playerColor: 'white',
        flaggedMoveNumbers: {},
      );
      expect(pts, isEmpty);
    });

    test('flagged blunder in same window → NOT flagged as critical moment', () {
      final curve = [200, 180, 150, 100, 60, 30, 20, 20, 20, 20];
      // move 1 is in the window (half-moves 0-5 → full moves 1-3)
      final pts = ChessInsights.detectTurningPoints(
        evalCurve: curve,
        playerColor: 'white',
        flaggedMoveNumbers: {1}, // blunder already captured
      );
      expect(pts, isEmpty);
    });

    test('black player: positive eval for black = player winning', () {
      // Eval in white's terms: -200 means black is winning.
      // Drift from -200 to -50 for black = good for white = bad for black
      final curve = [-200, -180, -150, -100, -60, -30, -50, -50, -50, -50];
      final pts = ChessInsights.detectTurningPoints(
        evalCurve: curve,
        playerColor: 'black',
        flaggedMoveNumbers: {},
      );
      expect(pts, isNotEmpty);
    });
  });

  // ── Tactical Blind Spots ────────────────────────────────────────────────

  group('ChessInsights.tacticalBlindSpots', () {
    test('no analysed games → empty list', () {
      expect(ChessInsights.tacticalBlindSpots([]), isEmpty);
    });

    test('games with no motifs → empty list', () {
      final games = [
        _game(analysis: [_move(5, 'blunder')]), // no motif
      ];
      expect(ChessInsights.tacticalBlindSpots(games), isEmpty);
    });

    test('only inaccuracies (not blunder/mistake) → excluded', () {
      final games = [
        _game(analysis: [
          MoveAnalysis(moveNumber: 5, move: 'e4', quality: 'inaccuracy', motif: 'pin'),
        ]),
      ];
      expect(ChessInsights.tacticalBlindSpots(games), isEmpty);
    });

    test('most frequent motif appears first', () {
      final games = [
        _game(analysis: [_move(5, 'blunder', motif: 'fork'), _move(10, 'blunder', motif: 'fork')]),
        _game(analysis: [_move(8, 'mistake', motif: 'pin')]),
        _game(analysis: [_move(12, 'blunder', motif: 'fork')]),
      ];
      final spots = ChessInsights.tacticalBlindSpots(games);
      expect(spots.first.motif, 'fork');
      expect(spots.first.count, 3);
      expect(spots[1].motif, 'pin');
      expect(spots[1].count, 1);
    });

    test('correctly aggregates across multiple games', () {
      final games = List.generate(5, (_) =>
          _game(analysis: [_move(6, 'blunder', motif: 'hanging_piece')]));
      final spots = ChessInsights.tacticalBlindSpots(games);
      expect(spots.length, 1);
      expect(spots.first.motif, 'hanging_piece');
      expect(spots.first.count, 5);
    });
  });

  // ── Opening records & needs-review ────────────────────────────────────

  group('ChessInsights.openingRecords', () {
    test('correct W/L/D tally per opening', () {
      final games = [
        _game(result: '1-0', opening: 'Sicilian'),
        _game(result: '0-1', color: 'white', opening: 'Sicilian'),
        _game(result: '1-0', opening: 'Italian'),
      ];
      final records = ChessInsights.openingRecords(games);
      expect(records['Sicilian']!.wins, 1);
      expect(records['Sicilian']!.losses, 1);
      expect(records['Italian']!.wins, 1);
    });

    test('needsReview true when ≥3 games and <40% win rate', () {
      final r = OpeningRecord('Test')
        ..wins = 1
        ..losses = 4;
      expect(r.needsReview, isTrue); // 20% win rate, 5 games
    });

    test('needsReview false when exactly 40%', () {
      final r = OpeningRecord('Test')
        ..wins = 2
        ..losses = 3;
      expect(r.needsReview, isFalse); // 40% is NOT < 40%
    });

    test('needsReview false when fewer than 3 games', () {
      final r = OpeningRecord('Test')..wins = 0..losses = 2;
      expect(r.needsReview, isFalse);
    });
  });

  // ── Per-time-control win rate ─────────────────────────────────────────

  group('ChessInsights.timeControlRecords', () {
    test('groups games by time control correctly', () {
      final games = [
        _game(result: '1-0', timeControl: 'blitz'),
        _game(result: '1-0', timeControl: 'blitz'),
        _game(result: '0-1', color: 'white', timeControl: 'rapid'),
      ];
      final records = ChessInsights.timeControlRecords(games);
      expect(records['blitz']!.wins, 2);
      expect(records['blitz']!.losses, 0);
      expect(records['rapid']!.losses, 1);
    });

    test('games with no time control → bucketed as unknown', () {
      final games = [_game(result: '1-0')]; // timeControl = null
      final records = ChessInsights.timeControlRecords(games);
      expect(records.containsKey('unknown'), isTrue);
    });
  });
}
