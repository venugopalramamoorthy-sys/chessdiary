import 'dart:math';

import 'package:chessdiary/models/game_model.dart';
import 'package:chessdiary/services/public_report_service.dart';
import 'package:flutter_test/flutter_test.dart';

// Morphy's Opera Game, padded past the 20-move publishing minimum is not
// needed for these unit checks -- eligibility is tested separately.
const opera = [
  'e4', 'e5', 'Nf3', 'd6', 'd4', 'Bg4', 'dxe5', 'Bxf3', 'Qxf3', 'dxe5',
  'Bc4', 'Nf6', 'Qb3', 'Qe7', 'Nc3', 'c6', 'Bg5', 'b5', 'Nxb5', 'cxb5',
  'Bxb5+', 'Nbd7', 'O-O-O', 'Rd8', 'Rxd7', 'Rxd7', 'Rd1', 'Qe6', 'Bxd7+',
  'Nxd7', 'Qb8+', 'Nxb8', 'Rd8#',
];

ChessGame game({
  List<String> moves = opera,
  List<MoveAnalysis>? analysis,
  String source = 'paper',
  String playerColor = 'black',
  String opponent = 'Ravi Kumar',
  String? event = 'Chennai Open 2026',
  List<int>? evalCurve,
}) =>
    ChessGame(
      id: 'g1',
      playerName: 'Me',
      opponentName: opponent,
      result: '1-0',
      playerColor: playerColor,
      moves: moves,
      pgn: '',
      datePlayed: DateTime(2026, 10, 12),
      source: source,
      event: event,
      opening: 'Philidor Defence',
      playerRating: 1650,
      opponentRating: 1720,
      analysis: analysis ??
          [
            MoveAnalysis(moveNumber: 3, move: 'Bg4', quality: 'inaccuracy', centipawnLoss: 60),
            MoveAnalysis(moveNumber: 9, move: 'b5', quality: 'mistake', centipawnLoss: 180, motif: 'pin'),
            MoveAnalysis(moveNumber: 14, move: 'Qe6', quality: 'blunder', centipawnLoss: 420),
            MoveAnalysis(moveNumber: 2, move: 'Nf3', quality: 'good', centipawnLoss: 5),
            MoveAnalysis(moveNumber: 17, move: 'Rd8#', quality: 'checkmate', centipawnLoss: 0),
          ],
      evalCurve: evalCurve ?? List.filled(opera.length, 0),
    );

