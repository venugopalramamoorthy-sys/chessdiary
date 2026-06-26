import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../models/game_model.dart';
import '../services/account_link_service.dart';
import '../services/chess_com_service.dart';
import '../services/game_service.dart';
import '../services/import_manager.dart';
import '../utils/theme.dart';
import '../utils/web_theme.dart';

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
  String? _linkedUsername; // Firestore-bound account (locks UI)

  List<String> _archiveUrls = [];
  final Map<String, List<ChessComGame>?> _gamesByMonth = {};
  final Map<String, bool> _expanded = {};
  final Map<String, bool> _loadingMonth = {};
  final Set<String> _selected = {};
  Set<String> _importedUrls = {};

  String _gameKey(String month, int index) => '$month:$index';
  bool get _isLocked => _linkedUsername != null;
  bool get _busy => _fetchingArchives || _importing || _importingAll;

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
    final linked = await AccountLinkService.getLinkedUsername(AccountLinkService.chessCom);
    final saved = linked ?? await ChessComService.getSavedUsername();
    final lastSync = await ChessComService.getLastSyncTime();
    setState(() {
      _linkedUsername = linked;
      _hasSavedUsername = saved != null;
      _lastSyncTime = lastSync;
      if (saved != null) {
        _usernameCtrl.text = saved;
        _username = saved;
      }
      _initializing = false;
    });
    if (saved != null) {
      await _fetchArchives(incremental: true);
    }
  }

  Future<void> _fetchArchives({bool incremental = false}) async {
    final username = _isLocked ? _linkedUsername! : _usernameCtrl.text.trim();
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

      String? sinceMonthKey;
      if (incremental && _lastSyncTime != null) {
        final cutoff = DateTime(_lastSyncTime!.year, _lastSyncTime!.month - 1);
        sinceMonthKey =
            '${cutoff.year}-${cutoff.month.toString().padLeft(2, '0')}';
      }
      final filteredArchives =
          ChessComService.filterArchivesSince(archives, sinceMonthKey);

      final monthKeys = filteredArchives
          .map(ChessComService.monthKeyFromArchiveUrl)
          .where((k) => k.isNotEmpty)
          .toList();

      await ChessComService.saveUsername(username);

      // Lock account after first successful import
      if (_linkedUsername == null) {
        await AccountLinkService.linkAccount(AccountLinkService.chessCom, username);
        _linkedUsername = username;
      }

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
      if (mounted) {
        setState(() {
          _gamesByMonth[monthKey] = filtered;
          _loadingMonth[monthKey] = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingMonth[monthKey] = false);
    }
  }

  String _archiveUrlForMonth(String monthKey) => _archiveUrls.firstWhere(
        (url) => ChessComService.monthKeyFromArchiveUrl(url) == monthKey,
        orElse: () => '',
      );

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

      await ChessComService.fetchArchivesParallel(
        unloaded,
        onProgress: (done, total) {
          if (mounted) {
            setState(() => _statusMessage = 'Loading $done / $total months...');
          }
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
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No new games to import')),
          );
        }
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('An import is already in progress')),
        );
      }
      return;
    }

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

  // ── unlink flow (replaces old _changeUsername) ─────────────────────────────

  Future<void> _unlinkFlow() async {
    final web = kIsWeb;
    final username = _linkedUsername!;

    final understood = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _UnlinkWarningDialog(
        platform: 'Chess.com',
        username: username,
        web: web,
      ),
    );
    if (understood != true || !mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _UnlinkConfirmDialog(username: username, web: web),
    );
    if (confirmed != true || !mounted) return;

    await AccountLinkService.unlinkAccount(AccountLinkService.chessCom);
    await AccountLinkService.deleteLinkedGames(AccountLinkService.chessCom, username);
    await ChessComService.clearUsername();

    if (!mounted) return;
    setState(() {
      _linkedUsername = null;
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

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Chess.com account unlinked.')),
    );
  }

  // ── build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final web = kIsWeb;
    if (_initializing) {
      return Scaffold(
        backgroundColor: web ? WT.scaffoldBg : null,
        body: Center(
          child: web
              ? const WebChessLoader(message: 'Loading…')
              : const CircularProgressIndicator(color: AppTheme.primary),
        ),
      );
    }
    return Scaffold(
      backgroundColor: web ? WT.offWhite : null,
      appBar: web
          ? webAppBar(context, title: 'Import from Chess.com')
          : AppBar(title: const Text('Import from Chess.com')),
      body: Column(
        children: [
          _isLocked ? _linkedBanner() : _searchBar(),
          if (!_isLocked &&
              _lastSyncTime != null &&
              _archiveUrls.isEmpty &&
              !_fetchingArchives)
            _syncInfoBar(),
          if (_statusMessage.isNotEmpty) _statusBar(),
          if (_selected.isNotEmpty && !_busy) _selectionBar(),
          Expanded(child: _body()),
          if (_archiveUrls.isNotEmpty && !_busy) _importAllBar(),
        ],
      ),
    );
  }

  // ── locked-state banner ────────────────────────────────────────────────────

  Widget _linkedBanner() {
    final web = kIsWeb;
    if (web) {
      return Container(
        margin: const EdgeInsets.fromLTRB(24, 20, 24, 0),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: WT.white,
          border: const Border(left: BorderSide(color: WT.greenLt, width: 3)),
          boxShadow: [
            BoxShadow(
                color: WT.textColor.withValues(alpha: 0.06),
                blurRadius: 8,
                offset: const Offset(0, 2))
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: WT.greenLt.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(2),
                    ),
                    child: Text('LINKED ACCOUNT',
                        style: WT.labelSm(9, color: WT.greenLt)),
                  ),
                  const SizedBox(height: 10),
                  Text(_linkedUsername!,
                      style: WT.anton(22, color: WT.textColor, spacing: 0)),
                  if (_lastSyncTime != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Last synced ${_lastSyncTime!.day}/${_lastSyncTime!.month}/${_lastSyncTime!.year}',
                      style: WT.bodySm(12),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                ElevatedButton.icon(
                  onPressed: _busy ? null : () => _fetchArchives(incremental: true),
                  icon: const Icon(Icons.sync_rounded, size: 14),
                  label: const Text('Sync'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: WT.greenLt,
                    foregroundColor: WT.white,
                    shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.zero),
                    textStyle: WT.lora(13, weight: FontWeight.w600),
                    minimumSize: const Size(80, 36),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: _busy ? null : _unlinkFlow,
                  icon: Icon(Icons.link_off, size: 13, color: WT.loss),
                  label: Text('Unlink account',
                      style: WT.lora(12, color: WT.loss, weight: FontWeight.w600)),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    minimumSize: Size.zero,
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    // Android
    return Container(
      padding: const EdgeInsets.all(16),
      color: AppTheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.link_rounded, size: 11, color: AppTheme.primary),
                    SizedBox(width: 4),
                    Text('LINKED',
                        style: TextStyle(
                            color: AppTheme.primary,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2)),
                  ],
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: _busy ? null : () => _fetchArchives(incremental: true),
                icon: const Icon(Icons.sync_rounded,
                    size: 14, color: AppTheme.primary),
                label: const Text('Sync',
                    style: TextStyle(color: AppTheme.primary, fontSize: 12)),
                style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: Size.zero),
              ),
              const SizedBox(width: 4),
              TextButton.icon(
                onPressed: _busy ? null : _unlinkFlow,
                icon: const Icon(Icons.link_off,
                    size: 14, color: AppTheme.loss),
                label: const Text('Unlink',
                    style: TextStyle(color: AppTheme.loss, fontSize: 12)),
                style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: Size.zero),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.person_rounded,
                  size: 22, color: AppTheme.textSecondary),
              const SizedBox(width: 10),
              Text(_linkedUsername!,
                  style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.w600)),
            ],
          ),
          if (_lastSyncTime != null) ...[
            const SizedBox(height: 4),
            Text(
              'Last synced: ${_lastSyncTime!.day}/${_lastSyncTime!.month}/${_lastSyncTime!.year}',
              style: const TextStyle(
                  color: AppTheme.textSecondary, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  // ── unlocked-state search bar ──────────────────────────────────────────────

  Widget _searchBar() {
    final web = kIsWeb;
    if (web) {
      return Container(
        margin: const EdgeInsets.fromLTRB(24, 20, 24, 0),
        padding: const EdgeInsets.all(20),
        decoration: WT.cardDeco(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('LINK YOUR CHESS.COM ACCOUNT',
                style: WT.labelSm(9, color: WT.greenLt)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _usernameCtrl,
                    enabled: !_busy,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _fetchArchives(),
                    style: WT.lora(14, color: WT.textColor),
                    decoration: InputDecoration(
                      hintText: 'Your Chess.com username',
                      hintStyle: WT.lora(14, color: WT.border),
                      prefixIcon: Icon(Icons.person_search_rounded,
                          color: WT.mutedColor, size: 18),
                      enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: WT.border),
                          borderRadius: BorderRadius.zero),
                      focusedBorder: const OutlineInputBorder(
                          borderSide: BorderSide(color: WT.greenLt),
                          borderRadius: BorderRadius.zero),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _busy ? null : _fetchArchives,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: WT.greenLt,
                    foregroundColor: WT.white,
                    shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.zero),
                    minimumSize: const Size(80, 52),
                    textStyle: WT.lora(14, weight: FontWeight.w600),
                  ),
                  child: _fetchingArchives
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Text('Sync'),
                ),
              ],
            ),
          ],
        ),
      );
    }

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
                prefixIcon: Icon(Icons.person_search_rounded,
                    color: AppTheme.textSecondary),
              ),
            ),
          ),
          const SizedBox(width: 10),
          ElevatedButton(
            onPressed: _busy ? null : _fetchArchives,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(80, 52),
              shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: _fetchingArchives
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
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
      color: kIsWeb ? WT.cream : AppTheme.surfaceAlt,
      child: Text(label,
          style: TextStyle(
              color: kIsWeb ? WT.muted : AppTheme.textSecondary,
              fontSize: 12)),
    );
  }

  Widget _statusBar() {
    final web = kIsWeb;
    final isError = _statusMessage.startsWith('Error:') ||
        _statusMessage.startsWith('Import failed') ||
        _statusMessage.contains('not found');
    if (web) {
      return Container(
        width: double.infinity,
        margin: const EdgeInsets.fromLTRB(24, 8, 24, 0),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isError
              ? WT.loss.withValues(alpha: 0.06)
              : WT.cream,
          border: Border(
              left: BorderSide(
                  color: isError ? WT.loss : WT.muted, width: 2)),
        ),
        child: Row(
          children: [
            if (_busy)
              const SizedBox(
                  width: 13,
                  height: 13,
                  child: CircularProgressIndicator(
                      strokeWidth: 1.5, color: WT.greenLt))
            else
              Icon(
                isError
                    ? Icons.error_outline_rounded
                    : Icons.info_outline_rounded,
                size: 15,
                color: isError ? WT.loss : WT.muted,
              ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(_statusMessage,
                  style: WT.lora(13,
                      color: isError ? WT.loss : WT.muted)),
            ),
          ],
        ),
      );
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: isError
          ? AppTheme.loss.withValues(alpha: 0.15)
          : AppTheme.surfaceAlt,
      child: Row(
        children: [
          if (_importing || _importingAll || _fetchingArchives)
            const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppTheme.primary))
          else
            Icon(
              isError
                  ? Icons.error_outline_rounded
                  : Icons.info_outline_rounded,
              size: 16,
              color: isError ? AppTheme.loss : AppTheme.textSecondary,
            ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(_statusMessage,
                style: TextStyle(
                    color: isError
                        ? AppTheme.loss
                        : AppTheme.textSecondary,
                    fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Widget _selectionBar() {
    final web = kIsWeb;
    if (web) {
      return Container(
        margin: const EdgeInsets.fromLTRB(24, 8, 24, 0),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: WT.white,
          border: const Border(left: BorderSide(color: WT.greenLt, width: 3)),
          boxShadow: [
            BoxShadow(
                color: WT.textColor.withValues(alpha: 0.04), blurRadius: 4)
          ],
        ),
        child: Row(
          children: [
            Text('${_selected.length} selected',
                style: WT.lora(13,
                    color: WT.greenLt, weight: FontWeight.w600)),
            const Spacer(),
            TextButton(
              onPressed: () => setState(() => _selected.clear()),
              child: Text('Clear', style: WT.lora(13, color: WT.mutedColor)),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: _importSelected,
              style: ElevatedButton.styleFrom(
                backgroundColor: WT.greenLt,
                foregroundColor: WT.white,
                shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.zero),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16),
              ),
              child: const Text('Import Selected'),
            ),
          ],
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: AppTheme.primary.withValues(alpha: 0.12),
      child: Row(
        children: [
          Text('${_selected.length} selected',
              style: const TextStyle(
                  color: AppTheme.primary, fontWeight: FontWeight.w600)),
          const Spacer(),
          TextButton(
            onPressed: () => setState(() => _selected.clear()),
            child: const Text('Clear',
                style: TextStyle(color: AppTheme.textSecondary)),
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
    final web = kIsWeb;
    final total = _gamesByMonth.values
        .where((g) => g != null)
        .fold(0, (s, g) => s + g!.length);
    final unloaded = _archiveUrls
        .where((url) =>
            _gamesByMonth[ChessComService.monthKeyFromArchiveUrl(url)] == null)
        .length;
    final label = unloaded > 0
        ? 'Import All (${_archiveUrls.length} months)'
        : 'Import All Games ($total)';
    if (web) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
        decoration: const BoxDecoration(
          color: WT.white,
          border: Border(top: BorderSide(color: WT.border)),
        ),
        child: ElevatedButton.icon(
          onPressed: _importAll,
          icon: const Icon(Icons.download_rounded),
          label: Text(label),
          style: ElevatedButton.styleFrom(
            backgroundColor: WT.greenLt,
            foregroundColor: WT.white,
            shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.zero),
            minimumSize: const Size(double.infinity, 48),
            textStyle: WT.lora(14, weight: FontWeight.w600),
          ),
        ),
      );
    }
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
    final web = kIsWeb;

    if (!_fetchingArchives && _archiveUrls.isEmpty && _username.isEmpty) {
      if (web) {
        return const WebEmptyState(
          title: 'No account linked',
          subtitle:
              'Enter your Chess.com username above to link your account and start importing games.',
        );
      }
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
      if (web) {
        return WebChessLoader(
            message: _statusMessage.isNotEmpty
                ? _statusMessage
                : 'Checking for new games…');
      }
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: AppTheme.primary),
            SizedBox(height: 16),
            Text('Checking for new games...',
                style: TextStyle(color: AppTheme.textSecondary)),
          ],
        ),
      );
    }

    if (_archiveUrls.isEmpty && _username.isNotEmpty) {
      if (web) {
        return const WebEmptyState(
          title: 'All caught up',
          subtitle: 'No new games to import from Chess.com.',
        );
      }
      return const Center(
        child: Text('All games are up to date.',
            style: TextStyle(color: AppTheme.textSecondary)),
      );
    }

    return ListView(
      padding: EdgeInsets.only(bottom: 8, top: web ? 12 : 0),
      children: _gamesByMonth.keys.map((monthKey) {
        final games = _gamesByMonth[monthKey];
        final isExpanded = _expanded[monthKey] ?? false;
        final isLoading = _loadingMonth[monthKey] ?? false;
        final monthSelectedCount = games == null
            ? 0
            : games
                .asMap()
                .entries
                .where((e) => _selected.contains(_gameKey(monthKey, e.key)))
                .length;

        if (web) {
          return Container(
            margin: const EdgeInsets.fromLTRB(24, 0, 24, 8),
            decoration: WT.cardDeco(),
            child: _monthCardContent(monthKey, games, isExpanded, isLoading,
                monthSelectedCount, web),
          );
        }
        return Card(
          margin: const EdgeInsets.fromLTRB(12, 6, 12, 0),
          child: _monthCardContent(monthKey, games, isExpanded, isLoading,
              monthSelectedCount, web),
        );
      }).toList(),
    );
  }

  Widget _monthCardContent(
    String monthKey,
    List<ChessComGame>? games,
    bool isExpanded,
    bool isLoading,
    int monthSelectedCount,
    bool web,
  ) {
    return Column(
      children: [
        InkWell(
          borderRadius: web
              ? const BorderRadius.vertical(top: Radius.circular(4))
              : const BorderRadius.vertical(top: Radius.circular(16)),
          onTap: () => _toggleMonth(monthKey),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Icon(
                  isExpanded
                      ? Icons.expand_less_rounded
                      : Icons.expand_more_rounded,
                  color: web ? WT.muted : AppTheme.textSecondary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ChessComService.formatMonthKey(monthKey),
                        style: web
                            ? WT.lora(15,
                                color: WT.textColor, weight: FontWeight.w600)
                            : const TextStyle(
                                color: AppTheme.textPrimary,
                                fontWeight: FontWeight.w600,
                                fontSize: 15),
                      ),
                      Text(
                        games != null
                            ? '${games.length} new game${games.length == 1 ? '' : 's'}'
                                '${monthSelectedCount > 0 ? ' · $monthSelectedCount selected' : ''}'
                            : 'Tap to load',
                        style: web
                            ? WT.bodySm(12)
                            : const TextStyle(
                                color: AppTheme.textSecondary, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                if (isLoading)
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: web ? WT.greenLt : AppTheme.primary),
                  )
                else if (games != null && games.isNotEmpty && !_busy)
                  TextButton(
                    onPressed: () => _importMonth(monthKey),
                    style: TextButton.styleFrom(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text('Import month',
                        style: TextStyle(
                            color: web ? WT.greenLt : AppTheme.primary,
                            fontSize: 12)),
                  ),
              ],
            ),
          ),
        ),
        if (isExpanded) ...[
          Container(
              height: 1, color: web ? WT.border : AppTheme.surfaceAlt),
          if (isLoading)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: CircularProgressIndicator(
                    color: web ? WT.greenLt : AppTheme.primary),
              ),
            )
          else if (games != null && games.isEmpty)
            Padding(
              padding:
                  const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
              child: Text('All games in this month already imported.',
                  style: web
                      ? WT.bodySm(13)
                      : const TextStyle(
                          color: AppTheme.textSecondary, fontSize: 13)),
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
                    color: isSelected
                        ? (web
                            ? WT.greenLt.withValues(alpha: 0.05)
                            : AppTheme.primary.withValues(alpha: 0.08))
                        : null,
                    border: Border(
                      top: BorderSide(
                          color: web ? WT.border : AppTheme.surfaceAlt,
                          width: 0.5),
                    ),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Checkbox(
                        value: isSelected,
                        onChanged: (_) => setState(() {
                          if (isSelected) _selected.remove(key);
                          else _selected.add(key);
                        }),
                        activeColor:
                            web ? WT.greenLt : AppTheme.primary,
                        side: BorderSide(
                            color: web
                                ? WT.border
                                : AppTheme.textSecondary),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${game.white} vs ${game.black}',
                              style: web
                                  ? WT.lora(13,
                                      color: WT.textColor,
                                      weight: FontWeight.w500)
                                  : const TextStyle(
                                      color: AppTheme.textPrimary,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500),
                            ),
                            const SizedBox(height: 3),
                            Row(
                              children: [
                                _chip(_timeClassLabel(game.timeClass),
                                    web ? WT.muted : AppTheme.textSecondary),
                                const SizedBox(width: 6),
                                _chip(_resultLabel(game.result),
                                    _resultColor(game.result)),
                                const SizedBox(width: 6),
                                Text(
                                  '${game.endTime.day}/${game.endTime.month}/${game.endTime.year}',
                                  style: TextStyle(
                                      color: web
                                          ? WT.muted
                                          : AppTheme.textSecondary,
                                      fontSize: 11),
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
    );
  }

  Widget _chip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(kIsWeb ? 2 : 6),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 10, fontWeight: FontWeight.w600)),
    );
  }

  String _timeClassLabel(String tc) {
    switch (tc) {
      case 'bullet': return '⚡ Bullet';
      case 'blitz':  return '🔥 Blitz';
      case 'rapid':  return '⏱ Rapid';
      case 'daily':  return '📅 Daily';
      default:       return tc;
    }
  }

  String _resultLabel(String result) {
    if (result == '1-0') return 'White wins';
    if (result == '0-1') return 'Black wins';
    return 'Draw';
  }

  Color _resultColor(String result) {
    if (result == '1-0') return kIsWeb ? WT.win : AppTheme.win;
    if (result == '0-1') return kIsWeb ? WT.loss : AppTheme.loss;
    return kIsWeb ? WT.draw : AppTheme.draw;
  }
}

