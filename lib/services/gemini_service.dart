// lib/services/gemini_service.dart
// Uses Google Gemini API (FREE tier) for:
// 1. Parsing chess scoresheets from images / PDFs / screenshots
// 2. Analysing games for mistakes and blunders
// 3. Coaching insights

import 'dart:convert';
import 'dart:typed_data' show Uint8List;
import 'package:http/http.dart' as http;
import '../models/game_model.dart';

// ── Coaching insight value objects ────────────────────────────────────────────

class InsightCard {
  final String title;
  final String body;
  const InsightCard({required this.title, required this.body});
}

class CoachingInsights {
  final InsightCard? leak;
  final InsightCard? strength;
  final InsightCard? focus;
  final bool hasEnoughData;

  const CoachingInsights({
    required this.leak,
    required this.strength,
    required this.focus,
    this.hasEnoughData = true,
  });

  factory CoachingInsights.notEnoughData() => const CoachingInsights(
        leak: null, strength: null, focus: null, hasEnoughData: false);
}

/// Pre-aggregated, computed stats passed to Gemini.
/// Gemini's job: turn numbers into language, not calculate patterns.
class CoachingData {
  final int totalGames;
  final int totalAnalysedGames;
  final double overallWinRate;
  // Color split
  final double whiteWinRate;
  final double blackWinRate;
  final int whiteGames;
  final int blackGames;
  // Time control
  final Map<String, double> winRateByTC; // e.g. {'blitz': 0.45, 'rapid': 0.62}
  final Map<String, int> gamesByTC;
  // Openings
  final String? bestOpening;
  final double? bestOpeningWinRate;
  final int? bestOpeningGames;
  final String? worstOpening;
  final double? worstOpeningWinRate;
  final int? worstOpeningGames;
  // Tactical blind spots
  final String? topMotif;
  final int? topMotifCount;
  // Endgame conversion
  final double? endgameConversionRate;
  final int endgameOpportunities;
  // Critical moments vs blunders
  final int flaggedBlunderCount;   // single-move blunders in analysed games
  // Tilt pattern
  final double? tiltWinRate;
  final double? normalWinRate;
  final int tiltGames;
  // Time pressure
  final double? timePressureBlunderRate;
  final double? normalBlunderRate;
  // Recent form (last 10)
  final int recentWins;
  final int recentTotal;
  // Rating trend
  final int? latestRating;
  final String? ratingType;
  final int? ratingChange; // vs previous entry (positive = up)
  // Toughest opponent (min 2 games)
  final String? toughestOpponent;
  final double? toughestOpponentWinRate;
  final int? toughestOpponentGames;
  // Blunder streak
  final int blunderStreakGames;

  const CoachingData({
    required this.totalGames,
    required this.totalAnalysedGames,
    required this.overallWinRate,
    required this.whiteWinRate,
    required this.blackWinRate,
    required this.whiteGames,
    required this.blackGames,
    required this.winRateByTC,
    required this.gamesByTC,
    required this.recentWins,
    required this.recentTotal,
    required this.flaggedBlunderCount,
    required this.endgameOpportunities,
    required this.tiltGames,
    required this.blunderStreakGames,
    this.bestOpening,
    this.bestOpeningWinRate,
    this.bestOpeningGames,
    this.worstOpening,
    this.worstOpeningWinRate,
    this.worstOpeningGames,
    this.topMotif,
    this.topMotifCount,
    this.endgameConversionRate,
    this.tiltWinRate,
    this.normalWinRate,
    this.timePressureBlunderRate,
    this.normalBlunderRate,
    this.latestRating,
    this.ratingType,
    this.ratingChange,
    this.toughestOpponent,
    this.toughestOpponentWinRate,
    this.toughestOpponentGames,
  });

