// lib/services/public_report_service.dart
//
// Public game reports: a frozen, privacy-filtered copy of an analysed game
// published to publicGames/{slug}. The web viewer (web/g/) and the static
// page build (tools/public-games/build.js) render it; firestore.rules limits
// writes to the owner and to exactly the fields built here. `approved` is
// only ever set by the admin tool, so reports start unindexed.

import 'dart:math';

import 'package:chess/chess.dart' as chess;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/game_model.dart';

/// A critical moment offered for comment: the position before the move.
class ReportMoment {
  final int ply; // 0-based half-move index into ChessGame.moves
  final String fen;
  final MoveAnalysis analysis;

  ReportMoment({required this.ply, required this.fen, required this.analysis});
}

class PublicReportService {
  static const siteUrl = 'https://chessdiary.app';
  static const maxMoments = 5;
  static const minMoves = 20; // full moves; shorter games can't be published

  // The indexing bar -- keep in step with tools/public-games/common.js.
  static const minOwnWords = 150;
  static const minComments = 2;

  static const maxNotesChars = 5000;
  static const maxCommentChars = 1500;
  static const maxNameChars = 40;

  static final slugPattern = RegExp(r'^[a-z0-9-]{8,80}$');

  static final _db = FirebaseFirestore.instance;
  static CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('publicGames');

  static String urlFor(String slug) => '$siteUrl/g/$slug/';

  // ── Eligibility ──────────────────────────────────────────────────────────

  /// Why [game] can't be published yet, or null if it can.
  static String? cannotPublishReason(ChessGame game) {
    if (game.analysis.isEmpty || game.evalCurve.isEmpty) {
      return 'Run the Stockfish analysis on this game first.';
    }
    if (game.moves.length < minMoves * 2) {
      return 'Only games of at least $minMoves moves can be published.';
    }
    if (pickMoments(game).isEmpty) {
      return 'This game has no critical moments to comment on.';
    }
    return null;
  }

  // ── Moments ──────────────────────────────────────────────────────────────

  /// Analysis stores full-move numbers without the side to move, so the
  /// half-move is found by matching the SAN on White's then Black's move.
  static int? plyFor(ChessGame game, MoveAnalysis a) => game.plyOf(a);

  /// FEN before each requested half-move, replaying the game from the start.
  /// Stops at the first move the rules engine rejects (a misread scoresheet).
  static Map<int, String> fensBefore(List<String> moves, Set<int> plies) {
    final board = chess.Chess();
    final fens = <int, String>{};
    for (var ply = 0; ply < moves.length; ply++) {
      if (plies.contains(ply)) fens[ply] = board.fen;
      if (!_play(board, moves[ply])) break;
    }
    return fens;
  }

  // move() wants exact SAN; scoresheet moves often drop '+'/'#' or write
  // castling with zeros, so fall back to comparing without decorations.
  static bool _play(chess.Chess board, String san) {
    if (board.move(san)) return true;
    String bare(String s) => s.replaceAll('0', 'O').replaceAll(RegExp(r'[+#?!]+$'), '');
    final want = bare(san.trim());
    for (final m in board.generate_moves()) {
      if (bare(board.move_to_san(m)) == want) return board.move(m);
    }
    return false;
  }

  /// The worst moves by centipawn loss (up to [maxMoments]), in game order.
  static List<ReportMoment> pickMoments(ChessGame game) {
    final candidates = <int, MoveAnalysis>{};
    for (final a in game.analysis) {
      if (!const ['inaccuracy', 'mistake', 'blunder'].contains(a.quality)) continue;
      final ply = plyFor(game, a);
      if (ply != null) candidates[ply] = a;
    }
    final worst = candidates.entries.toList()
      ..sort((x, y) => (y.value.centipawnLoss ?? 0).compareTo(x.value.centipawnLoss ?? 0));
    final chosen = worst.take(maxMoments).toList()..sort((x, y) => x.key.compareTo(y.key));
    final fens = fensBefore(game.moves, chosen.map((e) => e.key).toSet());
    return [
      for (final e in chosen)
        if (fens[e.key] != null) ReportMoment(ply: e.key, fen: fens[e.key]!, analysis: e.value),
    ];
  }