// ── Unlink warning dialog ────────────────────────────────────────────────────

class _UnlinkWarningDialog extends StatelessWidget {
  final String platform;
  final String username;
  final bool web;
  const _UnlinkWarningDialog(
      {required this.platform, required this.username, required this.web});

  @override
  Widget build(BuildContext context) =>
      web ? _buildWeb(context) : _buildAndroid(context);

  Widget _buildAndroid(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.surface,
      title: Text('Unlink $platform?',
          style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.w700)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.loss.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(8),
              border:
                  Border.all(color: AppTheme.loss.withValues(alpha: 0.30)),
            ),
            child: Text(
              'This will permanently delete all games imported from "$username" on $platform. '
              'This cannot be undone.',
              style: const TextStyle(color: AppTheme.loss, fontSize: 13),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Your manually added games, paper scoresheets, and games from other platforms are not affected.',
            style:
                TextStyle(color: AppTheme.textSecondary, fontSize: 13),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.loss),
          child: const Text('I understand, continue'),
        ),
      ],
    );
  }

  Widget _buildWeb(BuildContext context) {
    return Dialog(
      backgroundColor: WT.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('UNLINK $platform?'.toUpperCase(),
                  style: WT.anton(26, color: WT.textColor, spacing: 0)),
              const SizedBox(height: 4),
              Text('Linked as: $username', style: WT.bodySm(13)),
              const SizedBox(height: 20),
              Text(
                'This will permanently delete all games imported from "$username" on $platform.',
                style: WT.lora(14, color: WT.loss),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: WT.altBg,
                  border: Border(
                      left: BorderSide(color: WT.mutedColor, width: 3)),
                ),
                child: Text(
                  'Your manually added games, paper scoresheets, and games from other platforms will not be affected.',
                  style: WT.lora(13, color: WT.textColor),
                ),
              ),
              const SizedBox(height: 28),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: Text('Cancel',
                        style: WT.lora(13, color: WT.mutedColor)),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: WT.loss,
                      foregroundColor: WT.white,
                      shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.zero),
                      textStyle: WT.lora(13, weight: FontWeight.w600),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 14),
                    ),
                    child: const Text('I understand, continue'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Type-to-confirm dialog ───────────────────────────────────────────────────

class _UnlinkConfirmDialog extends StatefulWidget {
  final String username;
  final bool web;
  const _UnlinkConfirmDialog({required this.username, required this.web});

  @override
  State<_UnlinkConfirmDialog> createState() => _UnlinkConfirmDialogState();
}

class _UnlinkConfirmDialogState extends State<_UnlinkConfirmDialog> {
  final _ctrl = TextEditingController();
  bool _matches = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      widget.web ? _buildWeb(context) : _buildAndroid(context);

  Widget _buildAndroid(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.surface,
      title: const Text('Confirm deletion',
          style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.w700)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Type "${widget.username}" to confirm.',
            style:
                const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _ctrl,
            autofocus: true,
            onChanged: (v) =>
                setState(() => _matches = v.trim() == widget.username),
            style: const TextStyle(color: AppTheme.textPrimary),
            decoration: InputDecoration(
              hintText: widget.username,
              border: const OutlineInputBorder(),
              focusedBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: AppTheme.primary)),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed:
              _matches ? () => Navigator.pop(context, true) : null,
          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.loss),
          child: const Text('Delete & unlink'),
        ),
      ],
    );
  }

  Widget _buildWeb(BuildContext context) {
    return Dialog(
      backgroundColor: WT.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('FINAL CONFIRMATION',
                  style: WT.anton(22, color: WT.textColor, spacing: 0)),
              const SizedBox(height: 8),
              RichText(
                text: TextSpan(
                  style: WT.lora(13, color: WT.mutedColor),
                  children: [
                    const TextSpan(text: 'Type '),
                    TextSpan(
                      text: '"${widget.username}"',
                      style: WT.lora(13,
                          color: WT.textColor, weight: FontWeight.w700),
                    ),
                    const TextSpan(
                        text: ' exactly to confirm permanent deletion.'),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _ctrl,
                autofocus: true,
                onChanged: (v) =>
                    setState(() => _matches = v.trim() == widget.username),
                style: WT.lora(14, color: WT.textColor),
                decoration: InputDecoration(
                  hintText: widget.username,
                  hintStyle: WT.lora(14, color: WT.border),
                  enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: WT.border),
                      borderRadius: BorderRadius.zero),
                  focusedBorder: const OutlineInputBorder(
                      borderSide: BorderSide(color: WT.greenLt),
                      borderRadius: BorderRadius.zero),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 12),
                ),
              ),
              const SizedBox(height: 28),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: Text('Cancel',
                        style: WT.lora(13, color: WT.mutedColor)),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed:
                        _matches ? () => Navigator.pop(context, true) : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: WT.loss,
                      foregroundColor: WT.white,
                      disabledBackgroundColor: WT.border,
                      shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.zero),
                      textStyle: WT.lora(13, weight: FontWeight.w600),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 14),
                    ),
                    child: const Text('Delete & unlink'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
