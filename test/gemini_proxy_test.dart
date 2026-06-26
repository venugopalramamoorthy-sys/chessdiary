// Tests for GeminiService proxy routing.
// Verifies that ALL Gemini calls go through the Render proxy (never directly
// to googleapis.com), the proxy URL is correct, and response parsing works.

import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:chessdiary/services/gemini_service.dart';

void main() {
  // Reset the test client after each test so production code is unaffected.
  tearDown(() => GeminiService.testHttpClient = null);

  // ── Proxy endpoint contract ────────────────────────────────────────────────

  group('GeminiService — proxy URL', () {
    test('proxyEndpoint targets the Render server, not googleapis.com', () {
      expect(GeminiService.proxyEndpoint,
          contains('chessdiary-stockfish.onrender.com'));
      expect(GeminiService.proxyEndpoint,
          isNot(contains('googleapis.com')));
    });

    test('proxyEndpoint path is /gemini', () {
      expect(GeminiService.proxyEndpoint, endsWith('/gemini'));
    });

    test('proxyEndpoint is HTTPS', () {
      expect(GeminiService.proxyEndpoint, startsWith('https://'));
    });
  });

  // ── Text proxy call ────────────────────────────────────────────────────────

  group('GeminiService.parseTextGame — proxy routing', () {
    test('sends request to the proxy endpoint (not direct to Google)', () async {
      Uri? calledUrl;
      GeminiService.testHttpClient = MockClient((req) async {
        calledUrl = req.url;
        // Return a valid Gemini-format response
        return http.Response(
          jsonEncode({
            'candidates': [
              {
                'content': {
                  'parts': [
                    {'text': '{"playerWhite":"Alice","playerBlack":"Bob","result":"1-0","moves":["e4","e5"],"pgn":"1. e4 e5 *","totalMoves":2,"parseConfidence":"high"}'}
                  ]
                }
              }
            ]
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      await GeminiService.parseTextGame('1. e4 e5 *');

      expect(calledUrl, isNotNull);
      expect(calledUrl.toString(), contains('onrender.com'));
      expect(calledUrl.toString(), isNot(contains('googleapis.com')));
    });

    test('request body does not include an API key', () async {
      String? requestBody;
      GeminiService.testHttpClient = MockClient((req) async {
        requestBody = req.body;
        return http.Response(
          jsonEncode({
            'candidates': [
              {'content': {'parts': [{'text': '{"playerWhite":"A","playerBlack":"B","result":"*","moves":[],"pgn":"","totalMoves":0,"parseConfidence":"low"}'}]}}
            ]
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      await GeminiService.parseTextGame('1. e4 *');

      expect(requestBody, isNotNull);
      // Body is JSON to the proxy — no API key should appear
      expect(requestBody, isNot(contains('key=')));
      expect(requestBody, isNot(matches(RegExp(r'AIza\w+'))));
    });

    test('request includes the gemini model name in body', () async {
      String? requestBody;
      GeminiService.testHttpClient = MockClient((req) async {
        requestBody = req.body;
        return http.Response(
          jsonEncode({
            'candidates': [
              {'content': {'parts': [{'text': '{"playerWhite":"A","playerBlack":"B","result":"*","moves":[],"pgn":"","totalMoves":0,"parseConfidence":"low"}'}]}}
            ]
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      await GeminiService.parseTextGame('1. e4 *');
      expect(requestBody, contains('gemini-2.0-flash'));
    });
  });

  // ── Image proxy call ───────────────────────────────────────────────────────

  group('GeminiService.parseScoreSheetImage — proxy routing', () {
    test('sends image request to proxy, not to googleapis.com', () async {
      Uri? calledUrl;
      GeminiService.testHttpClient = MockClient((req) async {
        calledUrl = req.url;
        return http.Response(
          jsonEncode({
            'candidates': [
              {'content': {'parts': [{'text': '{"playerWhite":"A","playerBlack":"B","result":"*","moves":[],"pgn":"","totalMoves":0,"parseConfidence":"low"}'}]}}
            ]
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      // 1×1 PNG bytes (minimal valid image)
      final pngBytes = base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg=='
      );
      await GeminiService.parseScoreSheetImage(pngBytes, 'image/png');

      expect(calledUrl.toString(), contains('onrender.com'));
      expect(calledUrl.toString(), isNot(contains('googleapis.com')));
    });

    test('image request body contains inlineData with base64', () async {
      String? requestBody;
      GeminiService.testHttpClient = MockClient((req) async {
        requestBody = req.body;
        return http.Response(
          jsonEncode({
            'candidates': [
              {'content': {'parts': [{'text': '{"playerWhite":"A","playerBlack":"B","result":"*","moves":[],"pgn":"","totalMoves":0,"parseConfidence":"low"}'}]}}
            ]
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final pngBytes = base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg=='
      );
      await GeminiService.parseScoreSheetImage(pngBytes, 'image/png');

      expect(requestBody, contains('inlineData'));
      expect(requestBody, contains('image/png'));
    });
  });

  // ── Response parsing ───────────────────────────────────────────────────────

  group('GeminiService — proxy response parsing', () {
    test('throws on non-200 proxy response', () async {
      GeminiService.testHttpClient = MockClient((_) async =>
          http.Response('{"error":"GEMINI_API_KEY not set on server"}', 500,
              headers: {'content-type': 'application/json'}));

      expect(
        () => GeminiService.parseTextGame('1. e4 *'),
        throwsA(isA<Exception>().having(
          (e) => e.toString(), 'message', contains('500'))),
      );
    });

    test('throws on 401 unauthorised from proxy', () async {
      GeminiService.testHttpClient = MockClient((_) async =>
          http.Response('Unauthorised', 401));

      expect(
        () => GeminiService.parseTextGame('1. e4 *'),
        throwsA(isA<Exception>()),
      );
    });

    test('parseTextGame returns correct playerWhite from proxy response', () async {
      GeminiService.testHttpClient = MockClient((_) async => http.Response(
        jsonEncode({
          'candidates': [
            {
              'content': {
                'parts': [
                  {
                    'text': '{"playerWhite":"Magnus","playerBlack":"Hikaru","result":"1-0","moves":["e4","c5"],"pgn":"1. e4 c5 1-0","totalMoves":2,"parseConfidence":"high","opening":"Sicilian"}'
                  }
                ]
              }
            }
          ]
        }),
        200,
        headers: {'content-type': 'application/json'},
      ));

      final result = await GeminiService.parseTextGame('1. e4 c5 1-0');
      expect(result['playerWhite'], 'Magnus');
      expect(result['playerBlack'], 'Hikaru');
      expect(result['result'], '1-0');
      expect(result['opening'], 'Sicilian');
    });

    test('analyzeGame returns parsed MoveAnalysis list', () async {
      GeminiService.testHttpClient = MockClient((_) async => http.Response(
        jsonEncode({
          'candidates': [
            {
              'content': {
                'parts': [
                  {
                    'text': '[{"moveNumber":14,"move":"Bxf7+","quality":"blunder","comment":"Hangs the bishop","centipawnLoss":280}]'
                  }
                ]
              }
            }
          ]
        }),
        200,
        headers: {'content-type': 'application/json'},
      ));

      final analysis = await GeminiService.analyzeGame('1. e4 e5 *');
      expect(analysis.length, 1);
      expect(analysis.first.move, 'Bxf7+');
      expect(analysis.first.quality, 'blunder');
      expect(analysis.first.centipawnLoss, 280.0);
    });

    test('analyzeGame returns empty list on empty proxy response array', () async {
      GeminiService.testHttpClient = MockClient((_) async => http.Response(
        jsonEncode({
          'candidates': [
            {'content': {'parts': [{'text': '[]'}]}}
          ]
        }),
        200,
        headers: {'content-type': 'application/json'},
      ));

      final analysis = await GeminiService.analyzeGame('1. e4 *');
      expect(analysis, isEmpty);
    });
  });
}
