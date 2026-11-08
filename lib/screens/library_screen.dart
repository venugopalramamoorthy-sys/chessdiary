// lib/screens/library_screen.dart
//
// Game library: result tabs with counts, a search box, a Filters sheet
// (source / time control / colour / analysis / event), a sort menu, and the
// games grouped under month headings when sorted by date.

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../models/game_model.dart';
import '../services/game_service.dart';
import '../services/pgn_export_service.dart';
import '../utils/theme.dart';
import '../utils/web_theme.dart';
import '../widgets/game_card.dart';
import '../widgets/ad_banner_widget.dart';
import 'game_detail_screen.dart';

/// Everything except the result tab and the search text.
class _Filters {
  String source   = 'all'; // paper, chess.com, lichess, other
  String tc       = 'all'; // bullet, blitz, rapid, classical, correspondence
  String colour   = 'all'; // white, black
  String analysis = 'all'; // analysed, unanalysed
  String event    = 'all';

  _Filters();
  _Filters.from(_Filters o)
      : source = o.source, tc = o.tc, colour = o.colour,
        analysis = o.analysis, event = o.event;

  int get activeCount => [source, tc, colour, analysis, event]
      .where((v) => v != 'all').length;

  bool matches(ChessGame g) =>
      (source == 'all' || g.source == source) &&
      (tc == 'all' || g.timeControl == tc) &&
      (colour == 'all' || g.playerColor == colour) &&
      (analysis == 'all' || (analysis == 'analysed') == g.isAnalysed) &&
      (event == 'all' || (g.event ?? '').trim() == event);
}

class LibraryScreen extends StatefulWidget {
  /// 'all', 'Win', 'Loss' or 'Draw'. Applied on first build, and again
  /// (clearing every other filter) whenever [requestId] changes, so the
  /// Home screen's Wins/Losses/Draws/Total counters can open a fresh view.
  final String initialResult;
  final int requestId;
  const LibraryScreen({super.key, this.initialResult = 'all', this.requestId = 0});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  late String _result = widget.initialResult;
  _Filters _filters = _Filters();
  String _sort = 'newest';
  String _searchQuery = '';
  final _searchCtrl = TextEditingController();

  static const _sources = {
    'paper': 'Paper', 'chess.com': 'Chess.com', 'lichess': 'Lichess', 'other': 'Other',
  };
  static const _tcs = {
    'bullet': '⚡ Bullet', 'blitz': '🔥 Blitz', 'rapid': '⏱ Rapid',
    'classical': '🏛 Classical', 'correspondence': '📅 Correspondence',
  };
  static const _sorts = {
    'newest': 'Newest first', 'oldest': 'Oldest first',
    'opponent': 'Opponent A–Z', 'blunders': 'Most blunders',
  };

  bool get _web => kIsWeb;
  Color get _text   => _web ? WT.textColor : AppTheme.textPrimary;
  Color get _muted  => _web ? WT.mutedColor : AppTheme.textSecondary;
  Color get _accent => _web ? WT.greenAccent : AppTheme.primary;
  Color get _line   => _web ? WT.borderColor : AppTheme.surfaceAlt;
  Color get _card   => _web ? WT.cardBg : AppTheme.surface;

