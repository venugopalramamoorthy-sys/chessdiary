import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/game_model.dart';
import 'pgn_parser.dart';
import 'package:uuid/uuid.dart';

class LichessGame {
  final String id;
  final String pgn;
  final String white;
  final String black;
  final String result;
  final String speed; // bullet, blitz, rapid, classical, correspondence
  final DateTime createdAt;
  final int? whiteRating;
  final int? blackRating;
  final String? opening;

  LichessGame({
    required this.id,
    required this.pgn,
    required this.white,
    required this.black,
    required this.result,
    required this.speed,
    required this.createdAt,
    this.whiteRating,
    this.blackRating,
    this.opening,
  });

  factory LichessGame.fromJson(Map<String, dynamic> j) {
    final players = j['players'] as Map<String, dynamic>;
    final whiteMap = players['white'] as Map<String, dynamic>? ?? {};
    final blackMap = players['black'] as Map<String, dynamic>? ?? {};

    final whiteUser = whiteMap['user'] as Map<String, dynamic>? ?? {};
    final blackUser = blackMap['user'] as Map<String, dynamic>? ?? {};

    String result = '*';
    final winner = j['winner'] as String?;
    if (winner == 'white') result = '1-0';
    else if (winner == 'black') result = '0-1';
    else if (j['status'] == 'draw' || j['status'] == 'stalemate') result = '1/2-1/2';

    final openingMap = j['opening'] as Map<String, dynamic>?;

    // Lichess NDJSON includes pgn when requested
    final pgnField = j['pgn'] as String? ?? '';

    return LichessGame(
      id: j['id'] as String? ?? '',
      pgn: pgnField,
      white: whiteUser['name'] as String? ?? whiteMap['name'] as String? ?? 'Unknown',
      black: blackUser['name'] as String? ?? blackMap['name'] as String? ?? 'Unknown',
      result: result,
      speed: j['speed'] as String? ?? 'rapid',
      createdAt: DateTime.fromMillisecondsSinceEpoch(j['createdAt'] as int? ?? 0),
      whiteRating: whiteMap['rating'] as int?,
      blackRating: blackMap['rating'] as int?,
      opening: openingMap?['name'] as String?,
    );
  }

  String get monthKey =>
      '${createdAt.year}-${createdAt.month.toString().padLeft(2, '0')}';

  String get url => 'https://lichess.org/${id}';

  static String _normalizeSpeed(String speed) {
    switch (speed.toLowerCase()) {
      case 'bullet': return 'bullet';
      case 'blitz': return 'blitz';
      case 'rapid': return 'rapid';
      case 'classical': return 'classical';
      case 'correspondence': return 'correspondence';
      default: return 'rapid';
    }
  }

  ChessGame toChessGame(String playerUsername) {
    final isWhite = white.toLowerCase() == playerUsername.toLowerCase();
    List<String> moves;
    String finalPgn = pgn;

    if (pgn.isNotEmpty) {
      final parsed = PgnParser.parse(pgn);
      moves = List<String>.from(parsed['moves'] ?? []);
    } else {
      moves = [];
      finalPgn = '';
    }

    return ChessGame(
      id: const Uuid().v4(),
      playerName: playerUsername,
      opponentName: isWhite ? black : white,
      result: result,
      playerColor: isWhite ? 'white' : 'black',
      moves: moves,
      pgn: finalPgn,
      datePlayed: createdAt,
      source: 'lichess',
      opening: opening,
      event: '${speed[0].toUpperCase()}${speed.substring(1)} Game',
      playerRating: isWhite ? whiteRating : blackRating,
      opponentRating: isWhite ? blackRating : whiteRating,
      imageUrl: url,
      timeControl: _normalizeSpeed(speed),
      clockSeconds: PgnParser.extractClockSeconds(pgn),
    );
  }
}

class LichessService {
  static const _base = 'https://lichess.org/api';
  static const _headers = {
    'Accept': 'application/x-ndjson',
    'User-Agent': 'ChessDiary/1.0',
  };

  static const _prefKeyUsername = 'chessdiary_lichess_username';
  static const _prefKeyLastSync = 'chessdiary_lichess_last_sync';

  // ── Prefs ────────────────────────────────────────────────────────────────────

  static Future<String?> getSavedUsername() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_prefKeyUsername);
  }

  static Future<void> saveUsername(String username) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKeyUsername, username.toLowerCase().trim());
  }

  static Future<void> clearUsername() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefKeyUsername);
    await prefs.remove(_prefKeyLastSync);
  }

  static Future<DateTime?> getLastSyncTime() async {
    final prefs = await SharedPreferences.getInstance();
    final ms = prefs.getInt(_prefKeyLastSync);
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  static Future<void> saveLastSyncTime(DateTime time) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefKeyLastSync, time.millisecondsSinceEpoch);
  }

  // ── API ──────────────────────────────────────────────────────────────────────

  /// Verify username exists on Lichess.
  static Future<bool> userExists(String username) async {
    final res = await http.get(
      Uri.parse('$_base/user/${username.toLowerCase()}'),
      headers: {'User-Agent': 'ChessDiary/1.0'},
    );
    return res.statusCode == 200;
  }

  /// Fetch games as NDJSON. Optional [since] in milliseconds for incremental sync.
  static Future<List<LichessGame>> fetchGames(
    String username, {
    int? sinceMs,
    int max = 500,
    void Function(int count)? onProgress,
  }) async {
    final params = <String, String>{
      'pgnInJson': 'true',
      'opening': 'true',
      'max': '$max',
      'color': 'white',
    };
    if (sinceMs != null) params['since'] = '$sinceMs';

    // Fetch as white then as black (Lichess API filters by color)
    final games = <LichessGame>[];
    final seen = <String>{};

    for (final color in ['white', 'black']) {
      final p = Map<String, String>.from(params)..['color'] = color;
      final uri = Uri.parse('$_base/games/user/${username.toLowerCase()}')
          .replace(queryParameters: p);
      final res = await http.get(uri, headers: _headers);
      if (res.statusCode != 200) continue;

      final lines = res.body.split('\n').where((l) => l.trim().isNotEmpty);
      int count = 0;
      for (final line in lines) {
        try {
          final j = jsonDecode(line) as Map<String, dynamic>;
          final g = LichessGame.fromJson(j);
          if (!seen.contains(g.id) && g.pgn.isNotEmpty) {
            seen.add(g.id);
            games.add(g);
            count++;
            onProgress?.call(games.length);
          }
        } catch (_) {}
      }
    }

    // Sort newest first
    games.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return games;
  }

  static String formatMonthKey(String key) {
    final parts = key.split('-');
    if (parts.length != 2) return key;
    const months = [
      '', 'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    final month = int.tryParse(parts[1]) ?? 0;
    return '${months[month]} ${parts[0]}';
  }
}
