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

  @override
  Widget build(BuildContext context) {
    final result      = widget.game.resultDisplay;
    final resultColor = kIsWeb
        ? WT.resultColor(result)
        : AppTheme.resultColor(result);

    final card = Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: kIsWeb
          ? WT.cardDeco(hovered: _hovered, accentBorder: resultColor)
          : BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: resultColor.withValues(alpha: 0.3), width: 1),
            ),
      child: Row(
        children: [
          // Result badge
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: resultColor.withValues(alpha: kIsWeb ? 0.1 : 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                result[0],
                style: TextStyle(
                  color: resultColor,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),

          // Game info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'vs ${widget.game.opponentName.isEmpty ? "Unknown" : widget.game.opponentName}',
                  style: TextStyle(
                    color: kIsWeb ? WT.ink : AppTheme.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                if (widget.game.opening != null)
                  Text(
                    widget.game.opening!,
                    style: TextStyle(
                      color: kIsWeb ? WT.muted : AppTheme.textSecondary,
                      fontSize: 12,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    _chip(widget.game.source, Icons.source_rounded),
                    const SizedBox(width: 6),
                    _chip('${widget.game.totalMoves} moves',
                        Icons.format_list_numbered_rounded),
                  ],
                ),
              ],
            ),
          ),

          // Date
          Text(
            DateFormat('dd MMM\nyyyy').format(widget.game.datePlayed),
            textAlign: TextAlign.right,
            style: TextStyle(
              color: kIsWeb ? WT.muted : AppTheme.textSecondary,
              fontSize: 11,
            ),
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

  Widget _chip(String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: kIsWeb ? WT.bgAlt : AppTheme.surfaceAlt,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10,
              color: kIsWeb ? WT.muted : AppTheme.textSecondary),
          const SizedBox(width: 3),
          Text(label,
              style: TextStyle(
                  color: kIsWeb ? WT.muted : AppTheme.textSecondary,
                  fontSize: 10)),
        ],
      ),
    );
  }
}