  String toPromptText() {
    final buf = StringBuffer();
    buf.writeln('Total games: $totalGames');
    buf.writeln('Games analysed: $totalAnalysedGames');
    buf.writeln('Overall win rate: ${(overallWinRate * 100).toStringAsFixed(0)}%');
    buf.writeln('As White: ${(whiteWinRate * 100).toStringAsFixed(0)}% ($whiteGames games)');
    buf.writeln('As Black: ${(blackWinRate * 100).toStringAsFixed(0)}% ($blackGames games)');

    if (winRateByTC.isNotEmpty) {
      buf.writeln('Win rate by time control:');
      for (final e in winRateByTC.entries) {
        buf.writeln('  ${e.key}: ${(e.value * 100).toStringAsFixed(0)}% (${gamesByTC[e.key] ?? 0} games)');
      }
    }

    if (bestOpening != null) {
      buf.writeln('Best opening: $bestOpening — ${(bestOpeningWinRate! * 100).toStringAsFixed(0)}% win rate ($bestOpeningGames games)');
    }
    if (worstOpening != null) {
      buf.writeln('Worst opening: $worstOpening — ${(worstOpeningWinRate! * 100).toStringAsFixed(0)}% win rate ($worstOpeningGames games)');
    }

    if (topMotif != null) {
      buf.writeln('Most common tactical error: $topMotif ($topMotifCount occurrences in analysed games)');
    }
    buf.writeln('Total blunders/mistakes in analysed games: $flaggedBlunderCount');

    if (endgameConversionRate != null) {
      buf.writeln('Endgame conversion rate: ${(endgameConversionRate! * 100).toStringAsFixed(0)}% ($endgameOpportunities qualifying games)');
    } else if (endgameOpportunities == 0) {
      buf.writeln('Endgame conversion: no data yet');
    }

    if (tiltGames >= 3 && tiltWinRate != null) {
      buf.writeln('Win rate AFTER a loss (tilt): ${(tiltWinRate! * 100).toStringAsFixed(0)}% vs ${(normalWinRate! * 100).toStringAsFixed(0)}% normally ($tiltGames tilt games)');
    }

    if (timePressureBlunderRate != null) {
      buf.writeln('Blunder rate under 30s clock: ${timePressureBlunderRate!.toStringAsFixed(1)} per 10 moves vs ${normalBlunderRate!.toStringAsFixed(1)} with time');
    }

    buf.writeln('Recent form (last $recentTotal): $recentWins wins');

    if (latestRating != null) {
      final trend = ratingChange != null
          ? ' (${ratingChange! >= 0 ? '+' : ''}$ratingChange vs previous)'
          : '';
      buf.writeln('Latest $ratingType rating: $latestRating$trend');
    }

    if (toughestOpponent != null) {
      buf.writeln('Toughest opponent: $toughestOpponent — ${(toughestOpponentWinRate! * 100).toStringAsFixed(0)}% win rate ($toughestOpponentGames games)');
    }

    if (blunderStreakGames > 0) {
      buf.writeln('Clean game streak (no blunders): $blunderStreakGames consecutive games');
    }

    return buf.toString();
  }
}

class GeminiService {
  // All Gemini calls are routed through the Render proxy so no API key
  // lives in client code. The key is set as GEMINI_API_KEY on the server.
  static const String _serverUrl = 'https://chessdiary-stockfish.onrender.com';
  static const String proxyEndpoint = '$_serverUrl/gemini';

  // Update this when Google deprecates the model. "gemini-2.0-flash" was shut
  // down June 1 2026; "gemini-1.5-flash" before that. Consider switching to
  // "gemini-flash-latest" if manual updates become a recurring problem.
  static const String _model = 'gemini-2.5-flash';

  // Injectable HTTP client for unit testing — null in production.
  // ignore: invalid_use_of_visible_for_testing_member
  static http.Client? testHttpClient;

  static Future<String> _generateText(String prompt) => _proxyText(prompt);

  static Future<String> _generateWithImage(
      Uint8List bytes, String mimeType, String prompt) =>
      _proxyImage(bytes, mimeType, prompt);