  @override
  void didUpdateWidget(LibraryScreen old) {
    super.didUpdateWidget(old);
    if (widget.requestId != old.requestId) {
      _result = widget.initialResult;
      _filters = _Filters();
      _searchQuery = '';
      _searchCtrl.clear();
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  bool _matchesSearch(ChessGame g) {
    final q = _searchQuery;
    if (q.isEmpty) return true;
    return g.opponentName.toLowerCase().contains(q) ||
        (g.opening?.toLowerCase().contains(q) ?? false) ||
        (g.notes?.toLowerCase().contains(q) ?? false) ||
        (g.event?.toLowerCase().contains(q) ?? false) ||
        g.tags.any((t) => t.toLowerCase().contains(q));
  }

  List<ChessGame> _sorted(List<ChessGame> games) {
    final list = [...games];
    switch (_sort) {
      case 'oldest':
        list.sort((a, b) => a.datePlayed.compareTo(b.datePlayed));
      case 'opponent':
        list.sort((a, b) =>
            a.opponentName.toLowerCase().compareTo(b.opponentName.toLowerCase()));
      case 'blunders':
        list.sort((a, b) {
          final d = b.playerMoveCount('blunder').compareTo(a.playerMoveCount('blunder'));
          return d != 0 ? d : b.datePlayed.compareTo(a.datePlayed);
        });
      default:
        list.sort((a, b) => b.datePlayed.compareTo(a.datePlayed));
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final hPad = _web ? 24.0 : 16.0;

    return Scaffold(
      bottomNavigationBar: const AdBannerWidget(),
      appBar: AppBar(
        title: _web
            ? Text('Game Library',
                style: GoogleFonts.playfairDisplay(
                    fontSize: 18, fontWeight: FontWeight.w700, color: WT.textColor))
            : const Text('Game Library'),
        actions: [
          IconButton(
            icon: Icon(Icons.download_rounded, color: _web ? WT.mutedColor : null),
            tooltip: 'Export all as PGN',
            onPressed: _exportAll,
          ),
        ],
      ),
      body: StreamBuilder<List<ChessGame>>(
        stream: GameService.gamesStream(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return _web
                ? const WebChessLoader(message: 'Loading your library…')
                : const Center(child: CircularProgressIndicator(color: AppTheme.primary));
          }
          final all = snap.data ?? [];
          if (all.isEmpty) return _emptyState();

          final base = all.where((g) => _filters.matches(g) && _matchesSearch(g)).toList();
          final counts = {
            'all':  base.length,
            'Win':  base.where((g) => g.resultDisplay == 'Win').length,
            'Loss': base.where((g) => g.resultDisplay == 'Loss').length,
            'Draw': base.where((g) => g.resultDisplay == 'Draw').length,
          };
          final shown = _sorted(_result == 'all'
              ? base
              : base.where((g) => g.resultDisplay == _result).toList());

          return Column(
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(hPad, 8, hPad, 0),
                child: _searchBox(),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(hPad, 10, hPad, 0),
                child: _resultTabs(counts),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(hPad, 8, hPad, 4),
                child: _toolbar(all),
              ),
              Expanded(
                child: shown.isEmpty
                    ? _noMatches()
                    : _gameList(shown, hPad),
              ),
            ],
          );
        },
      ),
    );
  }

  // ── search ────────────────────────────────────────────────────────────────
  Widget _searchBox() {
    return TextField(
      controller: _searchCtrl,
      onChanged: (v) => setState(() => _searchQuery = v.trim().toLowerCase()),
      style: _web ? GoogleFonts.inter(fontSize: 14, color: WT.textColor) : null,
      decoration: InputDecoration(
        isDense: true,
        hintText: 'Search opponent, opening, event, notes…',
        prefixIcon: Icon(Icons.search_rounded, color: _muted),
        suffixIcon: _searchQuery.isEmpty
            ? null
            : IconButton(
                icon: Icon(Icons.close_rounded, color: _muted, size: 18),
                tooltip: 'Clear search',
                onPressed: () => setState(() {
                  _searchCtrl.clear();
                  _searchQuery = '';
                }),
              ),
      ),
    );
  }

