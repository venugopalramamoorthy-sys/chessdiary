import 'package:flutter/material.dart';
import '../models/game_model.dart';
import '../services/game_service.dart';
import '../utils/theme.dart';
import 'library_screen.dart';
import 'game_detail_screen.dart';

class OpeningsScreen extends StatefulWidget {
  const OpeningsScreen({super.key});

  @override
  State<OpeningsScreen> createState() => _OpeningsScreenState();
}

class _OpeningsScreenState extends State<OpeningsScreen> {
  String _colorFilter = 'both'; // 'both', 'white', 'black'
  String _sort = 'games'; // 'games', 'winrate', 'name'

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Opening Repertoire'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort_rounded),
            onSelected: (v) => setState(() => _sort = v),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'games', child: Text('Sort by games played')),
              PopupMenuItem(value: 'winrate', child: Text('Sort by win rate')),
              PopupMenuItem(value: 'name', child: Text('Sort by name')),
            ],
          ),
        ],
      ),
      body: FutureBuilder<List<ChessGame>>(
        future: GameService.getAllGames(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
          }
          final all = snap.data ?? [];
          final withOpening = all.where((g) => g.opening != null && g.opening!.isNotEmpty).toList();

          if (withOpening.isEmpty) {
            return _emptyState();
          }

          // Build opening stats
          final Map<String, _OpeningStat> stats = {};
          for (final g in withOpening) {
            if (_colorFilter != 'both' && g.playerColor != _colorFilter) continue;
            final key = g.opening!;
            final stat = stats.putIfAbsent(key, () => _OpeningStat(key));
            final r = g.resultDisplay;
            if (r == 'Win') stat.wins++;
            else if (r == 'Loss') stat.losses++;
            else stat.draws++;
            stat.games.add(g);
          }

          if (stats.isEmpty) {
            return _emptyState();
          }

          var sorted = stats.values.toList();
          switch (_sort) {
            case 'winrate':
              sorted.sort((a, b) => b.winRate.compareTo(a.winRate));
              break;
            case 'name':
              sorted.sort((a, b) => a.name.compareTo(b.name));
              break;
            default:
              sorted.sort((a, b) => b.total.compareTo(a.total));
          }

          final needsReview = sorted.where((s) => s.total >= 3 && s.winRate < 0.4).length;

          return Column(
            children: [
              // Color filter
              Container(
                color: AppTheme.surface,
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                child: Row(
                  children: [
                    _colorChip('Both', 'both'),
                    const SizedBox(width: 8),
                    _colorChip('♙ White', 'white'),
                    const SizedBox(width: 8),
                    _colorChip('♟ Black', 'black'),
                    const Spacer(),
                    if (needsReview > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.loss.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '$needsReview needs review',
                          style: const TextStyle(color: AppTheme.loss, fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: sorted.length,
                  itemBuilder: (_, i) => _OpeningCard(
                    stat: sorted[i],
                    onGameTap: (g) => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => GameDetailScreen(game: g)),
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

  Widget _colorChip(String label, String value) {
    final selected = _colorFilter == value;
    return GestureDetector(
      onTap: () => setState(() => _colorFilter = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primary.withOpacity(0.2) : AppTheme.surfaceAlt,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? AppTheme.primary : Colors.transparent),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? AppTheme.primary : AppTheme.textSecondary,
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Text('📖', style: TextStyle(fontSize: 56)),
          SizedBox(height: 16),
          Text('No openings yet',
              style: TextStyle(color: AppTheme.textPrimary, fontSize: 20, fontWeight: FontWeight.bold)),
          SizedBox(height: 8),
          Text('Import games from Chess.com or Lichess\nto see your opening repertoire',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textSecondary)),
        ],
      ),
    );
  }
}

class _OpeningStat {
  final String name;
  int wins = 0, losses = 0, draws = 0;
  final List<ChessGame> games = [];

  _OpeningStat(this.name);

  int get total => wins + losses + draws;
  double get winRate => total == 0 ? 0 : wins / total;
  bool get needsReview => total >= 3 && winRate < 0.4;
}

class _OpeningCard extends StatefulWidget {
  final _OpeningStat stat;
  final void Function(ChessGame) onGameTap;

  const _OpeningCard({required this.stat, required this.onGameTap});

  @override
  State<_OpeningCard> createState() => _OpeningCardState();
}

class _OpeningCardState extends State<_OpeningCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final s = widget.stat;
    final needsReview = s.needsReview;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: needsReview
            ? Border.all(color: AppTheme.loss.withOpacity(0.4))
            : null,
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.vertical(
              top: const Radius.circular(16),
              bottom: _expanded ? Radius.zero : const Radius.circular(16),
            ),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          s.name,
                          style: const TextStyle(
                              color: AppTheme.textPrimary,
                              fontWeight: FontWeight.w600,
                              fontSize: 14),
                        ),
                      ),
                      if (needsReview)
                        Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppTheme.loss.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text('Needs Review',
                              style: TextStyle(color: AppTheme.loss, fontSize: 10, fontWeight: FontWeight.w600)),
                        ),
                      Text(
                        '${(s.winRate * 100).toStringAsFixed(0)}%',
                        style: TextStyle(
                          color: s.winRate >= 0.5 ? AppTheme.win : s.winRate >= 0.4 ? AppTheme.textSecondary : AppTheme.loss,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text('${s.total} game${s.total == 1 ? '' : 's'}',
                          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                      const SizedBox(width: 12),
                      _badge('${s.wins}W', AppTheme.win),
                      const SizedBox(width: 4),
                      _badge('${s.losses}L', AppTheme.loss),
                      const SizedBox(width: 4),
                      _badge('${s.draws}D', AppTheme.draw),
                      const Spacer(),
                      Icon(
                        _expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                        color: AppTheme.textSecondary, size: 18,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // W/L/D stacked bar
                  if (s.total > 0)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: Row(
                        children: [
                          if (s.wins > 0) Flexible(flex: s.wins, child: Container(height: 6, color: AppTheme.win)),
                          if (s.losses > 0) Flexible(flex: s.losses, child: Container(height: 6, color: AppTheme.loss)),
                          if (s.draws > 0) Flexible(flex: s.draws, child: Container(height: 6, color: AppTheme.draw)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (_expanded) ...[
            Container(height: 1, color: AppTheme.surfaceAlt),
            ...s.games.map((g) => ListTile(
                  dense: true,
                  leading: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppTheme.resultColor(g.resultDisplay).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        g.resultDisplay[0],
                        style: TextStyle(
                            color: AppTheme.resultColor(g.resultDisplay),
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  title: Text(
                    'vs ${g.opponentName.isEmpty ? "Unknown" : g.opponentName}',
                    style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                  ),
                  subtitle: Text(
                    '${g.playerColor == "white" ? "White" : "Black"} · ${g.datePlayed.day}/${g.datePlayed.month}/${g.datePlayed.year}',
                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded, color: AppTheme.textSecondary, size: 18),
                  onTap: () => widget.onGameTap(g),
                )),
            const SizedBox(height: 4),
          ],
        ],
      ),
    );
  }

  Widget _badge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}
