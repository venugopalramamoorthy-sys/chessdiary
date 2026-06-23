import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/game_model.dart';
import 'chess_com_service.dart';
import 'game_service.dart';
import 'lichess_service.dart';

/// Progress state broadcast to any listener in the app.
class ImportProgress {
  final bool active;
  final String source;   // 'chess.com' or 'lichess'
  final int done;
  final int total;
  final String? error;

  const ImportProgress({
    required this.active,
    required this.source,
    required this.done,
    required this.total,
    this.error,
  });

  const ImportProgress.idle()
      : active = false, source = '', done = 0, total = 0, error = null;

  String get label => done == total && done > 0
      ? 'Imported $done games from $source'
      : 'Importing $done / $total from $source...';

  double get fraction => total == 0 ? 0.0 : (done / total).clamp(0.0, 1.0);
}

/// Singleton that owns the import lifecycle.
/// Lives outside any widget — survives screen navigation.
class ImportManager {
  ImportManager._();
  static final ImportManager instance = ImportManager._();

  final _controller = StreamController<ImportProgress>.broadcast();
  Stream<ImportProgress> get progressStream => _controller.stream;

  ImportProgress _current = const ImportProgress.idle();
  ImportProgress get current => _current;

  bool get isRunning => _current.active;

  void _emit(ImportProgress p) {
    _current = p;
    _controller.add(p);
  }

  // ── Chess.com ─────────────────────────────────────────────────────────────

  Future<void> importChessCom({
    required List<ChessGame> games,
    required Set<String> importedUrls,
    required String username,
  }) async {
    if (_current.active) return; // already running
    _emit(ImportProgress(active: true, source: 'chess.com', done: 0, total: games.length));

    try {
      final DateTime latest = games
          .map((g) => g.datePlayed)
          .fold(DateTime(2000), (a, b) => b.isAfter(a) ? b : a);

      await GameService.saveGames(games, onProgress: (done, total) {
        _emit(ImportProgress(active: true, source: 'chess.com', done: done, total: total));
      });

      await ChessComService.saveLastSyncTime(latest);
      // Emit final "done" state briefly then go idle
      _emit(ImportProgress(active: false, source: 'chess.com', done: games.length, total: games.length));
    } catch (e) {
      _emit(ImportProgress(active: false, source: 'chess.com', done: _current.done, total: _current.total, error: e.toString()));
    } finally {
      // Reset to idle after a short delay so the "done" message is visible
      await Future.delayed(const Duration(seconds: 3));
      _emit(const ImportProgress.idle());
    }
  }

  // ── Lichess ───────────────────────────────────────────────────────────────

  Future<void> importLichess({
    required List<ChessGame> games,
    required String username,
  }) async {
    if (_current.active) return;
    _emit(ImportProgress(active: true, source: 'lichess', done: 0, total: games.length));

    try {
      final DateTime latest = games
          .map((g) => g.datePlayed)
          .fold(DateTime(2000), (a, b) => b.isAfter(a) ? b : a);

      await GameService.saveGames(games, onProgress: (done, total) {
        _emit(ImportProgress(active: true, source: 'lichess', done: done, total: total));
      });

      await LichessService.saveLastSyncTime(latest);
      _emit(ImportProgress(active: false, source: 'lichess', done: games.length, total: games.length));
    } catch (e) {
      _emit(ImportProgress(active: false, source: 'lichess', done: _current.done, total: _current.total, error: e.toString()));
    } finally {
      await Future.delayed(const Duration(seconds: 3));
      _emit(const ImportProgress.idle());
    }
  }
}