  // ── Quality bar ──────────────────────────────────────────────────────────

  static int wordCount(String text) =>
      text.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;

  static int ownWords(String notes, Iterable<String> comments) =>
      wordCount(notes) + comments.fold(0, (n, c) => n + wordCount(c));

  static bool meetsIndexBar(String notes, List<String> comments) =>
      ownWords(notes, comments) >= minOwnWords &&
      comments.where((c) => c.trim().isNotEmpty).length >= minComments;

  // A short list of words that would never belong next to ads; everything
  // that gets indexed is also read by a person before approval.
  static const _blocked = [
    'fuck', 'shit', 'cunt', 'bitch', 'bastard', 'asshole', 'nigger', 'faggot',
    'retard', 'whore', 'slut', 'porn', 'casino', 'viagra',
  ];

  /// The first blocked word found in [texts], or null.
  static String? blockedWord(Iterable<String> texts) {
    for (final t in texts) {
      final lower = t.toLowerCase();
      for (final w in _blocked) {
        if (RegExp('\\b$w').hasMatch(lower)) return w;
      }
    }
    return null;
  }

  // ── Building the public copy ─────────────────────────────────────────────

  static String _slugPart(String s) => s
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');

  /// e.g. 2026-10-sicilian-defence-najdorf-k3f9q2 -- readable, not guessable.
  static String makeSlug(ChessGame game, {Random? random}) {
    final rnd = random ?? Random.secure();
    const alphabet = 'abcdefghijkmnpqrstuvwxyz23456789';
    final suffix = List.generate(6, (_) => alphabet[rnd.nextInt(alphabet.length)]).join();
    final date = game.datePlayed.toIso8601String().substring(0, 7);
    final words = _slugPart(game.opening ?? '').split('-').where((w) => w.isNotEmpty).take(4);
    final middle = words.isEmpty ? 'game' : words.join('-');
    return '$date-$middle-$suffix';
  }

