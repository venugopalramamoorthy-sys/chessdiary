// lib/screens/library_screen.dart

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../models/game_model.dart';
import '../services/game_service.dart';
import '../services/pgn_export_service.dart';
import '../utils/theme.dart';
import '../widgets/game_card.dart';
import 'game_detail_screen.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  String _filterSource = 'all';
  String _filterResult = 'all';
  String _filterTC = 'all'; // time control
  String _searchQuery = '';

  final List<String> _sources = ['all', 'paper', 'chess.com', 'lichess', 'other'];
  final List<String> _results = ['all', 'Win', 'Loss', 'Draw'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Game Library'),
        actions: [
          IconButton(
            icon: const Icon(Icons.download_rounded),
            tooltip: 'Export all as PGN',
            onPressed: _exportAll,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(110),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: TextField(
                  onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
                  decoration: const InputDecoration(
                    hintText: 'Search by opponent or opening...',
                    prefixIcon: Icon(Icons.search_rounded, color: AppTheme.textSecondary),
                  ),
                ),
              ),
              _filterRow(),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
      body: StreamBuilder<List<ChessGame>>(
        stream: GameService.gamesStream(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
          }

          final all = snap.data ?? [];
          final filtered = all.where((g) {
            final matchSource = _filterSource == 'all' || g.source == _filterSource;
            final matchResult = _filterResult == 'all' || g.resultDisplay == _filterResult;
            final matchTC = _filterTC == 'all' || g.timeControl == _filterTC;
            final matchSearch = _searchQuery.isEmpty ||
                g.opponentName.toLowerCase().contains(_searchQuery) ||
                (g.opening?.toLowerCase().contains(_searchQuery) ?? false) ||
                (g.notes?.toLowerCase().contains(_searchQuery) ?? false) ||
                (g.event?.toLowerCase().contains(_searchQuery) ?? false) ||
                g.tags.any((t) => t.toLowerCase().contains(_searchQuery));
            return matchSource && matchResult && matchTC && matchSearch;
          }).toList();

          if (all.isEmpty) return _emptyState();

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Text(
                      '${filtered.length} game${filtered.length == 1 ? '' : 's'}',
                      style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: filtered.length,
                  itemBuilder: (_, i) => GameCard(
                    game: filtered[i],
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => GameDetailScreen(game: filtered[i]),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _filterRow() {
    const tcOptions = ['bullet', 'blitz', 'rapid', 'classical', 'correspondence'];
    const tcEmoji = {'bullet': '⚡', 'blitz': '🔥', 'rapid': '⏱', 'classical': '🏛', 'correspondence': '📅'};
    return SizedBox(
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          ..._sources.map((s) => _chip(s, _filterSource == s, () {
                setState(() => _filterSource = s);
              })),
          const SizedBox(width: 12),
          ..._results.skip(1).map((r) => _chip(r, _filterResult == r, () {
                setState(() => _filterResult = _filterResult == r ? 'all' : r);
              }, color: r == 'Win' ? AppTheme.win : r == 'Loss' ? AppTheme.loss : AppTheme.draw)),
          const SizedBox(width: 12),
          ...tcOptions.map((tc) => _chip(
                '${tcEmoji[tc]} ${tc[0].toUpperCase()}${tc.substring(1)}',
                _filterTC == tc,
                () => setState(() => _filterTC = _filterTC == tc ? 'all' : tc),
              )),
        ],
      ),
    );
  }

  Widget _chip(String label, bool selected, VoidCallback onTap, {Color? color}) {
    final c = color ?? AppTheme.primary;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? c.withOpacity(0.2) : AppTheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? c : AppTheme.surfaceAlt),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? c : AppTheme.textSecondary,
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Future<void> _exportAll() async {
    try {
      final games = await GameService.getAllGames();
      if (games.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No games to export')),
        );
        return;
      }
      final path = await PgnExportService.exportAll(games);
      if (path != null) {
        await Share.shareXFiles(
          [XFile(path)],
          text: 'My ChessDiary games (${games.length} total)',
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e'), backgroundColor: AppTheme.loss),
        );
      }
    }
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('♟', style: TextStyle(fontSize: 64)),
          const SizedBox(height: 16),
          const Text('No games yet',
              style: TextStyle(color: AppTheme.textPrimary, fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Tap + Add Game to log your first game',
              style: TextStyle(color: AppTheme.textSecondary)),
        ],
      ),
    );
  }
}
