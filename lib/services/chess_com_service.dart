import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/game_model.dart';
import 'pgn_parser.dart';
import 'package:uuid/uuid.dart';

class ChessComGame {
  final String pgn;
  final String white;
  final String black;
  final String result;
  final String timeClass;
  final DateTime endTime;
  final int? whiteRating;
  final int? blackRating;
  final String? opening;
  final String url; // unique chess.com game URL from [Site "..."] PGN header

  ChessComGame({
    required this.pgn,
    required this.white,
    required this.black,
    required this.result,
    required this.timeClass,
    required this.endTime,
    this.whiteRating,
    this.blackRating,
    this.opening,
    required this.url,
  });

  factory ChessComGame.fromJson(Map<String, dynamic> j) {
    final whiteMap = j['white'] as Map<String, dynamic>;
    final blackMap = j['black'] as Map<String, dynamic>;

    String result = '*';
    final wr = whiteMap['result'] as String? ?? '';
    final br = blackMap['result'] as String? ?? '';
    if (wr == 'win') result = '1-0';
    else if (br == 'win') result = '0-1';
    else result = '1/2-1/2';

    final pgn = j['pgn'] as String? ?? '';
    return ChessComGame(
      pgn: pgn,
      white: whiteMap['username'] as String? ?? '',
      black: blackMap['username'] as String? ?? '',
      result: result,
      timeClass: j['time_class'] as String? ?? 'rapid',
      endTime: DateTime.fromMillisecondsSinceEpoch((j['end_time'] as int) * 1000),
      whiteRating: whiteMap['rating'] as int?,
      blackRating: blackMap['rating'] as int?,
      url: j['url'] as String? ?? _extractSiteUrl(pgn),
    );
  }

  String get monthKey {
    return '${endTime.year}-${endTime.month.toString().padLeft(2, '0')}';
  }

  ChessGame toChessGame(String playerUsername) {
    final isWhite = white.toLowerCase() == playerUsername.toLowerCase();
    final moves = _extractMoves(pgn);
    final opening = _extractOpening(pgn);
    final event = _extractEvent(pgn);

    return ChessGame(
      id: const Uuid().v4(),
      playerName: playerUsername,
      opponentName: isWhite ? black : white,
      result: result,
      playerColor: isWhite ? 'white' : 'black',
      moves: moves,
      pgn: pgn,
      datePlayed: endTime,
      source: 'chess.com',
      opening: opening,
      event: event ?? '${timeClass[0].toUpperCase()}${timeClass.substring(1)} Game',
      playerRating: isWhite ? whiteRating : blackRating,
      opponentRating: isWhite ? blackRating : whiteRating,
      imageUrl: url,
      timeControl: _normalizeTimeControl(timeClass),
      clockSeconds: PgnParser.extractClockSeconds(pgn),
    );
  }

  static List<String> _extractMoves(String pgn) {
    // Strip PGN headers and annotations, extract move tokens
    final noHeaders = pgn.replaceAll(RegExp(r'\[.*?\]\s*', dotAll: true), '');
    final noComments = noHeaders.replaceAll(RegExp(r'\{[^}]*\}'), '');
    final tokens = noComments
        .split(RegExp(r'\s+'))
        .where((t) =>
            t.isNotEmpty &&
            !RegExp(r'^\d+\.+$').hasMatch(t) &&
            !RegExp(r'^(1-0|0-1|1/2-1/2|\*)$').hasMatch(t))
        .toList();
    return tokens;
  }

  static String _normalizeTimeControl(String tc) {
    switch (tc.toLowerCase()) {
      case 'bullet': return 'bullet';
      case 'blitz': return 'blitz';
      case 'rapid': return 'rapid';
      case 'daily': return 'correspondence';
      default: return 'rapid';
    }
  }

  static String _extractSiteUrl(String pgn) {
    final m = RegExp(r'\[Site "([^"]+)"\]').firstMatch(pgn);
    return m?.group(1) ?? '';
  }

  static String? _extractOpening(String pgn) {
    final m = RegExp(r'\[ECOUrl "[^"]*\/([^"\/]+)"\]').firstMatch(pgn);
    if (m == null) return null;
    return m.group(1)!.replaceAll('-', ' ');
  }

  static String? _extractEvent(String pgn) {
    final m = RegExp(r'\[Event "([^"]+)"\]').firstMatch(pgn);
    return m?.group(1);
  }
}

class ChessComService {
  static const _base = 'https://api.chess.com/pub/player';
  static const _headers = {'User-Agent': 'ChessDiary/1.0'};
  static const _prefKeyUsername = 'chessdiary_chesscom_username';
  static const _prefKeyLastSync = 'chessdiary_chesscom_last_sync';

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

  // Returns only archive URLs for months >= sinceMonth ("YYYY-MM"), or all if null
  static List<String> filterArchivesSince(List<String> archives, String? sinceMonthKey) {
    if (sinceMonthKey == null) return archives;
    return archives
        .where((url) {
          final key = monthKeyFromArchiveUrl(url);
          return key.isNotEmpty && key.compareTo(sinceMonthKey) >= 0;
        })
        .toList();
  }

  static Future<List<String>> fetchArchives(String username) async {
    final res = await http.get(
      Uri.parse('$_base/${username.toLowerCase()}/games/archives'),
      headers: _headers,
    );
    if (res.statusCode == 404) throw Exception('User "$username" not found on Chess.com');
    if (res.statusCode != 200) throw Exception('Chess.com API error (${res.statusCode})');
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final archives = List<String>.from(data['archives'] ?? []);
    return archives.reversed.toList(); // newest first
  }

  static Future<List<ChessComGame>> fetchGamesForArchive(String archiveUrl) async {
    final res = await http.get(Uri.parse(archiveUrl), headers: _headers);
    if (res.statusCode != 200) return [];
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final games = (data['games'] as List<dynamic>? ?? []);
    return games
        .map((g) => ChessComGame.fromJson(g as Map<String, dynamic>))
        .where((g) => g.pgn.isNotEmpty)
        .toList()
        .reversed
        .toList(); // newest first within month
  }

  // Extract "YYYY-MM" from an archive URL like
  // https://api.chess.com/pub/player/foo/games/2024/03
  static String monthKeyFromArchiveUrl(String url) {
    final parts = url.split('/');
    if (parts.length >= 2) {
      final month = parts.last.padLeft(2, '0');
      final year = parts[parts.length - 2];
      return '$year-$month';
    }
    return '';
  }

  // Fetch games for multiple archive URLs in parallel (max 10 concurrent)
  static Future<Map<String, List<ChessComGame>>> fetchArchivesParallel(
    List<String> archiveUrls, {
    void Function(int done, int total)? onProgress,
  }) async {
    final result = <String, List<ChessComGame>>{};
    int done = 0;
    const batchSize = 10;
    for (int i = 0; i < archiveUrls.length; i += batchSize) {
      final batch = archiveUrls.skip(i).take(batchSize).toList();
      final results = await Future.wait(batch.map(fetchGamesForArchive));
      for (int j = 0; j < batch.length; j++) {
        final games = results[j];
        if (games.isNotEmpty) {
          result[games.first.monthKey] = games;
        }
        done++;
        onProgress?.call(done, archiveUrls.length);
      }
    }
    return result;
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
