import 'package:flutter/material.dart';
import '../models/game_model.dart';
import '../services/game_service.dart';
import '../utils/theme.dart';
import '../widgets/game_card.dart';
import 'game_detail_screen.dart';

class _OpponentStat {
  final String name;
  int wins = 0, losses = 0, draws = 0;
  int? lastRating;
  DateTime? lastPlayed;
  final List<ChessGame> games = [];

  _OpponentStat(this.name);

  int get total => wins + losses + draws;
  double get winRate => total == 0 ? 0 : wins / total;
}

class OpponentsScreen extends StatefulWidget {
  const OpponentsScreen({super.key});

  @override
  State<OpponentsScreen> createState() => _OpponentsScreenState();
}

class _OpponentsScreenState extends State<OpponentsScreen> {
  String _sort = 'games'; // 'games', 'winrate', 'recent', 'name'
  String _search = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Opponent Database'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort_rounded),
            onSelected: (v) => setState(() => _sort = v),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'games', child: Text('Most played')),
              PopupMenuItem(value: 'winrate', child: Text('Best win rate')),
              PopupMenuItem(value: 'recent', child: Text('Most recent')),
              PopupMenuItem(value: 'name', child: Text('Name A–Z')),
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

          // Build opponent stats
          final Map<String, _OpponentStat> stats = {};
          for (final g in all) {
            final opp = g.opponentName.trim();
            if (opp.isEmpty || opp.toLowerCase() == 'unknown') continue;
            final stat = stats.putIfAbsent(opp, () => _OpponentStat(opp));
            final r = g.resultDisplay;
            if (r == 'Win') stat.wins++;
            else if (r == 'Loss') stat.losses++;
            else stat.draws++;
            stat.games.add(g);
            if (g.opponentRating != null) stat.lastRating = g.opponentRating;
            if (stat.lastPlayed == null || g.datePlayed.isAfter(stat.lastPlayed!)) {
              stat.lastPlayed = g.datePlayed;
            }
          }

          if (stats.isEmpty) return _emptyState();

          var sorted = stats.values
              .where((s) => _search.isEmpty || s.name.toLowerCase().contains(_search.toLowerCase()))
              .toList();

          switch (_sort) {
            case 'winrate': sorted.sort((a, b) => b.winRate.compareTo(a.winRate)); break;
            case 'recent': sorted.sort((a, b) => (b.lastPlayed ?? DateTime(0)).compareTo(a.lastPlayed ?? DateTime(0))); break;
            case 'name': sorted.sort((a, b) => a.name.compareTo(b.name)); break;
            default: sorted.sort((a, b) => b.total.compareTo(a.total));
          }

          return Column(
            children: [
              // Search
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: TextField(
                  onChanged: (v) => setState(() => _search = v),
                  decoration: const InputDecoration(
                    hintText: 'Search opponents...',
                    prefixIcon: Icon(Icons.search_rounded, color: AppTheme.textSecondary),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  children: [
                    Text('${sorted.length} opponent${sorted.length == 1 ? '' : 's'}',
                        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  itemCount: sorted.length,
                  itemBuilder: (_, i) => _OpponentCard(stat: sorted[i]),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _emptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('👤', style: TextStyle(fontSize: 56)),
          SizedBox(height: 16),
          Text('No opponents yet',
              style: TextStyle(color: AppTheme.textPrimary, fontSize: 20, fontWeight: FontWeight.bold)),
          SizedBox(height: 8),
          Text('Add games with opponent names\nto build your database',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textSecondary)),
        ],
      ),
    );
  }
}

class _OpponentCard extends StatefulWidget {
  final _OpponentStat stat;
  const _OpponentCard({required this.stat});

  @override
  State<_OpponentCard> createState() => _OpponentCardState();
}

class _OpponentCardState extends State<_OpponentCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final s = widget.stat;
    final winPct = (s.winRate * 100).toStringAsFixed(0);
    final winColor = s.winRate >= 0.5 ? AppTheme.win : s.winRate >= 0.4 ? AppTheme.textSecondary : AppTheme.loss;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
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
              child: Row(
                children: [
                  // Avatar
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        s.name.isNotEmpty ? s.name[0].toUpperCase() : '?',
                        style: const TextStyle(
                            color: AppTheme.primary,
                            fontSize: 20,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(s.name,
                                  style: const TextStyle(
                                      color: AppTheme.textPrimary,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15)),
                            ),
                            if (s.lastRating != null)
                              Text('${s.lastRating}',
                                  style: const TextStyle(
                                      color: AppTheme.textSecondary, fontSize: 12)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text('${s.total} game${s.total == 1 ? '' : 's'}',
                                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                            const SizedBox(width: 8),
                            _badge('${s.wins}W', AppTheme.win),
                            const SizedBox(width: 4),
                            _badge('${s.losses}L', AppTheme.loss),
                            const SizedBox(width: 4),
                            _badge('${s.draws}D', AppTheme.draw),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('$winPct%',
                          style: TextStyle(
                              color: winColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 18)),
                      const Text('win rate',
                          style: TextStyle(color: AppTheme.textSecondary, fontSize: 10)),
                    ],
                  ),
                  const SizedBox(width: 4),
                  Icon(_expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                      color: AppTheme.textSecondary, size: 18),
                ],
              ),
            ),
          ),
          if (_expanded) ...[
            // W/L/D bar
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Row(
                  children: [
                    if (s.wins > 0) Flexible(flex: s.wins, child: Container(height: 6, color: AppTheme.win)),
                    if (s.losses > 0) Flexible(flex: s.losses, child: Container(height: 6, color: AppTheme.loss)),
                    if (s.draws > 0) Flexible(flex: s.draws, child: Container(height: 6, color: AppTheme.draw)),
                  ],
                ),
              ),
            ),
            Container(height: 1, color: AppTheme.surfaceAlt),
            // Last played
            if (s.lastPlayed != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
                child: Row(
                  children: [
                    const Icon(Icons.access_time_rounded, color: AppTheme.textSecondary, size: 13),
                    const SizedBox(width: 4),
                    Text(
                      'Last played: ${s.lastPlayed!.day}/${s.lastPlayed!.month}/${s.lastPlayed!.year}',
                      style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                    ),
                  ],
                ),
              ),
            // Game list
            ...s.games
                .toList()
                .reversed
                .take(5)
                .map((g) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
                      child: GameCard(
                        game: g,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => GameDetailScreen(game: g)),
                        ),
                      ),
                    )),
            if (s.games.length > 5)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  '+ ${s.games.length - 5} more game${s.games.length - 5 == 1 ? '' : 's'}',
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ),
            const SizedBox(height: 4),
          ],
        ],
      ),
    );
  }

  Widget _badge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600)),
    );
  }
}
