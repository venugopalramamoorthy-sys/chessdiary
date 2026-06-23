import 'package:flutter/material.dart';
import '../models/game_model.dart';
import '../services/game_service.dart';
import '../utils/theme.dart';
import '../widgets/game_card.dart';
import 'game_detail_screen.dart';

class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key});

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  String _opponentSearch = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Events & Tournaments')),
      body: Column(
        children: [
          // Opponent search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              onChanged: (v) => setState(() => _opponentSearch = v.toLowerCase().trim()),
              decoration: const InputDecoration(
                hintText: 'Search by opponent name...',
                prefixIcon: Icon(Icons.person_search_rounded, color: AppTheme.textSecondary),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<ChessGame>>(
        stream: GameService.gamesStream(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
          }
          final all = snap.data ?? [];

          // Filter by opponent if search is active
          final filtered = _opponentSearch.isEmpty
              ? all
              : all.where((g) => g.opponentName.toLowerCase().contains(_opponentSearch)).toList();

          // Group by event
          final Map<String, List<ChessGame>> byEvent = {};
          for (final g in filtered) {
            final key = (g.event?.trim().isNotEmpty == true) ? g.event! : '(No event)';
            (byEvent[key] ??= []).add(g);
          }
          // Sort: named events first alphabetically, then untagged last
          final keys = byEvent.keys.toList()
            ..sort((a, b) {
              if (a == '(No event)') return 1;
              if (b == '(No event)') return -1;
              return a.compareTo(b);
            });

          if (keys.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Text('🏆', style: TextStyle(fontSize: 56)),
                  SizedBox(height: 16),
                  Text('No events yet',
                      style: TextStyle(color: AppTheme.textPrimary, fontSize: 20, fontWeight: FontWeight.bold)),
                  SizedBox(height: 8),
                  Text('Tag games with an event name when adding them',
                      style: TextStyle(color: AppTheme.textSecondary), textAlign: TextAlign.center),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: keys.length,
            itemBuilder: (_, i) => _EventCard(
              eventName: keys[i],
              games: byEvent[keys[i]]!,
            ),
          );
        },
            ),
          ),
        ],
      ),
    );
  }
}

class _EventCard extends StatefulWidget {
  final String eventName;
  final List<ChessGame> games;

  const _EventCard({required this.eventName, required this.games});

  @override
  State<_EventCard> createState() => _EventCardState();
}

class _EventCardState extends State<_EventCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final games = widget.games;
    final wins = games.where((g) => g.resultDisplay == 'Win').length;
    final losses = games.where((g) => g.resultDisplay == 'Loss').length;
    final draws = games.where((g) => g.resultDisplay == 'Draw').length;
    final total = games.length;
    final isNoEvent = widget.eventName == '(No event)';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: isNoEvent
                          ? AppTheme.surfaceAlt
                          : AppTheme.primary.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        isNoEvent ? '📋' : '🏆',
                        style: const TextStyle(fontSize: 22),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.eventName,
                          style: const TextStyle(
                              color: AppTheme.textPrimary,
                              fontWeight: FontWeight.w600,
                              fontSize: 15),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text('$total game${total == 1 ? '' : 's'}',
                                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                            const SizedBox(width: 12),
                            _resultBadge('$wins W', AppTheme.win),
                            const SizedBox(width: 4),
                            _resultBadge('$losses L', AppTheme.loss),
                            const SizedBox(width: 4),
                            _resultBadge('$draws D', AppTheme.draw),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Win rate bar
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${total == 0 ? 0 : (wins / total * 100).toStringAsFixed(0)}%',
                        style: const TextStyle(
                            color: AppTheme.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 16),
                      ),
                      const Text('win rate',
                          style: TextStyle(color: AppTheme.textSecondary, fontSize: 10)),
                    ],
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    _expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                    color: AppTheme.textSecondary,
                  ),
                ],
              ),
            ),
          ),
          if (_expanded) ...[
            Container(height: 1, color: AppTheme.surfaceAlt),
            ...games.map((g) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: GameCard(
                    game: g,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => GameDetailScreen(game: g)),
                    ),
                  ),
                )),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }

  Widget _resultBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label,
          style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}
