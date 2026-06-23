/// Section 6: Network/fallback behavior tests
/// Uses http.MockClient to simulate Stockfish server failures.

import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:chessdiary/services/stockfish_service.dart';

void main() {
  group('StockfishService — server failure / fallback', () {
    test('throws on non-200 status code', () async {
      final client = MockClient((_) async => http.Response('Error', 500));
      expect(
        () => StockfishService.analyzeGame('1. e4 e5 *', client: client),
        throwsA(isA<Exception>().having(
            (e) => e.toString(), 'message', contains('500'))),
      );
    });

    test('throws on network timeout', () async {
      final client = MockClient((_) async {
        await Future.delayed(const Duration(milliseconds: 50));
        throw TimeoutException('Connection timed out');
      });
      expect(
        () => StockfishService.analyzeGame('1. e4 e5 *', client: client),
        throwsA(anything),
      );
    });

    test('throws on connection refused', () async {
      final client = MockClient((_) async {
        throw http.ClientException('Connection refused');
      });
      expect(
        () => StockfishService.analyzeGame('1. e4 e5 *', client: client),
        throwsA(anything),
      );
    });

    test('parses valid 200 response correctly', () async {
      final mockBody = jsonEncode({
        'analysis': [
          {
            'moveNumber': 5,
            'move': 'Nf3',
            'quality': 'good',
            'comment': 'Engine evaluation: +0.3',
            'centipawnLoss': 15,
            'isWhiteMove': true,
          }
        ],
        'evalCurve': [20, 15, 30, 25],
      });
      final client = MockClient((_) async =>
          http.Response(mockBody, 200, headers: {'content-type': 'application/json'}));

      final result = await StockfishService.analyzeGame('1. e4 e5 *', client: client);
      expect(result.analysis.length, 1);
      expect(result.analysis.first.move, 'Nf3');
      expect(result.evalCurve, [20, 15, 30, 25]);
    });

    test('returns empty analysis/curve for 200 with missing fields', () async {
      final client = MockClient((_) async =>
          http.Response('{}', 200, headers: {'content-type': 'application/json'}));

      final result = await StockfishService.analyzeGame('1. e4 *', client: client);
      expect(result.analysis, isEmpty);
      expect(result.evalCurve, isEmpty);
    });

    test('isServerReady returns false on error', () async {
      final client = MockClient((_) async {
        throw http.ClientException('No route to host');
      });
      final ready = await StockfishService.isServerReady(client: client);
      expect(ready, isFalse);
    });

    test('isServerReady returns true on 200', () async {
      final client = MockClient((_) async =>
          http.Response('{"status":"ok"}', 200));
      final ready = await StockfishService.isServerReady(client: client);
      expect(ready, isTrue);
    });

    test('isServerReady returns false on non-200', () async {
      final client = MockClient((_) async => http.Response('', 503));
      final ready = await StockfishService.isServerReady(client: client);
      expect(ready, isFalse);
    });
  });
}
