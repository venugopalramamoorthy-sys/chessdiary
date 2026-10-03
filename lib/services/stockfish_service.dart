import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import '../models/game_model.dart';

class StockfishResult {
  final List<MoveAnalysis> analysis;
  final List<int> evalCurve;
  const StockfishResult({required this.analysis, required this.evalCurve});
}

class StockfishService {
  static const String _baseUrl = 'https://chessdiary-stockfish.onrender.com';

  // Injectable FirebaseAuth for unit testing -- same pattern as
  // AuthService.testAuth (see delete_account_test.dart).
  static FirebaseAuth? testAuth;

  /// Sends a PGN to the Stockfish server. Requires a signed-in user --
  /// /analyze started requiring a Firebase ID token after a security
  /// review found it (and /gemini) completely open to anyone who had
  /// the URL, which ships in the public web JS bundle regardless.
  /// [client] is optional — pass a mock client in tests.
  static Future<StockfishResult> analyzeGame(String pgn,
      {http.Client? client}) async {
    final c = client ?? http.Client();
    try {
      final user = (testAuth ?? FirebaseAuth.instance).currentUser;
      if (user == null) {
        throw Exception('Sign in required to analyze a game.');
      }
      final token = await user.getIdToken();
      final response = await c
          .post(
            Uri.parse('$_baseUrl/analyze'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({'pgn': pgn}),
          )
          .timeout(const Duration(seconds: 90));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final analysis = (data['analysis'] as List<dynamic>? ?? [])
            .map((a) => MoveAnalysis.fromMap(a as Map<String, dynamic>))
            .toList();
        final evalCurve = List<int>.from(data['evalCurve'] ?? []);
        return StockfishResult(analysis: analysis, evalCurve: evalCurve);
      } else {
        throw Exception('Stockfish server error: ${response.statusCode}');
      }
    } finally {
      if (client == null) c.close(); // close default client; tests manage their own
    }
  }

  static Future<bool> isServerReady({http.Client? client}) async {
    final c = client ?? http.Client();
    try {
      final response = await c
          .get(Uri.parse('$_baseUrl/health'))
          .timeout(const Duration(seconds: 10));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    } finally {
      if (client == null) c.close();
    }
  }
}
