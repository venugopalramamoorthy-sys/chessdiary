// lib/models/game_model.dart

class ChessGame {
  final String id;
  final String playerName;
  final String opponentName;
  final String result; // '1-0', '0-1', '1/2-1/2', '*'
  final String playerColor; // 'white' or 'black'
  final List<String> moves;
  final String pgn;
  final DateTime datePlayed;
  final String source; // 'paper', 'chess.com', 'lichess', 'other'
  final String? event;
  final String? opening;
  final List<MoveAnalysis> analysis;
  final String? imageUrl;
  final int? playerRating;
  final int? opponentRating;
  final String? notes;        // Phase 2: free-text notes
  final List<String> tags;    // Phase 2: custom tags
  final String? timeControl;  // Phase 5: 'bullet','blitz','rapid','classical','correspondence'
  final List<int> evalCurve;     // Phase 5G2: centipawn eval per half-move (white's perspective)
  final List<int> clockSeconds;  // Phase 5G3: seconds remaining per half-move (from %clk)

  ChessGame({
    required this.id,
    required this.playerName,
    required this.opponentName,
    required this.result,
    required this.playerColor,
    required this.moves,
    required this.pgn,
    required this.datePlayed,
    required this.source,
    this.event,
    this.opening,
    this.analysis = const [],
    this.imageUrl,
    this.playerRating,
    this.opponentRating,
    this.notes,
    this.tags = const [],
    this.timeControl,
    this.evalCurve = const [],
    this.clockSeconds = const [],
  });

  factory ChessGame.fromMap(Map<String, dynamic> map, String id) {
    return ChessGame(
      id: id,
      playerName: map['playerName'] ?? '',
      opponentName: map['opponentName'] ?? '',
      result: map['result'] ?? '*',
      playerColor: map['playerColor'] ?? 'white',
      moves: List<String>.from(map['moves'] ?? []),
      pgn: map['pgn'] ?? '',
      datePlayed: DateTime.parse(map['datePlayed']),
      source: map['source'] ?? 'other',
      event: map['event'],
      opening: map['opening'],
      analysis: (map['analysis'] as List<dynamic>? ?? [])
          .map((a) => MoveAnalysis.fromMap(a))
          .toList(),
      imageUrl: map['imageUrl'],
      playerRating: map['playerRating'],
      opponentRating: map['opponentRating'],
      notes: map['notes'],
      tags: List<String>.from(map['tags'] ?? []),
      timeControl: map['timeControl'],
      evalCurve: List<int>.from(map['evalCurve'] ?? []),
      clockSeconds: List<int>.from(map['clockSeconds'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'playerName': playerName,
      'opponentName': opponentName,
      'result': result,
      'playerColor': playerColor,
      'moves': moves,
      'pgn': pgn,
      'datePlayed': datePlayed.toIso8601String(),
      'source': source,
      'event': event,
      'opening': opening,
      'analysis': analysis.map((a) => a.toMap()).toList(),
      'imageUrl': imageUrl,
      'playerRating': playerRating,
      'opponentRating': opponentRating,
      'notes': notes,
      'tags': tags,
      'timeControl': timeControl,
      'evalCurve': evalCurve,
      'clockSeconds': clockSeconds,
    };
  }

  ChessGame copyWith({
    String? notes,
    List<String>? tags,
    List<MoveAnalysis>? analysis,
    List<int>? evalCurve,
    List<int>? clockSeconds,
  }) {
    return ChessGame(
      id: id,
      playerName: playerName,
      opponentName: opponentName,
      result: result,
      playerColor: playerColor,
      moves: moves,
      pgn: pgn,
      datePlayed: datePlayed,
      source: source,
      event: event,
      opening: opening,
      analysis: analysis ?? this.analysis,
      imageUrl: imageUrl,
      playerRating: playerRating,
      opponentRating: opponentRating,
      notes: notes ?? this.notes,
      tags: tags ?? this.tags,
      timeControl: timeControl ?? this.timeControl,
      evalCurve: evalCurve ?? this.evalCurve,
      clockSeconds: clockSeconds ?? this.clockSeconds,
    );
  }

  String get resultDisplay {
    if (playerColor == 'white') {
      if (result == '1-0') return 'Win';
      if (result == '0-1') return 'Loss';
      return 'Draw';
    } else {
      if (result == '0-1') return 'Win';
      if (result == '1-0') return 'Loss';
      return 'Draw';
    }
  }

  int get totalMoves => moves.length;
}

class MoveAnalysis {
  final int moveNumber;
  final String move;
  final String quality; // 'best', 'good', 'inaccuracy', 'mistake', 'blunder'
  final String? comment;
  final double? centipawnLoss;
  final String? motif;       // tactical motif: fork, pin, skewer, etc.
  final bool timePressure;   // true if clock was <30s when mistake was made
  final String? bestMove;    // engine's recommended best move (SAN), if available

  MoveAnalysis({
    required this.moveNumber,
    required this.move,
    required this.quality,
    this.comment,
    this.centipawnLoss,
    this.motif,
    this.timePressure = false,
    this.bestMove,
  });

  // Game phase based on move number
  String get phase {
    if (moveNumber <= 15) return 'opening';
    if (moveNumber <= 35) return 'middlegame';
    return 'endgame';
  }

  factory MoveAnalysis.fromMap(Map<String, dynamic> map) {
    return MoveAnalysis(
      moveNumber: map['moveNumber'] ?? 0,
      move: map['move'] ?? '',
      quality: map['quality'] ?? 'good',
      comment: map['comment'],
      centipawnLoss: map['centipawnLoss']?.toDouble(),
      motif: map['motif'],
      timePressure: map['timePressure'] == true,
      bestMove: map['bestMove'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
        'moveNumber': moveNumber,
        'move': move,
        'quality': quality,
        'comment': comment,
        'centipawnLoss': centipawnLoss,
        'motif': motif,
        'timePressure': timePressure,
        'bestMove': bestMove,
      };
}

// A single eval point in the eval curve
class EvalPoint {
  final int halfMove; // 0-indexed half-move number
  final int centipawns; // from white's perspective, capped ±2000

  const EvalPoint(this.halfMove, this.centipawns);
}