void main() {
  group('plyFor', () {
    test('finds White and Black moves from full-move numbers', () {
      final g = game();
      expect(PublicReportService.plyFor(g, MoveAnalysis(moveNumber: 2, move: 'Nf3', quality: 'good')), 2);
      expect(PublicReportService.plyFor(g, MoveAnalysis(moveNumber: 3, move: 'Bg4', quality: 'good')), 5);
      expect(PublicReportService.plyFor(g, MoveAnalysis(moveNumber: 3, move: 'Nf6', quality: 'good')), isNull);
    });
  });

  group('pickMoments', () {
    test('keeps only real errors, in game order, with the position before the move', () {
      final moments = PublicReportService.pickMoments(game());
      expect(moments.map((m) => m.ply), [5, 17, 27]);
      // Before 3...Bg4: after 1.e4 e5 2.Nf3 d6 3.d4, Black to move.
      expect(moments.first.fen, 'rnbqkbnr/ppp2ppp/3p4/4p3/3PP3/5N2/PPP2PPP/RNBQKB1R b KQkq d3 0 3');
    });

    test('caps at the five worst moves', () {
      final analysis = [
        for (var i = 0; i < 8; i++)
          MoveAnalysis(moveNumber: i + 1, move: opera[i * 2], quality: 'inaccuracy', centipawnLoss: 10.0 * (i + 1)),
      ];
      final moments = PublicReportService.pickMoments(game(analysis: analysis));
      expect(moments.length, PublicReportService.maxMoments);
      expect(moments.map((m) => m.ply), [6, 8, 10, 12, 14]);
    });

    test('accepts scoresheet notation without check marks or with zero castling', () {
      final sloppy = [...opera]
        ..[20] = 'Bxb5'
        ..[22] = '0-0-0';
      final fens = PublicReportService.fensBefore(sloppy, {27});
      expect(fens[27], isNotNull, reason: 'replay should get past Bxb5 and 0-0-0');
    });

    test('stops at an illegal move instead of inventing positions', () {
      final broken = [...opera]..[4] = 'Ke2';
      expect(PublicReportService.fensBefore(broken, {3, 10}).keys, [3]);
    });
  });

  group('buildReport privacy', () {
    Map<String, dynamic> build(ChessGame g, {bool showOpponent = true, bool showEvent = false}) =>
        PublicReportService.buildReport(
          game: g,
          slug: '2026-10-philidor-defence-abc234',
          ownerUid: 'uid1',
          authorName: '  KnightOwl ',
          showOpponentName: showOpponent,
          showEvent: showEvent,
          notes: 'notes',
          moments: PublicReportService.pickMoments(g),
          comments: const ['a', 'b'],
        );

    test('paper games never name the opponent and show only the month', () {
      final r = build(game());
      expect(r['whiteName'], 'Opponent');
      expect(r['blackName'], 'KnightOwl');
      expect(r['datePlayed'], '2026-10');
      expect(r.containsKey('event'), isFalse);
      expect(r['whiteRating'], 1720);
      expect(r['blackRating'], 1650);
      expect(r['approved'], isFalse);
      expect(r.values.whereType<String>().any((v) => v.contains('Ravi')), isFalse);
    });

    test('online games show the username only when chosen', () {
      expect(build(game(source: 'lichess', opponent: 'ravi_k'))['whiteName'], 'ravi_k');
      expect(build(game(source: 'lichess', opponent: 'ravi_k'), showOpponent: false)['whiteName'], 'Opponent');
      expect(build(game(source: 'lichess'))['datePlayed'], '2026-10-12');
    });

    test('event only when chosen; comments matched to moments; no nulls', () {
      final r = build(game(playerColor: 'white'), showEvent: true);
      expect(r['event'], 'Chennai Open 2026');
      expect(r['whiteName'], 'KnightOwl');
      final moments = r['moments'] as List;
      expect(moments.map((m) => m['comment']), ['a', 'b', '']);
      expect(moments[1]['motif'], 'pin');
      expect(moments.first.containsKey('bestMove'), isFalse);
      expect((r['analysis'] as List).map((a) => a['quality']), ['inaccuracy', 'mistake', 'blunder', 'checkmate']);
      expect(r.values.contains(null), isFalse);
    });
  });

  group('quality bar', () {
    test('needs 150 own words and two commented moments', () {
      final words150 = List.filled(150, 'word').join(' ');
      expect(PublicReportService.meetsIndexBar(words150, ['one', 'two', '']), isTrue);
      expect(PublicReportService.meetsIndexBar(words150, ['one', '', '']), isFalse);
      expect(PublicReportService.meetsIndexBar('short', ['one', 'two']), isFalse);
      expect(PublicReportService.ownWords('a b  c\n\nd', ['e f', '']), 6);
    });

    test('blocked words are caught, ordinary chess words are not', () {
      expect(PublicReportService.blockedWord(['What a shitty move']), 'shit');
      expect(PublicReportService.blockedWord(['I played Bxh7+ and the bishop sacrifice worked']), isNull);
    });
  });

  test('slugs are readable, valid and random', () {
    final slug = PublicReportService.makeSlug(game(), random: Random(1));
    expect(slug, startsWith('2026-10-philidor-defence-'));
    expect(PublicReportService.slugPattern.hasMatch(slug), isTrue);
    expect(PublicReportService.makeSlug(game(), random: Random(2)), isNot(slug));
  });

  test('eligibility needs analysis and at least 20 moves', () {
    expect(PublicReportService.cannotPublishReason(game(evalCurve: const [])), contains('Stockfish'));
    expect(PublicReportService.cannotPublishReason(game()), contains('20 moves'));
  });
}
