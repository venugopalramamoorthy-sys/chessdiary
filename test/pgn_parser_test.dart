import 'package:flutter_test/flutter_test.dart';
import 'package:chessdiary/services/pgn_parser.dart';

void main() {
  const fullPgn = '''
[Event "Club Championship"]
[White "Alice"]
[Black "Bob"]
[Result "1-0"]
[WhiteElo "1500"]
[BlackElo "1450"]
[Date "2024.03.15"]
[Opening "Ruy Lopez"]

1. e4 { [%clk 0:05:00] } e5 { [%clk 0:05:00] } 2. Nf3 { [%clk 0:04:50] } Nc6 { [%clk 0:04:45] } 3. Bb5 { [%clk 0:04:30] } a6 { [%clk 0:00:25] } 4. Ba4 { [%clk 0:04:10] } Nf6 { [%clk 0:00:10] } 1-0
''';

  group('PgnParser.parse — headers', () {
    test('parses White and Black names', () {
      final r = PgnParser.parse(fullPgn);
      expect(r['playerWhite'], 'Alice');
      expect(r['playerBlack'], 'Bob');
    });
    test('parses result', () => expect(PgnParser.parse(fullPgn)['result'], '1-0'));
    test('parses event', () => expect(PgnParser.parse(fullPgn)['event'], 'Club Championship'));
    test('parses Elo as ints', () {
      final r = PgnParser.parse(fullPgn);
      expect(r['ratingWhite'], 1500);
      expect(r['ratingBlack'], 1450);
    });
    test('parses date with dashes', () => expect(PgnParser.parse(fullPgn)['date'], '2024-03-15'));
    test('parses opening', () => expect(PgnParser.parse(fullPgn)['opening'], 'Ruy Lopez'));
    test('sets parseConfidence to high', () => expect(PgnParser.parse(fullPgn)['parseConfidence'], 'high'));
  });

  group('PgnParser.parse — move extraction', () {
    test('extracts correct moves', () {
      final moves = PgnParser.parse(fullPgn)['moves'] as List<String>;
      expect(moves, containsAll(['e4', 'e5', 'Nf3', 'Nc6', 'Bb5', 'a6', 'Ba4', 'Nf6']));
    });
    test('strips move numbers', () {
      final moves = PgnParser.parse(fullPgn)['moves'] as List<String>;
      expect(moves, everyElement(isNot(matches(RegExp(r'^\d+\.+$')))));
    });
    test('strips result token', () {
      final moves = PgnParser.parse(fullPgn)['moves'] as List<String>;
      expect(moves, isNot(contains('1-0')));
    });
    test('strips inline comments', () {
      const withComments = '1. e4 {Good move} e5 {Classical} 2. Nf3 *';
      final moves = PgnParser.parse(withComments)['moves'] as List<String>;
      expect(moves, everyElement(isNot(contains('{'))));
    });
  });

  group('PgnParser.extractClockSeconds — h:mm:ss format', () {
    test('extracts clock for every half-move', () {
      final clocks = PgnParser.extractClockSeconds(fullPgn);
      // 8 half-moves → 8 clock entries
      expect(clocks.length, 8);
    });
    test('first clock is 5 minutes (300s)', () {
      final clocks = PgnParser.extractClockSeconds(fullPgn);
      expect(clocks[0], 300);
    });
    test('detects time pressure (< 30s) at move 6 (black, 25s)', () {
      final clocks = PgnParser.extractClockSeconds(fullPgn);
      // half-move index 5 = black's 3rd move = 25 seconds
      expect(clocks[5], 25);
      expect(clocks[5] < 30, isTrue);
    });
    test('detects critical time pressure (10s) at half-move 7', () {
      final clocks = PgnParser.extractClockSeconds(fullPgn);
      expect(clocks[7], 10);
    });
    test('returns empty list for PGN without clock annotations', () {
      const noClock = '1. e4 e5 2. Nf3 *';
      expect(PgnParser.extractClockSeconds(noClock), isEmpty);
    });
  });

  group('PgnParser.extractClockSeconds — mm:ss short format', () {
    test('parses mm:ss without hours', () {
      const pgn = '1. e4 { [%clk 3:45] } e5 { [%clk 3:40] } *';
      final clocks = PgnParser.extractClockSeconds(pgn);
      expect(clocks.length, 2);
      expect(clocks[0], 225); // 3*60 + 45
      expect(clocks[1], 220);
    });
  });

  group('PgnParser.parse — edge cases', () {
    test('minimal PGN with no headers', () {
      const minimal = '1. d4 d5 *';
      final r = PgnParser.parse(minimal);
      expect(r['playerWhite'], 'Unknown');
      expect(r['result'], '*');
      expect((r['moves'] as List).length, greaterThan(0));
    });

    test('unknown date placeholder excluded', () {
      const pgn = '[Date "????.??.??"]\n\n1. e4 *';
      expect(PgnParser.parse(pgn)['date'], isNull);
    });

    test('0-1 result preserved', () {
      const pgn = '[Result "0-1"]\n\n1. e4 e5 0-1';
      expect(PgnParser.parse(pgn)['result'], '0-1');
    });

    test('draw result preserved', () {
      const pgn = '[Result "1/2-1/2"]\n\n1. e4 e5 1/2-1/2';
      expect(PgnParser.parse(pgn)['result'], '1/2-1/2');
    });

    test('ECO fallback when Opening absent', () {
      const pgn = '[ECO "C60"]\n\n1. e4 e5 *';
      expect(PgnParser.parse(pgn)['opening'], 'C60');
    });

    test('malformed PGN with no moves returns empty move list', () {
      const pgn = '[White "Alice"]\n[Black "Bob"]\n[Result "*"]\n\n*';
      final r = PgnParser.parse(pgn);
      expect(r['moves'], isEmpty);
      expect(r['result'], '*');
    });

    test('NAG annotations stripped from moves', () {
      const pgn = '1. e4\$1 e5\$2 *';
      final moves = PgnParser.parse(pgn)['moves'] as List<String>;
      expect(moves, everyElement(isNot(contains(r'$'))));
    });

    test('totalMoves matches move list length', () {
      final r = PgnParser.parse(fullPgn);
      expect(r['totalMoves'], (r['moves'] as List).length);
    });
  });
}
