import 'package:flutter/material.dart';
import '../models/game_model.dart';
import '../services/chess_com_service.dart';
import '../services/game_service.dart';
import '../services/import_manager.dart';
import '../utils/theme.dart';

class ChessComImportScreen extends StatefulWidget {
  const ChessComImportScreen({super.key});

  @override
  State<ChessComImportScreen> createState() => _ChessComImportScreenState();
}

class _ChessComImportScreenState extends State<ChessComImportScreen> {
  final _usernameCtrl = TextEditingController();

  bool _initializing = true;
  bool _fetchingArchives = false;
  bool _importing = false;
  bool _importingAll = false;
  String _statusMessage = '';

  String _username = '';
  bool _hasSavedUsername = false;
  DateTime? _lastSyncTime;

  List<String> _archiveUrls = [];
  // monthKey -> loaded games (null = not fetched yet)
  final Map<String, List<ChessComGame>?> _gamesByMonth = {};
  final Map<String, bool> _expanded = {};
  final Map<String, bool> _loadingMonth = {};
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
    final saved = await ChessComService.getSavedUsername();
    final lastSync = await ChessComService.getLastSyncTime();
    setState(() {
      _hasSavedUsername = saved != null;
      _lastSyncTime = lastSync;
      if (saved != null) _usernameCtrl.text = saved;
      _initializing = false;
    });
    // Auto-fetch if we have a saved username
    if (saved != null) {
      _username = saved;
      await _fetchArchives(incremental: true);
    }
  }

  Future<void> _fetchArchives({bool incremental = false}) async {
    final username = _usernameCtrl.text.trim();
    if (username.isEmpty) return;

    setState(() {
      _fetchingArchives = true;
      _statusMessage = incremental ? 'Checking for new games...' : 'Fetching archives...';
      _archiveUrls = [];
      _gamesByMonth.clear();
      _expanded.clear();
      _loadingMonth.clear();
      _selected.clear();
      _importedUrls = {};
    });

    try {
      final archivesFuture = ChessComService.fetchArchives(username);
      final existingFuture = GameService.getAllGames();

      var archives = await archivesFuture;
      final existing = await existingFuture;

      final importedUrls = existing
          .where((g) => g.source == 'chess.com' && g.imageUrl != null)
          .map((g) => g.imageUrl!)
          .toSet();

      // For incremental sync, only look at months since last sync
      String? sinceMonthKey;
      if (incremental && _lastSyncTime != null) {
        // Go one month back to catch any late additions to the previous month
        final cutoff = DateTime(_lastSyncTime!.year, _lastSyncTime!.month - 1);
        sinceMonthKey =
            '${cutoff.year}-${cutoff.month.toString().padLeft(2, '0')}';
      }
      final filteredArchives = ChessComService.filterArchivesSince(archives, sinceMonthKey);

      // Build month keys for display
      final monthKeys = filteredArchives
          .map(ChessComService.monthKeyFromArchiveUrl)
          .where((k) => k.isNotEmpty)
          .toList();

      await ChessComService.saveUsername(username);

      setState(() {
        _username = username;
        _hasSavedUsername = true;
        _archiveUrls = filteredArchives;
        _importedUrls = importedUrls;
        _fetchingArchives = false;
        _statusMessage = '';
        for (final key in monthKeys) {
          _gamesByMonth[key] = null;
          _expanded[key] = false;
          _loadingMonth[key] = false;
        }
        if (monthKeys.isNotEmpty) {
          _expanded[monthKeys.first] = true;
          _loadMonth(monthKeys.first, filteredArchives.first);
        }
      });

      if (filteredArchives.isEmpty) {
        setState(() => _statusMessage = 'All games already up to date!');
      }
    } catch (e) {
      setState(() {
        _fetchingArchives = false;
        _statusMessage = 'Error: ${e.toString()}';
      });
    }
  }

  Future<void> _loadMonth(String monthKey, String archiveUrl) async {
    if (_loadingMonth[monthKey] == true) return;
    if (_gamesByMonth[monthKey] != null) return;
    setState(() => _loadingMonth[monthKey] = true);
    try {
      final games = await ChessComService.fetchGamesForArchive(archiveUrl);
      final filtered = games.where((g) => !_importedUrls.contains(g.url)).toList();
      if (mounted) setState(() {
        _gamesByMonth[monthKey] = filtered;
        _loadingMonth[monthKey] = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingMonth[monthKey] = false);
    }
  }

  String _archiveUrlForMonth(String monthKey) {
    return _archiveUrls.firstWhere(
      (url) => ChessComService.monthKeyFromArchiveUrl(url) == monthKey,
      orElse: () => '',
    );
  }

  void _toggleMonth(String monthKey) {
    final nowExpanded = !(_expanded[monthKey] ?? false);
    setState(() => _expanded[monthKey] = nowExpanded);
    if (nowExpanded && _gamesByMonth[monthKey] == null) {
      _loadMonth(monthKey, _archiveUrlForMonth(monthKey));
    }
  }

  void _removeImported(Set<String> importedKeys, Set<String> importedUrls) {
    for (final monthKey in List.of(_gamesByMonth.keys)) {
      final games = _gamesByMonth[monthKey];
      if (games == null) continue;
      final remaining = <ChessComGame>[];
      for (int i = 0; i < games.length; i++) {
        if (!importedKeys.contains(_gameKey(monthKey, i))) remaining.add(games[i]);
      }
      _gamesByMonth[monthKey] = remaining;
    }
    _importedUrls.addAll(importedUrls);
    _selected.removeWhere((k) => importedKeys.contains(k));
  }

  Future<void> _importSelected() async {
    if (_selected.isEmpty) return;
    final keys = Set<String>.from(_selected);
    final games = <ChessGame>[];
    final urls = <String>{};
    for (final monthKey in _gamesByMonth.keys) {
      final monthGames = _gamesByMonth[monthKey] ?? [];
      for (int i = 0; i < monthGames.length; i++) {
        final key = _gameKey(monthKey, i);
        if (keys.contains(key)) {
          games.add(monthGames[i].toChessGame(_username));
          urls.add(monthGames[i].url);
        }
      }
    }
    await _runImport(games, keys, urls);
  }

  Future<void> _importMonth(String monthKey) async {
    final archiveUrl = _archiveUrlForMonth(monthKey);
    if (_gamesByMonth[monthKey] == null && archiveUrl.isNotEmpty) {
      await _loadMonth(monthKey, archiveUrl);
    }
    final monthGames = _gamesByMonth[monthKey] ?? [];
    if (monthGames.isEmpty) return;
    final keys = <String>{};
    final games = <ChessGame>[];
    final urls = <String>{};
    for (int i = 0; i < monthGames.length; i++) {
      keys.add(_gameKey(monthKey, i));
      games.add(monthGames[i].toChessGame(_username));
      urls.add(monthGames[i].url);
    }
    await _runImport(games, keys, urls);
  }

  Future<void> _importAll() async {
    setState(() {
      _importingAll = true;
      _statusMessage = 'Loading all months...';
    });
    try {
      final unloaded = _archiveUrls
          .where((url) => _gamesByMonth[ChessComService.monthKeyFromArchiveUrl(url)] == null)
          .toList();

      int loadDone = 0;
      await ChessComService.fetchArchivesParallel(
        unloaded,
        onProgress: (done, total) {
          if (mounted) setState(() {
            loadDone = done;
            _statusMessage = 'Loading $done / $total months...';
          });
        },
      ).then((loaded) {
        for (final entry in loaded.entries) {
          _gamesByMonth[entry.key] =
              entry.value.where((g) => !_importedUrls.contains(g.url)).toList();
        }
      });

      final allKeys = <String>{};
      final allGames = <ChessGame>[];
      final allUrls = <String>{};
      for (final monthKey in _gamesByMonth.keys) {
        final games = _gamesByMonth[monthKey] ?? [];
        for (int i = 0; i < games.length; i++) {
          allKeys.add(_gameKey(monthKey, i));
          allGames.add(games[i].toChessGame(_username));
          allUrls.add(games[i].url);
        }
      }

      setState(() {
        _importingAll = false;
        _statusMessage = '';
      });

      if (allGames.isEmpty) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No new games to import')),
        );
        return;
      }
      await _runImport(allGames, allKeys, allUrls);
    } catch (e) {
      setState(() {
        _importingAll = false;
        _statusMessage = 'Error: $e';
      });
    }
  }

  Future<void> _runImport(
      List<ChessGame> games, Set<String> importedKeys, Set<String> importedUrls) async {
    if (games.isEmpty) return;
    if (ImportManager.instance.isRunning) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('An import is already in progress')),
      );
      return;
    }

    // Remove games from the screen immediately
    if (mounted) {
      setState(() {
        _importing = true;
        _statusMessage = 'Import started — you can navigate away';
        _removeImported(importedKeys, importedUrls);
        _lastSyncTime = games
            .map((g) => g.datePlayed)
            .fold<DateTime>(DateTime(2000), (a, b) => b.isAfter(a) ? b : a);
      });
    }

    // Hand off to ImportManager — it runs independently of this screen
    ImportManager.instance.importChessCom(
      games: games,
      importedUrls: importedUrls,
      username: _username,
    ).then((_) {
      if (mounted) {
        setState(() {
          _importing = false;
          _statusMessage = '';
        });
        final remaining = _gamesByMonth.values
            .where((g) => g != null)
            .fold(0, (s, g) => s + g!.length);
        if (remaining == 0) Navigator.pop(context);
      }
    });
  }

  Future<void> _changeUsername() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('Change Chess.com username?',
            style: TextStyle(color: AppTheme.textPrimary)),
        content: const Text(
          'This will clear the saved username and sync history. Your already-imported games will not be affected.',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Change'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await ChessComService.clearUsername();
      setState(() {
        _username = '';
        _hasSavedUsername = false;
        _lastSyncTime = null;
        _usernameCtrl.clear();
        _archiveUrls = [];
        _gamesByMonth.clear();
        _expanded.clear();
        _selected.clear();
        _statusMessage = '';
      });
    }
  }

  bool get _busy => _fetchingArchives || _importing || _importingAll;

  @override
  Widget build(BuildContext context) {
    if (_initializing) {
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: AppTheme.primary)));
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Import from Chess.com'),
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
          if (_lastSyncTime != null && _archiveUrls.isEmpty && !_fetchingArchives)
            _syncInfoBar(),
          if (_statusMessage.isNotEmpty) _statusBar(),
          if (_selected.isNotEmpty && !_busy) _selectionBar(),
          Expanded(child: _body()),
          if (_archiveUrls.isNotEmpty && !_busy) _importAllBar(),
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
              onSubmitted: (_) => _fetchArchives(),
              decoration: const InputDecoration(
                hintText: 'Chess.com username',
                prefixIcon: Icon(Icons.person_search_rounded, color: AppTheme.textSecondary),
              ),
            ),
          ),
          const SizedBox(width: 10),
          ElevatedButton(
            onPressed: _busy ? null : _fetchArchives,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(80, 52),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: _fetchingArchives
                ? const SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Sync'),
          ),
        ],
      ),
    );
  }

  Widget _syncInfoBar() {
    final dt = _lastSyncTime!;
    final label = 'Last synced: ${dt.day}/${dt.month}/${dt.year}';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: AppTheme.surfaceAlt,
      child: Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
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
          if (_importing || _importingAll || _fetchingArchives)
            const SizedBox(
              width: 14, height: 14,
              child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary),
            )
          else
            Icon(
              isError ? Icons.error_outline_rounded : Icons.info_outline_rounded,
              size: 16,
              color: isError ? AppTheme.loss : AppTheme.textSecondary,
            ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(_statusMessage,
                style: TextStyle(
                  color: isError ? AppTheme.loss : AppTheme.textSecondary,
                  fontSize: 13,
                )),
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
              minimumSize: const Size(100, 38),
              padding: const EdgeInsets.symmetric(horizontal: 16),
            ),
            child: const Text('Import Selected'),
          ),
        ],
      ),
    );
  }

  Widget _importAllBar() {
    final total = _gamesByMonth.values
        .where((g) => g != null)
        .fold(0, (s, g) => s + g!.length);
    final unloaded = _archiveUrls
        .where((url) => _gamesByMonth[ChessComService.monthKeyFromArchiveUrl(url)] == null)
        .length;
    final label = unloaded > 0
        ? 'Import All (${_archiveUrls.length} months)'
        : 'Import All Games ($total)';
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
          label: Text(label),
        ),
      ),
    );
  }

  Widget _body() {
    if (!_fetchingArchives && _archiveUrls.isEmpty && _username.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Text('♟', style: TextStyle(fontSize: 56)),
            SizedBox(height: 16),
            Text(
              'Enter your Chess.com username\nto import your games',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 15),
            ),
          ],
        ),
      );
    }

    if (_fetchingArchives && _archiveUrls.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: AppTheme.primary),
            SizedBox(height: 16),
            Text('Checking for new games...', style: TextStyle(color: AppTheme.textSecondary)),
          ],
        ),
      );
    }

    if (_archiveUrls.isEmpty && _username.isNotEmpty) {
      return const Center(
        child: Text('All games are up to date.',
            style: TextStyle(color: AppTheme.textSecondary)),
      );
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 8),
      children: _gamesByMonth.keys.map((monthKey) {
        final games = _gamesByMonth[monthKey];
        final isExpanded = _expanded[monthKey] ?? false;
        final isLoading = _loadingMonth[monthKey] ?? false;
        final monthSelectedCount = games == null
            ? 0
            : games.asMap().entries.where((e) => _selected.contains(_gameKey(monthKey, e.key))).length;

        return Card(
          margin: const EdgeInsets.fromLTRB(12, 6, 12, 0),
          child: Column(
            children: [
              InkWell(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                onTap: () => _toggleMonth(monthKey),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Row(
                    children: [
                      Icon(
                        isExpanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                        color: AppTheme.textSecondary,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              ChessComService.formatMonthKey(monthKey),
                              style: const TextStyle(
                                color: AppTheme.textPrimary,
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                            ),
                            Text(
                              games != null
                                  ? '${games.length} new game${games.length == 1 ? '' : 's'}'
                                      '${monthSelectedCount > 0 ? ' · $monthSelectedCount selected' : ''}'
                                  : 'Tap to load',
                              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      if (isLoading)
                        const SizedBox(
                          width: 16, height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary),
                        )
                      else if (games != null && games.isNotEmpty && !_busy)
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
              if (isExpanded) ...[
                if (isLoading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Center(child: CircularProgressIndicator(color: AppTheme.primary)),
                  )
                else if (games != null && games.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                    child: Text('All games in this month already imported.',
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                  )
                else if (games != null)
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
                          border: const Border(
                            top: BorderSide(color: AppTheme.surfaceAlt, width: 0.5),
                          ),
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
                                  Text(
                                    '${game.white} vs ${game.black}',
                                    style: const TextStyle(
                                      color: AppTheme.textPrimary,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Row(
                                    children: [
                                      _chip(_timeClassLabel(game.timeClass), AppTheme.textSecondary),
                                      const SizedBox(width: 6),
                                      _chip(_resultLabel(game.result), _resultColor(game.result)),
                                      const SizedBox(width: 6),
                                      Text(
                                        '${game.endTime.day}/${game.endTime.month}/${game.endTime.year}',
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
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600)),
    );
  }

  String _timeClassLabel(String tc) {
    switch (tc) {
      case 'bullet': return '⚡ Bullet';
      case 'blitz': return '🔥 Blitz';
      case 'rapid': return '⏱ Rapid';
      case 'daily': return '📅 Daily';
      default: return tc;
    }
  }

  String _resultLabel(String result) {
    if (result == '1-0') return 'White wins';
    if (result == '0-1') return 'Black wins';
    return 'Draw';
  }

  Color _resultColor(String result) {
    if (result == '1-0') return AppTheme.win;
    if (result == '0-1') return AppTheme.loss;
    return AppTheme.draw;
  }
}