  static Future<String> _proxyText(String prompt) async {
    final client = testHttpClient ?? http.Client();
    final resp = await client.post(
      Uri.parse(proxyEndpoint),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'model': _model,
        'contents': [
          {
            'parts': [
              {'text': prompt}
            ]
          }
        ],
      }),
    ).timeout(const Duration(seconds: 60));
    return _parseProxyResponse(resp);
  }

  static Future<String> _proxyImage(
      Uint8List bytes, String mimeType, String prompt) async {
    final client = testHttpClient ?? http.Client();
    final resp = await client.post(
      Uri.parse(proxyEndpoint),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'model': _model,
        'contents': [
          {
            'parts': [
              {
                'inlineData': {
                  'mimeType': mimeType,
                  'data': base64Encode(bytes),
                }
              },
              {'text': prompt}
            ]
          }
        ],
      }),
    ).timeout(const Duration(seconds: 60));
    return _parseProxyResponse(resp);
  }

  static String _parseProxyResponse(http.Response resp) {
    if (resp.statusCode == 429 ||
        (resp.statusCode >= 400 && resp.body.contains('RESOURCE_EXHAUSTED'))) {
      throw Exception(
          'AI is temporarily at capacity — please try again in a few minutes.');
    }
    if (resp.statusCode >= 400 && resp.body.contains('API_KEY_INVALID')) {
      throw Exception('AI service configuration error — please contact support.');
    }
    if (resp.statusCode != 200) {
      throw Exception('AI service error (${resp.statusCode}) — please try again.');
    }
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    final candidates = data['candidates'] as List?;
    if (candidates == null || candidates.isEmpty) return '';
    final content = (candidates[0] as Map<String, dynamic>)['content']
        as Map<String, dynamic>?;
    final parts = content?['parts'] as List?;
    if (parts == null || parts.isEmpty) return '';
    return (parts[0] as Map<String, dynamic>)['text'] as String? ?? '';
  }

  // ─────────────────────────────────────────────
  // 1. PARSE SCORESHEET FROM IMAGE
  // ─────────────────────────────────────────────
  static Future<Map<String, dynamic>> parseScoreSheetImage(
      Uint8List bytes, String mimeType) async {

    const prompt = '''
You are an expert chess scoresheet reader. Carefully analyze this image and extract every chess move written on it.

Return ONLY a valid JSON object — no markdown, no extra text, just raw JSON:
{
  "playerWhite": "name or Unknown",
  "playerBlack": "name or Unknown",
  "result": "1-0 or 0-1 or 1/2-1/2 or *",
  "event": "tournament name or null",
  "date": "YYYY-MM-DD or null",
  "moves": ["e4", "e5", "Nf3", "Nc6"],
  "pgn": "full PGN string here",
  "opening": "Opening name if identifiable or null",
  "ratingWhite": null,
  "ratingBlack": null,
  "totalMoves": 0,
  "parseConfidence": "high or medium or low",
  "notes": "any issues encountered"
}

Important rules:
- moves array = alternating White and Black moves in algebraic notation
- pgn = complete PGN with headers and moves
- If handwriting is unclear, make your best guess and set parseConfidence to "low"
- Include all moves you can read even if the game is incomplete
''';

    try {
      final text = await _generateWithImage(bytes, mimeType, prompt);
      return _extractJson(text);
    } catch (e) {
      throw Exception('Failed to parse scoresheet image: $e');
    }
  }

  // ─────────────────────────────────────────────
  // 2. PARSE FROM TEXT (PGN / screenshot text / move list)
  // ─────────────────────────────────────────────
  static Future<Map<String, dynamic>> parseTextGame(String gameText) async {
    final prompt = '''
You are a chess game parser. Parse the following chess game text and extract all information.

Game text:
$gameText

Return ONLY a valid JSON object — no markdown, no extra text:
{
  "playerWhite": "name or Unknown",
  "playerBlack": "name or Unknown",
  "result": "1-0 or 0-1 or 1/2-1/2 or *",
  "event": "tournament name or null",
  "date": "YYYY-MM-DD or null",
  "moves": ["e4", "e5", "Nf3", "Nc6"],
  "pgn": "full PGN string",
  "opening": "Opening name or null",
  "ratingWhite": null,
  "ratingBlack": null,
  "totalMoves": 0,
  "parseConfidence": "high or medium or low",
  "notes": "any observations"
}
''';

    try {
      final text = await _generateText(prompt);
      return _extractJson(text);
    } catch (e) {
      throw Exception('Failed to parse game text: $e');
    }
  }

  // ─────────────────────────────────────────────
  // 3. ANALYSE GAME — find mistakes and good moves
  // ─────────────────────────────────────────────
  static Future<List<MoveAnalysis>> analyzeGame(String pgn) async {
    final prompt = '''
You are an experienced chess coach. Analyze this game and identify the most important moves — both mistakes and brilliant ones.

PGN:
$pgn

Return ONLY a valid JSON array — no markdown, no extra text:
[
  {
    "moveNumber": 1,
    "move": "e4",
    "quality": "best",
    "comment": "Strong central control — the most popular first move.",
    "centipawnLoss": 0
  },
  {
    "moveNumber": 14,
    "move": "Bxf7+",
    "quality": "blunder",
    "comment": "Sacrificing the bishop here loses material without enough compensation.",
    "centipawnLoss": 300
  }
]

Rules:
- quality must be one of: "best", "good", "inaccuracy", "mistake", "blunder"
- Only include moves worth commenting on (skip routine, obvious moves)
- Maximum 15 moves in your response
- Focus on moves where the game's direction changed
- centipawnLoss: 0 for best/good, 50-100 for inaccuracy, 100-200 for mistake, 200+ for blunder
- motif: if the move involves a tactic, set to one of: fork, pin, skewer, hanging_piece, back_rank, discovered_attack, deflection, overloaded, sacrifice. Otherwise set to "none".
- Add "motif" field to each entry.
''';

    try {
      final text = await _generateText(prompt);
      final List<dynamic> data = _extractJsonArray(text);
      return data.map((a) => MoveAnalysis.fromMap(a)).toList();
    } catch (e) {
      throw Exception('Failed to analyze game: $e');
    }
  }

  // ─────────────────────────────────────────────
  // 4. TAG TACTICAL MOTIFS for Stockfish-analysed moves
  // ─────────────────────────────────────────────
  /// Takes already-analysed moves (from Stockfish) and asks Gemini
  /// to identify the tactical motif for each mistake/blunder.
  static Future<List<MoveAnalysis>> tagMotifs(
      String pgn, List<MoveAnalysis> analysis) async {
    final flagged = analysis
        .where((a) => a.quality == 'mistake' || a.quality == 'blunder' || a.quality == 'inaccuracy')
        .toList();
    if (flagged.isEmpty) return analysis;

    final moveList = flagged
        .map((a) => '{"moveNumber":${a.moveNumber},"move":"${a.move}","quality":"${a.quality}"}')
        .join(',');

    final prompt = '''
You are a chess tactics expert. Given this game PGN and a list of flagged moves, identify the tactical motif for each.

PGN:
$pgn

Flagged moves: [$moveList]

For each move, return the tactical motif. Use ONLY these values:
fork, pin, skewer, hanging_piece, back_rank, discovered_attack, deflection, overloaded, sacrifice, endgame_technique, none

Return ONLY a valid JSON array (same order as input), no markdown:
[
  {"moveNumber": 5, "motif": "hanging_piece"},
  {"moveNumber": 12, "motif": "pin"}
]
''';

    try {
      final text = await _generateText(prompt);
      final List<dynamic> motifData = _extractJsonArray(text);
      final Map<int, String> motifByMove = {
        for (final m in motifData)
          (m['moveNumber'] as int): (m['motif'] as String? ?? 'none'),
      };

      return analysis.map((a) {
        final motif = motifByMove[a.moveNumber];
        if (motif == null) return a;
        return MoveAnalysis(
          moveNumber: a.moveNumber,
          move: a.move,
          quality: a.quality,
          comment: a.comment,
          centipawnLoss: a.centipawnLoss,
          motif: motif == 'none' ? null : motif,
        );
      }).toList();
    } catch (_) {
      return analysis; // motif tagging is best-effort
    }
  }

  // ─────────────────────────────────────────────
  // 5. COACHING INSIGHTS — 3 specific, stat-backed cards
  // ─────────────────────────────────────────────

  /// Pass fully-computed stats; Gemini's job is language, not analysis.
  static Future<CoachingInsights> getCoachingInsights(CoachingData data) async {
    // Require minimum data for meaningful insights
    if (data.totalGames < 5) {
      return CoachingInsights.notEnoughData();
    }

    final prompt = '''
You are a direct, data-driven chess coach. I will give you computed statistics about a player.
Your job is to write 3 specific insight cards using ONLY these numbers — do NOT add general advice not supported by the data.

PLAYER STATS:
${data.toPromptText()}

Write exactly 3 JSON objects in this array. Each must reference a specific number from the stats above.
Return ONLY valid JSON, no markdown:
[
  {
    "title": "Your Biggest Leak",
    "body": "One sentence naming the specific weakness with the exact stat. E.g. 'You blunder hanging pieces 4 times more often than any other motif (7 occurrences), mostly in the middlegame.'"
  },
  {
    "title": "What's Working",
    "body": "One sentence naming a genuine strength with the exact stat. Must be a real strength, not generic praise."
  },
  {
    "title": "This Week's Focus",
    "body": "One specific, actionable drill or habit directly tied to the leak above. Include a concrete number or threshold to aim for."
  }
]

Rules:
- Every sentence must cite an actual number from the stats I gave you
- Do NOT use phrases like "consider", "perhaps", or "might want to" — be direct
- Do NOT repeat stats between cards
- If there is genuinely no clear strength, say "Not enough variety in your data yet to identify a clear strength"
''';

    try {
      final text = await _generateText(prompt);
      final List<dynamic> cards = _extractJsonArray(text);
      if (cards.length < 3) return CoachingInsights.notEnoughData();
      return CoachingInsights(
        leak: _card(cards[0]),
        strength: _card(cards[1]),
        focus: _card(cards[2]),
      );
    } catch (_) {
      return CoachingInsights.notEnoughData();
    }
  }

  static InsightCard _card(dynamic json) => InsightCard(
        title: json['title'] as String? ?? '',
        body: json['body'] as String? ?? '',
      );

  // Keep old single-string version for backward compat (no longer used in UI)
  static Future<String> getCoachingInsight(List<ChessGame> recentGames) async {
    return "Log more games to unlock personalised coaching insights.";
  }

  // ─────────────────────────────────────────────
  // HELPERS
  // ─────────────────────────────────────────────
  static Map<String, dynamic> _extractJson(String text) {
    // Remove markdown code fences if present
    String cleaned = text
        .replaceAll(RegExp(r'```json\s*'), '')
        .replaceAll(RegExp(r'```\s*'), '')
        .trim();

    try {
      return jsonDecode(cleaned);
    } catch (_) {
      // Try to find raw JSON object
      final match = RegExp(r'\{[\s\S]*\}').firstMatch(cleaned);
      if (match != null) {
        return jsonDecode(match.group(0)!);
      }
      throw Exception('Could not extract JSON from Gemini response');
    }
  }

  static List<dynamic> _extractJsonArray(String text) {
    String cleaned = text
        .replaceAll(RegExp(r'```json\s*'), '')
        .replaceAll(RegExp(r'```\s*'), '')
        .trim();

    try {
      return jsonDecode(cleaned);
    } catch (_) {
      final match = RegExp(r'\[[\s\S]*\]').firstMatch(cleaned);
      if (match != null) {
        return jsonDecode(match.group(0)!);
      }
      return [];
    }
  }

}