  // ── result tabs ───────────────────────────────────────────────────────────
  Widget _resultTabs(Map<String, int> counts) {
    Color colourFor(String r) => switch (r) {
          'Win'  => _web ? WT.winColor : AppTheme.win,
          'Loss' => _web ? WT.lossColor : AppTheme.loss,
          'Draw' => _web ? WT.drawColor : AppTheme.draw,
          _      => _accent,
        };
    const labels = {'all': 'All', 'Win': 'Wins', 'Loss': 'Losses', 'Draw': 'Draws'};

    return Container(
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(_web ? 4 : 12),
        border: Border.all(color: _line),
      ),
      child: Row(
        children: [
          for (final r in labels.keys)
            Expanded(
              child: InkWell(
                onTap: () => setState(() => _result = r),
                borderRadius: BorderRadius.circular(_web ? 4 : 12),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: _result == r
                        ? colourFor(r).withValues(alpha: 0.12)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(_web ? 4 : 12),
                    border: Border(
                      bottom: BorderSide(
                        color: _result == r ? colourFor(r) : Colors.transparent,
                        width: 2,
                      ),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('${counts[r]}',
                          style: TextStyle(
                              color: colourFor(r),
                              fontSize: 17,
                              fontWeight: FontWeight.bold)),
                      Text(labels[r]!,
                          style: TextStyle(
                              color: _result == r ? _text : _muted,
                              fontSize: 11,
                              fontWeight: _result == r ? FontWeight.w600 : FontWeight.normal)),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── filters button, sort menu, active filter chips ────────────────────────
  Widget _toolbar(List<ChessGame> all) {
    final active = <MapEntry<String, VoidCallback>>[
      if (_filters.source != 'all')
        MapEntry(_sources[_filters.source]!, () => _filters.source = 'all'),
      if (_filters.tc != 'all')
        MapEntry(_tcs[_filters.tc]!, () => _filters.tc = 'all'),
      if (_filters.colour != 'all')
        MapEntry(_filters.colour == 'white' ? 'As White' : 'As Black',
            () => _filters.colour = 'all'),
      if (_filters.analysis != 'all')
        MapEntry(_filters.analysis == 'analysed' ? 'Analysed' : 'Not analysed',
            () => _filters.analysis = 'all'),
      if (_filters.event != 'all')
        MapEntry(_filters.event, () => _filters.event = 'all'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _toolButton(
              icon: Icons.tune_rounded,
              label: _filters.activeCount == 0
                  ? 'Filters'
                  : 'Filters · ${_filters.activeCount}',
              highlighted: _filters.activeCount > 0,
              onTap: () => _openFilters(all),
            ),
            const SizedBox(width: 8),
            PopupMenuButton<String>(
              tooltip: 'Sort',
              initialValue: _sort,
              onSelected: (v) => setState(() => _sort = v),
              itemBuilder: (_) => [
                for (final e in _sorts.entries)
                  PopupMenuItem(value: e.key, child: Text(e.value)),
              ],
              child: _toolButton(
                icon: Icons.swap_vert_rounded,
                label: _sorts[_sort]!,
                highlighted: false,
                trailing: Icons.arrow_drop_down_rounded,
              ),
            ),
          ],
        ),
        if (active.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final a in active)
                InputChip(
                  label: Text(a.key, style: TextStyle(fontSize: 12, color: _text)),
                  onDeleted: () => setState(a.value),
                  deleteIconColor: _muted,
                  backgroundColor: _card,
                  side: BorderSide(color: _line),
                  visualDensity: VisualDensity.compact,
                ),
              TextButton(
                onPressed: () => setState(() => _filters = _Filters()),
                child: Text('Clear all', style: TextStyle(color: _accent, fontSize: 12)),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _toolButton({
    required IconData icon,
    required String label,
    required bool highlighted,
    VoidCallback? onTap,
    IconData? trailing,
  }) {
    final c = highlighted ? _accent : _muted;
    final box = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: highlighted ? _accent.withValues(alpha: 0.1) : _card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: highlighted ? _accent : _line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: c),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                  color: highlighted ? _accent : _text,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600)),
          if (trailing != null) Icon(trailing, size: 18, color: c),
        ],
      ),
    );
    if (onTap == null) return box;
    return InkWell(onTap: onTap, borderRadius: BorderRadius.circular(20), child: box);
  }

  // ── filters sheet ─────────────────────────────────────────────────────────
  Future<void> _openFilters(List<ChessGame> all) async {
    final draft = _Filters.from(_filters);
    final events = all
        .map((g) => (g.event ?? '').trim())
        .where((e) => e.isNotEmpty && e != '?')
        .toSet()
        .toList()
      ..sort();

    final applied = await showModalBottomSheet<_Filters>(
      context: context,
      isScrollControlled: true,
      backgroundColor: _card,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          final count = all.where((g) =>
              draft.matches(g) &&
              _matchesSearch(g) &&
              (_result == 'all' || g.resultDisplay == _result)).length;

          Widget group(String title, Map<String, String> options, String value,
              void Function(String) set) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title.toUpperCase(),
                      style: TextStyle(
                          color: _muted,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final e in {'all': 'Any', ...options}.entries)
                        ChoiceChip(
                          label: Text(e.value,
                              style: TextStyle(
                                  fontSize: 12,
                                  color: value == e.key ? _accent : _text)),
                          selected: value == e.key,
                          showCheckmark: false,
                          selectedColor: _accent.withValues(alpha: 0.12),
                          backgroundColor: _card,
                          side: BorderSide(color: value == e.key ? _accent : _line),
                          onSelected: (_) => setSheet(() => set(e.key)),
                        ),
                    ],
                  ),
                ],
              ),
            );
          }

          return SafeArea(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(ctx).height * 0.85, maxWidth: 640),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 8, 4),
                    child: Row(
                      children: [
                        Text('Filters',
                            style: TextStyle(
                                color: _text, fontSize: 18, fontWeight: FontWeight.bold)),
                        const Spacer(),
                        TextButton(
                          onPressed: () => setSheet(() {
                            draft.source = draft.tc = draft.colour =
                                draft.analysis = draft.event = 'all';
                          }),
                          child: Text('Reset', style: TextStyle(color: _accent)),
                        ),
                      ],
                    ),
                  ),
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          group('Source', _sources, draft.source,
                              (v) => draft.source = v),
                          group('Time control', _tcs, draft.tc, (v) => draft.tc = v),
                          group('Your colour', const {'white': 'White', 'black': 'Black'},
                              draft.colour, (v) => draft.colour = v),
                          group('Analysis',
                              const {'analysed': 'Analysed', 'unanalysed': 'Not analysed'},
                              draft.analysis, (v) => draft.analysis = v),
                          if (events.isNotEmpty)
                            group('Event', {for (final e in events) e: e}, draft.event,
                                (v) => draft.event = v),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: _accent,
                          foregroundColor: _web && WT.isDark ? Colors.black : Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: () => Navigator.pop(ctx, draft),
                        child: Text('Show $count game${count == 1 ? '' : 's'}'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
    if (applied != null && mounted) setState(() => _filters = applied);
  }

  // ── list, grouped by month when sorted by date ────────────────────────────
  Widget _gameList(List<ChessGame> games, double hPad) {
    final byDate = _sort == 'newest' || _sort == 'oldest';
    final rows = <Object>[]; // String month key or ChessGame
    final groups = <String, List<ChessGame>>{};
    if (byDate) {
      for (final g in games) {
        final key = DateFormat('MMMM yyyy').format(g.datePlayed);
        if (!groups.containsKey(key)) rows.add(key);
        (groups[key] ??= []).add(g);
        rows.add(g);
      }
    } else {
      rows.addAll(games);
    }

    return ListView.builder(
      padding: EdgeInsets.fromLTRB(hPad, 4, hPad, 96),
      itemCount: rows.length + (byDate ? 0 : 1),
      itemBuilder: (_, i) {
        if (!byDate) {
          if (i == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8, top: 4),
              child: Text('${games.length} game${games.length == 1 ? '' : 's'}',
                  style: TextStyle(color: _muted, fontSize: 12)),
            );
          }
          return _gameCard(rows[i - 1] as ChessGame);
        }
        final row = rows[i];
        if (row is String) return _monthHeader(row, groups[row]!, first: i == 0);
        return _gameCard(row as ChessGame);
      },
    );
  }

  Widget _gameCard(ChessGame g) => GameCard(
        game: g,
        onTap: () => Navigator.push(
            context, MaterialPageRoute(builder: (_) => GameDetailScreen(game: g))),
      );

  Widget _monthHeader(String month, List<ChessGame> games, {required bool first}) {
    final w = games.where((g) => g.resultDisplay == 'Win').length;
    final l = games.where((g) => g.resultDisplay == 'Loss').length;
    final d = games.length - w - l;
    return Padding(
      padding: EdgeInsets.only(top: first ? 8 : 18, bottom: 10),
      child: Row(
        children: [
          Text(month.toUpperCase(),
              style: TextStyle(
                  color: _text,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1)),
          const SizedBox(width: 10),
          Expanded(child: Divider(color: _line, height: 1)),
          const SizedBox(width: 10),
          Text(
            '${games.length} game${games.length == 1 ? '' : 's'}  ·  ${w}W ${l}L ${d}D',
            style: TextStyle(color: _muted, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _noMatches() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off_rounded, size: 40, color: _muted),
            const SizedBox(height: 12),
            Text('No games match these filters',
                style: TextStyle(color: _text, fontSize: 15, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => setState(() {
                _filters = _Filters();
                _result = 'all';
                _searchCtrl.clear();
                _searchQuery = '';
              }),
              child: Text('Show all games', style: TextStyle(color: _accent)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportAll() async {
    try {
      final games = await GameService.getAllGames();
      if (!mounted) return;
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
    if (_web) {
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
                  color: AppTheme.textPrimary, fontSize: 20, fontWeight: FontWeight.bold)),
          SizedBox(height: 8),
          Text('Tap + Add Game to log your first game',
              style: TextStyle(color: AppTheme.textSecondary)),
        ],
      ),
    );
  }
}
