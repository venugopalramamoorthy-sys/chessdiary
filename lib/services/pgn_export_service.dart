import 'dart:convert' show utf8;
import '../models/game_model.dart';
import '../utils/platform_file.dart';

class PgnExportService {
  static String gameToPgn(ChessGame g) {
    final buf = StringBuffer();

    void tag(String key, String? value) {
      if (value != null && value.isNotEmpty) buf.writeln('[$key "$value"]');
    }

    tag('Event', g.event ?? 'ChessDiary Game');
    tag('Site', 'ChessDiary');
    final d = g.datePlayed;
    tag('Date', '${d.year}.${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')}');
    tag('White', g.playerColor == 'white' ? g.playerName : g.opponentName);
    tag('Black', g.playerColor == 'black' ? g.playerName : g.opponentName);
    tag('Result', g.result);
    if (g.playerRating != null) {
      if (g.playerColor == 'white') {
        tag('WhiteElo', '${g.playerRating}');
      } else {
        tag('BlackElo', '${g.playerRating}');
      }
    }
    if (g.opponentRating != null) {
      if (g.playerColor == 'white') {
        tag('BlackElo', '${g.opponentRating}');
      } else {
        tag('WhiteElo', '${g.opponentRating}');
      }
    }
    if (g.opening != null) tag('Opening', g.opening);

    buf.writeln();

    if (g.pgn.isNotEmpty && g.pgn.contains('[')) {
      final noHeaders = g.pgn.replaceAll(RegExp(r'\[.*?\]\s*', dotAll: true), '').trim();
      buf.writeln(noHeaders);
    } else if (g.moves.isNotEmpty) {
      final moves = g.moves;
      final sb = StringBuffer();
      for (int i = 0; i < moves.length; i++) {
        if (i % 2 == 0) sb.write('${i ~/ 2 + 1}. ');
        sb.write('${moves[i]} ');
      }
      sb.write(g.result);
      buf.writeln(sb.toString().trim());
    } else {
      buf.writeln(g.result);
    }

    return buf.toString();
  }

  static String collectionToPgn(List<ChessGame> games) {
    return games.map(gameToPgn).join('\n\n');
  }

  // Returns the saved file path on mobile/desktop, or null on web
  // (web triggers a browser download directly).
  static Future<String?> exportGame(ChessGame game) async {
    final content = gameToPgn(game);
    final opp = game.opponentName.replaceAll(RegExp(r'[^\w]'), '_');
    final date =
        '${game.datePlayed.year}${game.datePlayed.month.toString().padLeft(2, '0')}${game.datePlayed.day.toString().padLeft(2, '0')}';
    return platformSaveFile(
      'chessdiary_vs_${opp}_$date.pgn',
      utf8.encode(content),
      'application/x-chess-pgn',
    );
  }

  static Future<String?> exportAll(List<ChessGame> games) async {
    final content = collectionToPgn(games);
    return platformSaveFile(
      'chessdiary_all_games.pgn',
      utf8.encode(content),
      'application/x-chess-pgn',
    );
  }
}
