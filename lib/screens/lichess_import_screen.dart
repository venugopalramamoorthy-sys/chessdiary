import 'package:flutter/material.dart';
import '../models/game_model.dart';
import '../services/game_service.dart';
import '../services/import_manager.dart';
import '../services/lichess_service.dart';
import '../utils/theme.dart';

class LichessImportScreen extends StatefulWidget {
  const LichessImportScreen({super.key});

  @override
  State<LichessImportScreen> createState() => _LichessImportScreenState();
}

class _LichessImportScreenState extends State<LichessImportScreen> {
  final _usernameCtrl = TextEditingController();

  bool _initializing = true;
  bool _loading = false;
  bool _importing = false;
  String _statusMessage = '';
  int _loadedCount = 0;

  String _username = '';
  bool _hasSavedUsername = false;
  DateTime? _lastSyncTime;

  // monthKey -> games
  Map<String, List<LichessGame>> _gamesByMonth = {};
  final Map<String, bool> _expanded = {};
  final Set<String> _selected = {};
  Set<String> _importedUrls = {};

  String _gameKey(String month, int index) => '$month:$index';

  @override
  void initState() {
    super.initState();
    _initFromSaved();
  }

  @override
  void dispose() {
    _usernameCtrl.dispose();
    super.dispose();
  }

  Future<void> _initFromSaved() async {
    final saved = await LichessService.getSavedUsername();
    final lastSync = await LichessService.getLastSyncTime();
    setState(() {
      _hasSavedUsername = saved != null;
      _lastSyncTime = lastSync;
      if (saved != null) _usernameCtrl.text = saved;
      _initializing = false;
    });
    if (saved != null) {
      _username = saved;
      await _fetchGames(incremental: true);
    }
  }

  Future<void> _fetchGames({bool incremental = false}) async {
    final username = _usernameCtrl.text.trim();
    if (username.isEmpty) return;
    setState(() {
      _loading = true;
      _loadedCount = 0;
      _statusMessage = incremental ? 'Checking for new games...' : 'Fetching games from Lichess...';
      _gamesByMonth = {};
      _expanded.clear();
      _selected.clear();
      _importedUrls = {};
    });

    try {
      // Verify user exists
      final exists = await LichessService.userExists(username);
      if (!exists) throw Exception('User "$username" not found on Lichess');

      final existingFuture = GameService.getAllGames();

      int? sinceMs;
      if (incremental && _lastSyncTime != null) {
        // Subtract 2 days to catch any late-arriving games
        sinceMs = _lastSyncTime!.subtract(const Duration(days: 2)).millisecondsSinceEpoch;
      }

      final games = await LichessService.fetchGames(
        username,
        sinceMs: sinceMs,
        max: 500,
        onProgress: (count) {
          if (mounted) setState(() {
            _loadedCount = count;
            _statusMessage = 'Loading... $count games found';
          });
        },
      );

      final existing = await existingFuture;
      final importedUrls = existing
          .where((g) => g.source == 'lichess' && g.imageUrl != null)
          .map((g) => g.imageUrl!)
          .toSet();

      // Group by month and filter already-imported
      final grouped = <String, List<LichessGame>>{};
      for (final g in games) {
        if (!importedUrls.contains(g.url)) {
          (grouped[g.monthKey] ??= []).add(g);
        }
      }

      await LichessService.saveUsername(username);

      setState(() {
        _username = username;
        _hasSavedUsername = true;
        _importedUrls = importedUrls;
        _gamesByMonth = grouped;
        _loading = false;
        _statusMessage = grouped.isEmpty ? 'All games already imported!' : '';
        if (grouped.isNotEmpty) {
          _expanded[grouped.keys.first] = true;
        }
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _statusMessage = 'Error: ${e.toString()}';
      });
    }
  }

  void _removeImported(Set<String> importedKeys) {
    final updated = <String, List<LichessGame>>{};
    for (final monthKey in _gamesByMonth.keys) {
      final games = _gamesByMonth[monthKey]!;
      final remaining = <LichessGame>[];
      for (int i = 0; i < games.length; i++) {
        if (!importedKeys.contains(_gameKey(monthKey, i))) remaining.add(games[i]);
      }
      if (remaining.isNotEmpty) updated[monthKey] = remaining;
    }
    _gamesByMonth = updated;
    _selected.removeWhere((k) => importedKeys.contains(k));
  }

  Future<void> _importSelected() async {
    if (_selected.isEmpty) return;
    final keys = Set<String>.from(_selected);
    final games = <ChessGame>[];
    for (final monthKey in _gamesByMonth.keys) {
      final mg = _gamesByMonth[monthKey]!;
      for (int i = 0; i < mg.length; i++) {
        if (keys.contains(_gameKey(monthKey, i))) games.add(mg[i].toChessGame(_username));
      }
    }
    await _runImport(games, keys);
  }

