import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../models/game_model.dart';
import '../services/game_service.dart';
import '../utils/theme.dart';
import '../utils/web_theme.dart';
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
    final web = kIsWeb;
    return Scaffold(
      backgroundColor: web ? WT.offWhite : null,
      appBar: web
          ? webAppBar(context, title: 'Events & Tournaments',
              automaticallyImplyLeading: false)
          : AppBar(title: const Text('Events & Tournaments')),
      body: WebBodyWithTabs(
        tabs: web
            ? [
                WebTabItem('HOME', WT.charcoal,
                    () => Navigator.pop(context)),
                WebTabItem('LIBRARY', WT.charcoal,
                    () => Navigator.pop(context)),
              ]
            : [],
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(web ? 24 : 16, 12, web ? 24 : 16, 8),
              child: TextField(
                onChanged: (v) =>
                    setState(() => _opponentSearch = v.toLowerCase().trim()),
                style: web ? WT.lora(14, color: WT.ink) : null,
                decoration: InputDecoration(
                  hintText: 'Search by opponent name…',
                  prefixIcon: Icon(Icons.person_search_rounded,
                      color: web ? WT.muted : AppTheme.textSecondary),
                ),
              ),
            ),
            Expanded(
              child: StreamBuilder<List<ChessGame>>(
                stream: GameService.gamesStream(),
                builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return web
                ? const WebChessLoader(message: 'Loading events…')
                : const Center(child: CircularProgressIndicator(color: AppTheme.primary));
          }
          final all = snap.data ?? [];

          final filtered = _opponentSearch.isEmpty
              ? all
              : all.where((g) => g.opponentName.toLowerCase().contains(_opponentSearch)).toList();

          final Map<String, List<ChessGame>> byEvent = {};
          for (final g in filtered) {
            final key = (g.event?.trim().isNotEmpty == true) ? g.event! : '(No event)';
            (byEvent[key] ??= []).add(g);
          }
          final keys = byEvent.keys.toList()
            ..sort((a, b) {
              if (a == '(No event)') return 1;
              if (b == '(No event)') return -1;
              return a.compareTo(b);
            });

          if (keys.isEmpty) {
            return kIsWeb
                ? const WebEmptyState(
                    title: 'No events yet',
                    subtitle:
                        'Tag games with an event name when adding them.',
                  )
                : Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Text('🏆', style: TextStyle(fontSize: 56)),
                        SizedBox(height: 16),
                        Text('No events yet',
                            style: TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 20,
                                fontWeight: FontWeight.bold)),
                        SizedBox(height: 8),
                        Text('Tag games with an event name when adding them',
                            style: TextStyle(color: AppTheme.textSecondary),
                            textAlign: TextAlign.center),
                      ],
                    ),
                  );
          }

          return ListView.builder(
            padding: EdgeInsets.all(kIsWeb ? 24 : 16),
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
    final web = kIsWeb;
    final games = widget.games;
    final wins = games.where((g) => g.resultDisplay == 'Win').length;
    final losses = games.where((g) => g.resultDisplay == 'Loss').length;
    final draws = games.where((g) => g.resultDisplay == 'Draw').length;
    final total = games.length;
    final isNoEvent = widget.eventName == '(No event)';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: web
          ? WT.cardDeco()
          : BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(16),
            ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.vertical(
              top: web ? const Radius.circular(4) : const Radius.circular(16),
              bottom: _expanded
                  ? Radius.zero
                  : (web ? const Radius.circular(4) : const Radius.circular(16)),
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
                          ? (web ? WT.cream : AppTheme.surfaceAlt)
                          : (web
                              ? WT.greenLt.withValues(alpha: 0.10)
                              : AppTheme.primary.withValues(alpha: 0.15)),
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
                          style: web
                              ? WT.lora(14, color: WT.ink, weight: FontWeight.w600)
                              : const TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(
                              '$total game${total == 1 ? '' : 's'}',
                              style: web
                                  ? WT.bodySm(12)
                                  : const TextStyle(
                                      color: AppTheme.textSecondary, fontSize: 12),
                            ),
                            const SizedBox(width: 12),
                            _resultBadge('$wins W', web ? WT.win : AppTheme.win),
                            const SizedBox(width: 4),
                            _resultBadge('$losses L', web ? WT.loss : AppTheme.loss),
                            const SizedBox(width: 4),
                            _resultBadge('$draws D', web ? WT.draw : AppTheme.draw),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${total == 0 ? 0 : (wins / total * 100).toStringAsFixed(0)}%',
                        style: web
                            ? WT.anton(16, color: WT.greenLt, spacing: 0)
                            : const TextStyle(
                                color: AppTheme.primary,
                                fontWeight: FontWeight.bold,
                                fontSize: 16),
                      ),
                      Text(
                        'win rate',
                        style: web
                            ? WT.bodySm(10)
                            : const TextStyle(
                                color: AppTheme.textSecondary, fontSize: 10),
                      ),
                    ],
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    _expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                    color: web ? WT.muted : AppTheme.textSecondary,
                  ),
                ],
              ),
            ),
          ),
          if (_expanded) ...[
            Container(height: 1, color: web ? WT.border : AppTheme.surfaceAlt),
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
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label,
          style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}
