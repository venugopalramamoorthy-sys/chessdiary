// lib/services/game_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/game_model.dart';

class GameService {
  static final _db = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  static String get _uid => _auth.currentUser!.uid;
  static CollectionReference get _col =>
      _db.collection('users').doc(_uid).collection('games');

  static Future<String> saveGame(ChessGame game) async {
    final ref = await _col.add(game.toMap());
    return ref.id;
  }

  // Save many games at once using Firestore batch writes (500 per commit)
  static Future<void> saveGames(
    List<ChessGame> games, {
    void Function(int done, int total)? onProgress,
  }) async {
    const batchLimit = 500;
    int done = 0;
    for (int i = 0; i < games.length; i += batchLimit) {
      final chunk = games.skip(i).take(batchLimit).toList();
      final batch = _db.batch();
      for (final g in chunk) {
        batch.set(_col.doc(), g.toMap());
      }
      await batch.commit();
      done += chunk.length;
      onProgress?.call(done, games.length);
    }
  }

  static Future<void> updateGame(String id, ChessGame game) async {
    await _col.doc(id).update(game.toMap());
  }

  static Future<void> deleteGame(String id) async {
    await _col.doc(id).delete();
  }

  static Stream<List<ChessGame>> gamesStream() {
    return _col
        .orderBy('datePlayed', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => ChessGame.fromMap(d.data() as Map<String, dynamic>, d.id))
            .toList());
  }

  static Future<List<ChessGame>> getAllGames() async {
    final snap = await _col.orderBy('datePlayed', descending: true).get();
    return snap.docs
        .map((d) => ChessGame.fromMap(d.data() as Map<String, dynamic>, d.id))
        .toList();
  }

  static Future<PlayerStats> getPlayerStats() async {
    final games = await getAllGames();
    int wins = 0, losses = 0, draws = 0, totalMoves = 0;
    Map<String, int> openings = {};
    Map<String, int> sources = {};

    for (final g in games) {
      switch (g.resultDisplay) {
        case 'Win':
          wins++;
          break;
        case 'Loss':
          losses++;
          break;
        default:
          draws++;
      }
      totalMoves += g.moves.length;
      if (g.opening != null) openings[g.opening!] = (openings[g.opening!] ?? 0) + 1;
      sources[g.source] = (sources[g.source] ?? 0) + 1;
    }

    String? fav;
    if (openings.isNotEmpty) {
      fav = openings.entries.reduce((a, b) => a.value > b.value ? a : b).key;
    }

    return PlayerStats(
      totalGames: games.length,
      wins: wins,
      losses: losses,
      draws: draws,
      avgMoves: games.isEmpty ? 0 : totalMoves ~/ games.length,
      favoriteOpening: fav,
      sourceCounts: sources,
      recentGames: games.take(10).toList(),
      allGames: games,
    );
  }
}

class PlayerStats {
  final int totalGames;
  final int wins;
  final int losses;
  final int draws;
  final int avgMoves;
  final String? favoriteOpening;
  final Map<String, int> sourceCounts;
  final List<ChessGame> recentGames;
  final List<ChessGame> allGames;

  PlayerStats({
    required this.totalGames,
    required this.wins,
    required this.losses,
    required this.draws,
    required this.avgMoves,
    this.favoriteOpening,
    required this.sourceCounts,
    required this.recentGames,
    required this.allGames,
  });

  double get winRate => totalGames == 0 ? 0 : wins / totalGames;
}
