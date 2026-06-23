import 'package:flutter_test/flutter_test.dart';
import 'package:chessdiary/models/game_model.dart';

void main() {
  // Full base map with every current field
  final base = <String, dynamic>{
    'playerName': 'Alice',
    'opponentName': 'Bob',
    'result': '1-0',
    'playerColor': 'white',
    'moves': ['e4', 'e5', 'Nf3', 'Nc6'],
    'pgn': '1. e4 e5 2. Nf3 Nc6',
    'datePlayed': '2024-03-15T10:00:00.000',
    'source': 'chess.com',
    'event': 'Club Championship',
    'opening': 'Italian Game',
    'analysis': <dynamic>[],
    'imageUrl': null,
    'playerRating': 1500,
    'opponentRating': 1450,
    'notes': 'Great game',
    'tags': ['tactics', 'opening'],
    'timeControl': 'rapid',
    'evalCurve': [20, 30, -50, 100],
    'clockSeconds': [180, 175, 170, 165],
  };

  Map<String, dynamic> m(Map<String, dynamic> overrides) =>
      {...base, ...overrides};

  // ── ChessGame.fromMap ─────────────────────────────────────────────────────

  group('ChessGame.fromMap', () {
    test('parses all fields correctly', () {
      final g = ChessGame.fromMap(base, 'test-id');
      expect(g.id, 'test-id');
      expect(g.playerName, 'Alice');
      expect(g.opponentName, 'Bob');
      expect(g.result, '1-0');
      expect(g.playerColor, 'white');
      expect(g.moves, ['e4', 'e5', 'Nf3', 'Nc6']);
      expect(g.source, 'chess.com');
      expect(g.opening, 'Italian Game');
      expect(g.playerRating, 1500);
      expect(g.notes, 'Great game');
      expect(g.tags, ['tactics', 'opening']);
      expect(g.timeControl, 'rapid');
      expect(g.evalCurve, [20, 30, -50, 100]);
      expect(g.clockSeconds, [180, 175, 170, 165]);
    });

    test('handles missing optional fields gracefully', () {
      final minimal = {
        'playerName': 'Alice',
        'opponentName': 'Bob',
        'result': '*',
        'playerColor': 'white',
        'moves': <String>[],
        'pgn': '',
        'datePlayed': '2024-01-01T00:00:00.000',
        'source': 'paper',
      };
      final g = ChessGame.fromMap(minimal, 'id');
      expect(g.notes, isNull);
      expect(g.tags, isEmpty);
      expect(g.timeControl, isNull);
      expect(g.evalCurve, isEmpty);
      expect(g.clockSeconds, isEmpty);
      expect(g.analysis, isEmpty);
    });

    test('parses analysis blocks including new fields', () {
      final withAnalysis = m({
        'analysis': [
          {
            'moveNumber': 5,
            'move': 'Nf3',
            'quality': 'best',
            'motif': null,
            'timePressure': false,
          },
          {
            'moveNumber': 14,
            'move': 'Bxf7',
            'quality': 'blunder',
            'centipawnLoss': 300.0,
            'motif': 'sacrifice',
            'timePressure': true,
          },
        ],
      });
      final g = ChessGame.fromMap(withAnalysis, 'id');
      expect(g.analysis.length, 2);
      expect(g.analysis[0].motif, isNull);
      expect(g.analysis[0].timePressure, isFalse);
      expect(g.analysis[1].motif, 'sacrifice');
      expect(g.analysis[1].timePressure, isTrue);
    });
  });

  // ── ChessGame.toMap ───────────────────────────────────────────────────────

  group('ChessGame.toMap', () {
    test('round-trips all fields through fromMap → toMap', () {
      final original = ChessGame.fromMap(base, 'id');
      final roundTripped = ChessGame.fromMap(original.toMap(), 'id');
      expect(roundTripped.playerName, original.playerName);
      expect(roundTripped.notes, original.notes);
      expect(roundTripped.tags, original.tags);
      expect(roundTripped.timeControl, original.timeControl);
      expect(roundTripped.evalCurve, original.evalCurve);
      expect(roundTripped.clockSeconds, original.clockSeconds);
    });

    test('toMap contains all expected keys including new ones', () {
      final map = ChessGame.fromMap(base, 'id').toMap();
      for (final key in [
        'playerName', 'opponentName', 'result', 'playerColor',
        'moves', 'pgn', 'datePlayed', 'source', 'analysis',
        'tags', 'timeControl', 'evalCurve', 'clockSeconds',
      ]) {
        expect(map.containsKey(key), isTrue, reason: 'Missing key: $key');
      }
    });
  });

  // ── ChessGame.copyWith ────────────────────────────────────────────────────

  group('ChessGame.copyWith', () {
    late ChessGame original;
    setUp(() => original = ChessGame.fromMap(base, 'id'));

    test('updating notes does not lose other fields', () {
      final updated = original.copyWith(notes: 'New note');
      expect(updated.notes, 'New note');
      expect(updated.playerName, original.playerName);
      expect(updated.moves, original.moves);
      expect(updated.timeControl, original.timeControl);
      expect(updated.evalCurve, original.evalCurve);
      expect(updated.clockSeconds, original.clockSeconds);
    });

    test('updating tags does not lose notes or timeControl', () {
      final updated = original.copyWith(tags: ['endgame']);
      expect(updated.tags, ['endgame']);
      expect(updated.notes, original.notes);
      expect(updated.timeControl, original.timeControl);
    });

    test('updating evalCurve does not lose clockSeconds', () {
      final newCurve = [1, 2, 3];
      final updated = original.copyWith(evalCurve: newCurve);
      expect(updated.evalCurve, newCurve);
      expect(updated.clockSeconds, original.clockSeconds);
    });

    test('updating clockSeconds does not lose evalCurve', () {
      final newClocks = [60, 55, 50];
      final updated = original.copyWith(clockSeconds: newClocks);
      expect(updated.clockSeconds, newClocks);
      expect(updated.evalCurve, original.evalCurve);
    });

    test('updating analysis does not lose any other field', () {
      final analysis = [MoveAnalysis(moveNumber: 1, move: 'e4', quality: 'best')];
      final updated = original.copyWith(analysis: analysis);
      expect(updated.analysis.length, 1);
      expect(updated.timeControl, original.timeControl);
      expect(updated.notes, original.notes);
    });
  });

  // ── resultDisplay ────────────────────────────────────────────────────────

  group('ChessGame.resultDisplay', () {
    test('white 1-0 → Win', () => expect(ChessGame.fromMap(m({'playerColor': 'white', 'result': '1-0'}), 'id').resultDisplay, 'Win'));
    test('white 0-1 → Loss', () => expect(ChessGame.fromMap(m({'playerColor': 'white', 'result': '0-1'}), 'id').resultDisplay, 'Loss'));
    test('white 1/2 → Draw', () => expect(ChessGame.fromMap(m({'result': '1/2-1/2'}), 'id').resultDisplay, 'Draw'));
    test('black 0-1 → Win', () => expect(ChessGame.fromMap(m({'playerColor': 'black', 'result': '0-1'}), 'id').resultDisplay, 'Win'));
    test('black 1-0 → Loss', () => expect(ChessGame.fromMap(m({'playerColor': 'black', 'result': '1-0'}), 'id').resultDisplay, 'Loss'));
    test('unknown result → Draw', () => expect(ChessGame.fromMap(m({'result': '*'}), 'id').resultDisplay, 'Draw'));
  });

  // ── MoveAnalysis ────────────────────────────────────────────────────────

  group('MoveAnalysis', () {
    test('fromMap parses all fields including motif and timePressure', () {
      final a = MoveAnalysis.fromMap({
        'moveNumber': 18,
        'move': 'Rxe5',
        'quality': 'blunder',
        'comment': 'Hangs the rook',
        'centipawnLoss': 280.0,
        'motif': 'hanging_piece',
        'timePressure': true,
      });
      expect(a.moveNumber, 18);
      expect(a.quality, 'blunder');
      expect(a.motif, 'hanging_piece');
      expect(a.timePressure, isTrue);
      expect(a.centipawnLoss, 280.0);
    });

    test('fromMap defaults timePressure to false when absent', () {
      final a = MoveAnalysis.fromMap({'moveNumber': 1, 'move': 'e4', 'quality': 'best'});
      expect(a.timePressure, isFalse);
      expect(a.motif, isNull);
    });

    test('phase getter — opening (moves 1-15)', () {
      expect(MoveAnalysis(moveNumber: 1, move: 'e4', quality: 'good').phase, 'opening');
      expect(MoveAnalysis(moveNumber: 15, move: 'O-O', quality: 'good').phase, 'opening');
    });

    test('phase getter — middlegame (moves 16-35)', () {
      expect(MoveAnalysis(moveNumber: 16, move: 'Nc3', quality: 'good').phase, 'middlegame');
      expect(MoveAnalysis(moveNumber: 35, move: 'Rg1', quality: 'good').phase, 'middlegame');
    });

    test('phase getter — endgame (moves 36+)', () {
      expect(MoveAnalysis(moveNumber: 36, move: 'Ke2', quality: 'good').phase, 'endgame');
      expect(MoveAnalysis(moveNumber: 99, move: 'a8=Q', quality: 'good').phase, 'endgame');
    });

    test('toMap round-trips including new fields', () {
      final original = MoveAnalysis(
        moveNumber: 12,
        move: 'Ng5',
        quality: 'mistake',
        comment: 'Too aggressive',
        centipawnLoss: 120.0,
        motif: 'fork',
        timePressure: true,
      );
      final back = MoveAnalysis.fromMap(original.toMap());
      expect(back.motif, 'fork');
      expect(back.timePressure, isTrue);
      expect(back.centipawnLoss, 120.0);
    });
  });
}
