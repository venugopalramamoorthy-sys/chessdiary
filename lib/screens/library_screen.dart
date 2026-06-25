// lib/screens/library_screen.dart

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import '../models/game_model.dart';
import '../services/game_service.dart';
import '../services/pgn_export_service.dart';
import '../utils/theme.dart';
import '../utils/web_theme.dart';
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
    final web = kIsWeb;
    final hPad = web ? 24.0 : 16.0;

    return Scaffold(
      appBar: AppBar(
        title: web
            ? Text('Game Library',
                style: GoogleFonts.playfairDisplay(
                    fontSize: 18, fontWeight: FontWeight.w700, color: WT.ink))
            : const Text('Game Library'),
        actions: [
          IconButton(
            icon: Icon(Icons.download_rounded,
                color: web ? WT.muted : null),
            tooltip: 'Export all as PGN',
            onPressed: _exportAll,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(110),
          child: Column(
            children: [
              Padding(
                padding: EdgeInsets.symmetric(horizontal: hPad, vertical: 4),
                child: TextField(
                  onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
                  style: web
                      ? GoogleFonts.inter(fontSize: 14, color: WT.ink)
                      : null,
                  decoration: InputDecoration(
                    hintText: 'Search by opponent or opening…',
                    prefixIcon: Icon(Icons.search_rounded,
                        color: web ? WT.muted : AppTheme.textSecondary),
                  ),
                ),
              ),
              _filterRow(hPad),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
      body: StreamBuilder<List<ChessGame>>(
        stream: GameService.gamesStream(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return web
                ? const WebChessLoader(message: 'Loading your library…')
                : const Center(
                    child: CircularProgressIndicator(color: AppTheme.primary));
          }

          final all      = snap.data ?? [];
          final filtered = all.where((g) {
            final matchSource = _filterSource == 'all' || g.source == _filterSource;
            final matchResult = _filterResult == 'all' || g.resultDisplay == _filterResult;
            final matchTC     = _filterTC == 'all' || g.timeControl == _filterTC;
            final matchSearch = _searchQuery.isEmpty ||
                g.opponentName.toLowerCase().contains(_searchQuery) ||
                (g.opening?.toLowerCase().contains(_searchQuery) ?? false) ||
                (g.notes?.toLowerCase().contains(_searchQuery) ?? false) ||
                (g.event?.toLowerCase().contains(_searchQuery) ?? false) ||
                g.tags.any((t) => t.toLowerCase().contains(_searchQuery));
            return matchSource && matchResult && matchTC && matchSearch;
          }).toList();

          if (all.isEmpty) return _emptyState(web);

          final list = Column(
            children: [
              Padding(
                padding: EdgeInsets.symmetric(horizontal: hPad, vertical: 8),
                child: Row(
                  children: [
                    Text(
                      '${filtered.length} game${filtered.length == 1 ? '' : 's'}',
                      style: web
                          ? WT.bodySm(13)
                          : const TextStyle(
                              color: AppTheme.textSecondary, fontSize: 13),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: EdgeInsets.symmetric(horizontal: hPad),
                  itemCount: filtered.length,
                  itemBuilder: (_, i) => GameCard(
                    game: filtered[i],
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => GameDetailScreen(game: filtered[i])),
                    ),
                  ),
                ),
              ),
            ],
          );

          return list;
        },
      ),
    );
  }

  Widget _filterRow(double hPad) {
    const tcOptions = ['bullet', 'blitz', 'rapid', 'classical', 'correspondence'];
    const tcEmoji   = {'bullet': '⚡', 'blitz': '🔥', 'rapid': '⏱', 'classical': '🏛', 'correspondence': '📅'};
    return SizedBox(
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: hPad),
        children: [
          ..._sources.map((s) => _chip(s, _filterSource == s,
              () => setState(() => _filterSource = s))),
          const SizedBox(width: 12),
          ..._results.skip(1).map((r) => _chip(
                r, _filterResult == r,
                () => setState(() => _filterResult = _filterResult == r ? 'all' : r),
                color: kIsWeb
                    ? (r == 'Win' ? WT.win : r == 'Loss' ? WT.loss : WT.draw)
                    : (r == 'Win' ? AppTheme.win : r == 'Loss' ? AppTheme.loss : AppTheme.draw),
              )),
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
    final web = kIsWeb;
    final c   = color ?? (web ? WT.accent : AppTheme.primary);
    return _ChipButton(
      label: label, selected: selected, onTap: onTap, color: c, web: web);
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

  Widget _emptyState(bool web) {
    if (web) {
      return const WebEmptyState(
        title: 'No games in your library yet',
        subtitle: 'Add your first game using the + button.',
      );
    }
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Text('♟', style: TextStyle(fontSize: 64)),
          SizedBox(height: 16),
          Text('No games yet',
              style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.bold)),
          SizedBox(height: 8),
          Text('Tap + Add Game to log your first game',
              style: TextStyle(color: AppTheme.textSecondary)),
        ],
      ),
    );
  }
}

// ── hover-aware filter chip ───────────────────────────────────────────────────
class _ChipButton extends StatefulWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color color;
  final bool web;
  const _ChipButton({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.color,
    required this.web,
  });

  @override
  State<_ChipButton> createState() => _ChipButtonState();
}

class _ChipButtonState extends State<_ChipButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final bg = widget.selected
        ? widget.color.withValues(alpha: 0.12)
        : (widget.web
            ? (_hovered ? WT.bgAlt : WT.card)
            : AppTheme.surface);
    final borderColor = widget.selected
        ? widget.color
        : (widget.web ? WT.border : AppTheme.surfaceAlt);

    final chip = AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
        boxShadow: widget.web && _hovered
            ? [const BoxShadow(color: Color(0x0A000000), blurRadius: 8, offset: Offset(0, 2))]
            : null,
      ),
      child: Text(
        widget.label,
        style: widget.web
            ? GoogleFonts.inter(
                fontSize: 12,
                color: widget.selected ? widget.color : WT.muted,
                fontWeight: widget.selected ? FontWeight.w600 : FontWeight.w500)
            : TextStyle(
                color: widget.selected ? widget.color : AppTheme.textSecondary,
                fontSize: 12,
                fontWeight: widget.selected ? FontWeight.w600 : FontWeight.normal),
      ),
    );

    if (widget.web) {
      return MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit:  (_) => setState(() => _hovered = false),
        child: GestureDetector(onTap: widget.onTap, child: chip),
      );
    }
    return GestureDetector(onTap: widget.onTap, child: chip);
  }
}
