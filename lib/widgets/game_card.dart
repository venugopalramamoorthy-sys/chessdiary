// lib/widgets/game_card.dart

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/game_model.dart';
import '../utils/theme.dart';
import '../utils/web_theme.dart';

class GameCard extends StatefulWidget {
  final ChessGame game;
  final VoidCallback? onTap;
  const GameCard({super.key, required this.game, this.onTap});

  @override
  State<GameCard> createState() => _GameCardState();
}

class _GameCardState extends State<GameCard> {
  bool _hovered = false;

  static const _sourceLabel = {
    'paper': 'Paper',
    'chess.com': 'Chess.com',
    'lichess': 'Lichess',
    'other': 'Other',
  };

  Color get _text  => kIsWeb ? WT.textColor : AppTheme.textPrimary;
  Color get _muted => kIsWeb ? WT.mutedColor : AppTheme.textSecondary;

  @override
  Widget build(BuildContext context) {
    final g           = widget.game;
    final result      = g.resultDisplay;
    final resultColor = kIsWeb ? WT.resultColor(result) : AppTheme.resultColor(result);
    final isWhite     = g.playerColor == 'white';
    final opponent    = g.opponentName.isEmpty ? 'Unknown' : g.opponentName;

    final details = <String>[
      _sourceLabel[g.source] ?? g.source,
      if (g.timeControl != null && g.timeControl!.isNotEmpty)
        '${g.timeControl![0].toUpperCase()}${g.timeControl!.substring(1)}',
      if (g.event != null && g.event!.trim().isNotEmpty) g.event!.trim(),
      '${g.totalMoves} moves',
    ];

    final card = Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: kIsWeb
          ? WT.cardDeco(hovered: _hovered, accentBorder: resultColor)
          : BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: resultColor.withValues(alpha: 0.3)),
            ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Result badge
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: resultColor.withValues(alpha: kIsWeb ? 0.1 : 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(result[0],
                  style: TextStyle(
                      color: resultColor, fontSize: 19, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Colour + opponent
                Row(
                  children: [
                    Tooltip(
                      message: isWhite ? 'You played White' : 'You played Black',
                      child: Container(
                        width: 11,
                        height: 11,
                        decoration: BoxDecoration(
                          color: isWhite ? Colors.white : const Color(0xFF111111),
                          shape: BoxShape.circle,
                          border: Border.all(color: _muted, width: 1),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'vs $opponent'
                        '${g.opponentRating != null ? ' (${g.opponentRating})' : ''}',
                        style: TextStyle(
                            color: _text, fontSize: 14, fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                if (g.opening != null && g.opening!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(g.opening!,
                      style: TextStyle(color: _muted, fontSize: 12),
                      overflow: TextOverflow.ellipsis),
                ],
                const SizedBox(height: 4),
                Text(details.join('  ·  '),
                    style: TextStyle(color: _muted, fontSize: 11),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 6),
                _analysisLine(g),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Date
          Text(
            DateFormat('dd MMM\nyyyy').format(g.datePlayed),
            textAlign: TextAlign.right,
            style: TextStyle(color: _muted, fontSize: 11),
          ),
        ],
      ),
    );

    if (kIsWeb) {
      return MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit:  (_) => setState(() => _hovered = false),
        child: GestureDetector(onTap: widget.onTap, child: card),
      );
    }
    return GestureDetector(onTap: widget.onTap, child: card);
  }

  Widget _analysisLine(ChessGame g) {
    if (!g.isAnalysed) {
      return _pill('Not analysed', _muted, icon: Icons.hourglass_empty_rounded);
    }
    final blunders = g.playerMoveCount('blunder');
    final mistakes = g.playerMoveCount('mistake');
    final good = kIsWeb ? WT.winColor : AppTheme.win;
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [
        _pill('Analysed', good, icon: Icons.check_rounded),
        if (blunders > 0)
          _pill('$blunders blunder${blunders == 1 ? '' : 's'}',
              kIsWeb ? WT.blunderColor : AppTheme.blunder),
        if (mistakes > 0)
          _pill('$mistakes mistake${mistakes == 1 ? '' : 's'}',
              kIsWeb ? WT.mistakeColor : AppTheme.mistake),
        if (blunders == 0 && mistakes == 0) _pill('No blunders', good),
      ],
    );
  }

  Widget _pill(String label, Color color, {IconData? icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 11, color: color),
            const SizedBox(width: 3),
          ],
          Text(label,
              style: TextStyle(color: color, fontSize: 10.5, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