  /// The public document. Paper games never show the opponent's real name
  /// or the exact date; [showOpponentName] only applies to online games,
  /// whose usernames are already public on Chess.com/Lichess.
  static Map<String, dynamic> buildReport({
    required ChessGame game,
    required String slug,
    required String ownerUid,
    required String authorName,
    required bool showOpponentName,
    required bool showEvent,
    required String notes,
    required List<ReportMoment> moments,
    required List<String> comments,
  }) {
    final online = game.source == 'chess.com' || game.source == 'lichess';
    final opponent = online && showOpponentName && game.opponentName.trim().isNotEmpty
        ? _trim(game.opponentName.trim(), maxNameChars)
        : 'Opponent';
    final author = _trim(authorName.trim(), maxNameChars);
    final authorIsWhite = game.playerColor != 'black';
    final authorRating = game.playerRating;
    final opponentRating = game.opponentRating;
    final iso = game.datePlayed.toIso8601String();

    final flagged = <Map<String, dynamic>>[];
    for (final a in game.analysis) {
      if (!const ['inaccuracy', 'mistake', 'blunder', 'checkmate'].contains(a.quality)) continue;
      final ply = plyFor(game, a);
      if (ply == null) continue;
      flagged.add({
        'ply': ply,
        'move': a.move,
        'quality': a.quality,
        'cpLoss': (a.centipawnLoss ?? 0).round(),
      });
    }

    return {
      'ownerUid': ownerUid,
      'slug': slug,
      'sourceGameId': game.id,
      'approved': false,
      'authorName': author,
      'playerColor': authorIsWhite ? 'white' : 'black',
      'whiteName': authorIsWhite ? author : opponent,
      'blackName': authorIsWhite ? opponent : author,
      if ((authorIsWhite ? authorRating : opponentRating) != null)
        'whiteRating': authorIsWhite ? authorRating : opponentRating,
      if ((authorIsWhite ? opponentRating : authorRating) != null)
        'blackRating': authorIsWhite ? opponentRating : authorRating,
      'result': game.result,
      'datePlayed': online ? iso.substring(0, 10) : iso.substring(0, 7),
      'source': game.source,
      if (showEvent && (game.event ?? '').trim().isNotEmpty)
        'event': _trim(game.event!.trim(), 80),
      if ((game.opening ?? '').trim().isNotEmpty) 'opening': _trim(game.opening!.trim(), 80),
      if ((game.timeControl ?? '').isNotEmpty) 'timeControl': game.timeControl,
      'moves': game.moves,
      'evalCurve': game.evalCurve,
      'analysis': flagged,
      'moments': [
        for (var i = 0; i < moments.length; i++)
          {
            'ply': moments[i].ply,
            'fen': moments[i].fen,
            'move': moments[i].analysis.move,
            'quality': moments[i].analysis.quality,
            'cpLoss': (moments[i].analysis.centipawnLoss ?? 0).round(),
            if ((moments[i].analysis.bestMove ?? '').isNotEmpty)
              'bestMove': moments[i].analysis.bestMove,
            if ((moments[i].analysis.motif ?? '').isNotEmpty)
              'motif': moments[i].analysis.motif,
            'comment': _trim(i < comments.length ? comments[i].trim() : '', maxCommentChars),
          },
      ],
      'notes': _trim(notes.trim(), maxNotesChars),
    };
  }

  static String _trim(String s, int max) => s.length <= max ? s : s.substring(0, max);

  // ── Firestore ────────────────────────────────────────────────────────────

  /// The published copy of [game], if any.
  static Future<Map<String, dynamic>?> fetch(String slug) async {
    final snap = await _col.doc(slug).get();
    return snap.data();
  }

  /// Creates or replaces the report and links it from the private game.
  /// Re-publishing keeps the slug and publish date and resets approval.
  static Future<String> publish({
    required ChessGame game,
    required String authorName,
    required bool showOpponentName,
    required bool showEvent,
    required String notes,
    required List<ReportMoment> moments,
    required List<String> comments,
  }) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final existing = game.publicSlug;
    final slug = existing ?? makeSlug(game);
    final report = buildReport(
      game: game,
      slug: slug,
      ownerUid: uid,
      authorName: authorName,
      showOpponentName: showOpponentName,
      showEvent: showEvent,
      notes: notes,
      moments: moments,
      comments: comments,
    );
    final ref = _col.doc(slug);
    final current = existing == null ? null : await ref.get();
    if (current != null && current.exists) {
      await ref.set({
        ...report,
        'publishedAt': current.data()!['publishedAt'],
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } else {
      await ref.set({
        ...report,
        'publishedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    if (existing == null) {
      await _gameRef(uid, game.id).update({'publicSlug': slug});
    }
    return slug;
  }

  static Future<void> unpublish(ChessGame game) async {
    final slug = game.publicSlug;
    if (slug == null) return;
    final uid = FirebaseAuth.instance.currentUser!.uid;
    await _col.doc(slug).delete();
    await _gameRef(uid, game.id).update({'publicSlug': FieldValue.delete()});
  }

  /// Every report [uid] published -- used by account deletion.
  static Future<void> deleteAllFor(String uid) async {
    final snap = await _col.where('ownerUid', isEqualTo: uid).get();
    for (final doc in snap.docs) {
      await doc.reference.delete();
    }
  }

  static DocumentReference<Map<String, dynamic>> _gameRef(String uid, String gameId) =>
      _db.collection('users').doc(uid).collection('games').doc(gameId);
}
