import 'package:flutter/material.dart';

import '../../models/analyzed_move.dart';
import '../../utils/chess_position_utils.dart';

class MoveInfoPanel extends StatelessWidget {
  final AnalyzedMove move;
  final bool isDark;

  const MoveInfoPanel({
    super.key,
    required this.move,
    required this.isDark,
  });

  /// Get the best move formatted with piece icon
  String _getFormattedBestMove() {
    final bestMove = move.bestMove;
    final bestMoveUci = move.bestMoveUci;

    if (bestMove == null || bestMove.isEmpty) {
      return '';
    }

    // Determine if it's white's move (for piece icon color)
    final isWhite = move.color == 'white';

    // Try to format with icon - use UCI if we have it and FEN
    if (bestMoveUci != null && bestMoveUci.isNotEmpty && move.fen.isNotEmpty) {
      return ChessPositionUtils.formatMoveWithIcon(
        bestMoveUci,
        fen: move.fen,
        isWhite: isWhite,
      );
    }

    // If bestMove looks like SAN, format it with icon
    return ChessPositionUtils.formatMoveWithIcon(
      bestMove,
      fen: move.fen,
      isWhite: isWhite,
    );
  }

  /// Get the played move formatted with piece icon
  String _getFormattedPlayedMove() {
    final san = move.san;
    if (san.isEmpty) return move.displayString;

    final isWhite = move.color == 'white';
    final formattedSan = ChessPositionUtils.formatMoveWithIcon(
      san,
      isWhite: isWhite,
    );

    if (isWhite) {
      return '${move.fullMoveNumber}. $formattedSan';
    } else {
      return '${move.fullMoveNumber}... $formattedSan';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: move.classification.color.withValues(alpha: 0.1),
        border: Border(
          top: BorderSide(color: move.classification.color.withValues(alpha: 0.3)),
          bottom: BorderSide(color: move.classification.color.withValues(alpha: 0.3)),
        ),
      ),
      child: Row(
        children: [
          // Classification badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: move.classification.color,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(move.classification.icon, size: 16, color: Colors.white),
                const SizedBox(width: 6),
                Text(
                  move.classification.displayName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Move notation with piece icon
          Text(
            _getFormattedPlayedMove(),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          // Best move suggestion if different
          if (move.bestMove != null && move.bestMove != move.san && !move.classification.isGood)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Best: ',
                      style: TextStyle(
                        fontSize: 14,
                        color: MoveClassification.best.color,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      _getFormattedBestMove(),
                      style: TextStyle(
                        fontSize: 14,
                        color: MoveClassification.best.color,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Text(
                  move.evalAfterDisplay,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