  Future<void> _importMonth(String monthKey) async {
    final mg = _gamesByMonth[monthKey] ?? [];
    if (mg.isEmpty) return;
    final keys = <String>{};
    final games = <ChessGame>[];
    for (int i = 0; i < mg.length; i++) {
      keys.add(_gameKey(monthKey, i));
      games.add(mg[i].toChessGame(_username));
    }
    await _runImport(games, keys);
  }

  Future<void> _importAll() async {
    final keys = <String>{};
    final games = <ChessGame>[];
    for (final monthKey in _gamesByMonth.keys) {
      final mg = _gamesByMonth[monthKey]!;
      for (int i = 0; i < mg.length; i++) {
        keys.add(_gameKey(monthKey, i));
        games.add(mg[i].toChessGame(_username));
      }
    }
    if (games.isEmpty) return;
    await _runImport(games, keys);
  }

  Future<void> _runImport(List<ChessGame> games, Set<String> importedKeys) async {
    if (games.isEmpty) return;
    if (ImportManager.instance.isRunning) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('An import is already in progress')),
      );
      return;
    }

    if (mounted) {
      setState(() {
        _importing = true;
        _statusMessage = 'Import started — you can navigate away';
        _removeImported(importedKeys);
        _lastSyncTime = games
            .map((g) => g.datePlayed)
            .fold<DateTime>(DateTime(2000), (a, b) => b.isAfter(a) ? b : a);
      });
    }

    ImportManager.instance.importLichess(
      games: games,
      username: _username,
    ).then((_) {
      if (mounted) {
        setState(() { _importing = false; _statusMessage = ''; });
        final remaining = _gamesByMonth.values.fold(0, (s, g) => s + g.length);
        if (remaining == 0) Navigator.pop(context);
      }
    });
  }

  Future<void> _changeUsername() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('Change Lichess username?',
            style: TextStyle(color: AppTheme.textPrimary)),
        content: const Text('This clears the saved username and sync history.',
            style: TextStyle(color: AppTheme.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Change')),
        ],
      ),
    );
    if (confirm == true) {
      await LichessService.clearUsername();
      setState(() {
        _username = '';
        _hasSavedUsername = false;
        _lastSyncTime = null;
        _usernameCtrl.clear();
        _gamesByMonth = {};
        _expanded.clear();
        _selected.clear();
        _statusMessage = '';
      });
    }
  }

  int get _totalGames => _gamesByMonth.values.fold(0, (s, g) => s + g.length);
  bool get _busy => _loading || _importing;

  @override
  Widget build(BuildContext context) {
    if (_initializing) {
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: AppTheme.primary)));
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Import from Lichess'),
        actions: [
          if (_hasSavedUsername)
            IconButton(
              icon: const Icon(Icons.manage_accounts_rounded),
              tooltip: 'Change username',
              onPressed: _busy ? null : _changeUsername,
            ),
        ],
      ),
      body: Column(
        children: [
          _searchBar(),
          if (_lastSyncTime != null && !_loading && _gamesByMonth.isEmpty) _syncInfoBar(),
          if (_statusMessage.isNotEmpty) _statusBar(),
          if (_selected.isNotEmpty && !_busy) _selectionBar(),
          Expanded(child: _body()),
          if (_gamesByMonth.isNotEmpty && !_busy) _importAllBar(),
        ],
      ),
    );
  }

  Widget _searchBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      color: AppTheme.surface,
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _usernameCtrl,
              enabled: !_busy,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _fetchGames(),
              decoration: const InputDecoration(
                hintText: 'Lichess username',
                prefixIcon: Icon(Icons.person_search_rounded, color: AppTheme.textSecondary),
              ),
            ),
          ),
          const SizedBox(width: 10),
          ElevatedButton(
            onPressed: _busy ? null : _fetchGames,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(80, 52),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: _loading
                ? const SizedBox(width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Sync'),
          ),
        ],
      ),
    );
  }

  Widget _syncInfoBar() {
    final dt = _lastSyncTime!;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: AppTheme.surfaceAlt,
      child: Text('Last synced: ${dt.day}/${dt.month}/${dt.year}',
          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
    );
  }

  Widget _statusBar() {
    final isError = _statusMessage.startsWith('Error:') ||
        _statusMessage.startsWith('Import failed') ||
        _statusMessage.contains('not found');
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: isError ? AppTheme.loss.withOpacity(0.15) : AppTheme.surfaceAlt,
      child: Row(
        children: [
          if (_busy)
            const SizedBox(width: 14, height: 14,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary))
          else
            Icon(isError ? Icons.error_outline_rounded : Icons.info_outline_rounded,
                size: 16, color: isError ? AppTheme.loss : AppTheme.textSecondary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(_statusMessage,
                style: TextStyle(
                    color: isError ? AppTheme.loss : AppTheme.textSecondary, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Widget _selectionBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: AppTheme.primary.withOpacity(0.12),
      child: Row(
        children: [
          Text('${_selected.length} selected',
              style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w600)),
          const Spacer(),
          TextButton(
            onPressed: () => setState(() => _selected.clear()),
            child: const Text('Clear', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: _importSelected,
            style: ElevatedButton.styleFrom(
                minimumSize: const Size(100, 38), padding: const EdgeInsets.symmetric(horizontal: 16)),
            child: const Text('Import Selected'),
          ),
        ],
      ),
    );
  }

  Widget _importAllBar() {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        decoration: const BoxDecoration(
          color: AppTheme.surface,
          border: Border(top: BorderSide(color: AppTheme.surfaceAlt)),
        ),
        child: ElevatedButton.icon(
          onPressed: _importAll,
          icon: const Icon(Icons.download_rounded),
          label: Text('Import All Games ($_totalGames)'),
        ),
      ),
    );
  }

  Widget _body() {
    if (!_loading && _gamesByMonth.isEmpty && _username.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Text('🦁', style: TextStyle(fontSize: 56)),
            SizedBox(height: 16),
            Text('Enter your Lichess username\nto import your games',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 15)),
          ],
        ),
      );
    }

    if (_loading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: AppTheme.primary),
            const SizedBox(height: 16),
            Text(_statusMessage, style: const TextStyle(color: AppTheme.textSecondary)),
          ],
        ),
      );
    }

    if (_gamesByMonth.isEmpty && _username.isNotEmpty) {
      return const Center(
          child: Text('All games are up to date.',
              style: TextStyle(color: AppTheme.textSecondary)));
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 8),
      children: _gamesByMonth.entries.map((entry) {
        final monthKey = entry.key;
        final games = entry.value;
        final isExpanded = _expanded[monthKey] ?? false;
        final selectedCount = games.asMap().entries
            .where((e) => _selected.contains(_gameKey(monthKey, e.key)))
            .length;

        return Card(
          margin: const EdgeInsets.fromLTRB(12, 6, 12, 0),
          child: Column(
            children: [
              InkWell(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                onTap: () => setState(() => _expanded[monthKey] = !isExpanded),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Row(
                    children: [
                      Icon(isExpanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                          color: AppTheme.textSecondary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(LichessService.formatMonthKey(monthKey),
                                style: const TextStyle(
                                    color: AppTheme.textPrimary,
                                    fontWeight: FontWeight.w600, fontSize: 15)),
                            Text(
                              '${games.length} game${games.length == 1 ? '' : 's'}'
                              '${selectedCount > 0 ? ' · $selectedCount selected' : ''}',
                              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      if (!_importing)
                        TextButton(
                          onPressed: () => _importMonth(monthKey),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text('Import month',
                              style: TextStyle(color: AppTheme.primary, fontSize: 12)),
                        ),
                    ],
                  ),
                ),
              ),
              if (isExpanded)
                ...games.asMap().entries.map((e) {
                  final idx = e.key;
                  final game = e.value;
                  final key = _gameKey(monthKey, idx);
                  final isSelected = _selected.contains(key);
                  return InkWell(
                    onTap: () => setState(() {
                      if (isSelected) _selected.remove(key);
                      else _selected.add(key);
                    }),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isSelected ? AppTheme.primary.withOpacity(0.08) : null,
                        border: const Border(top: BorderSide(color: AppTheme.surfaceAlt, width: 0.5)),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          Checkbox(
                            value: isSelected,
                            onChanged: (_) => setState(() {
                              if (isSelected) _selected.remove(key);
                              else _selected.add(key);
                            }),
                            activeColor: AppTheme.primary,
                            side: const BorderSide(color: AppTheme.textSecondary),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${game.white} vs ${game.black}',
                                    style: const TextStyle(
                                        color: AppTheme.textPrimary,
                                        fontSize: 13, fontWeight: FontWeight.w500)),
                                const SizedBox(height: 3),
                                Row(
                                  children: [
                                    _chip(_speedLabel(game.speed), AppTheme.textSecondary),
                                    const SizedBox(width: 6),
                                    _chip(_resultLabel(game.result), _resultColor(game.result)),
                                    const SizedBox(width: 6),
                                    Text(
                                      '${game.createdAt.day}/${game.createdAt.month}/${game.createdAt.year}',
                                      style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _chip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
          color: color.withOpacity(0.2), borderRadius: BorderRadius.circular(6)),
      child: Text(label,
          style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600)),
    );
  }

  String _speedLabel(String s) {
    switch (s) {
      case 'bullet': return '⚡ Bullet';
      case 'blitz': return '🔥 Blitz';
      case 'rapid': return '⏱ Rapid';
      case 'classical': return '🏛 Classical';
      case 'correspondence': return '📅 Corr.';
      default: return s;
    }
  }

  String _resultLabel(String r) {
    if (r == '1-0') return 'White wins';
    if (r == '0-1') return 'Black wins';
    return 'Draw';
  }

  Color _resultColor(String r) {
    if (r == '1-0') return AppTheme.win;
    if (r == '0-1') return AppTheme.loss;
    return AppTheme.draw;
  }
}
