import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/piece_icon.dart';
import '../../models/analyzed_move.dart';
import '../../utils/chess_position_utils.dart';

class MoveInfoPanel extends ConsumerWidget {
  final AnalyzedMove move;
  final bool isDark;

  const MoveInfoPanel({
    super.key,
    required this.move,
    required this.isDark,
  });

  /// Get the best move in SAN notation
  String? _getBestMoveSan() {
    final bestMove = move.bestMove;
    final bestMoveUci = move.bestMoveUci;

    if (bestMove == null || bestMove.isEmpty) {
      return null;
    }

    // Try to convert UCI to SAN if we have it and FEN
    if (bestMoveUci != null && bestMoveUci.isNotEmpty && move.fen.isNotEmpty) {
      final san = ChessPositionUtils.uciToSan(move.fen, bestMoveUci);
      if (san != null) return san;
    }

    return bestMove;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isWhite = move.color == 'white';
    final bestMoveSan = _getBestMoveSan();

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
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isWhite ? '${move.fullMoveNumber}. ' : '${move.fullMoveNumber}... ',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              MoveWithPieceIcon(
                san: move.san,
                isWhite: isWhite,
                fontSize: 18,
                pieceSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ],
          ),
          const Spacer(),
          // Best move suggestion if different
          if (bestMoveSan != null && bestMoveSan != move.san && !move.classification.isGood)
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
                    MoveWithPieceIcon(
                      san: bestMoveSan,
                      isWhite: isWhite,
                      fontSize: 14,
                      pieceSize: 18,
                      fontWeight: FontWeight.bold,
                      color: MoveClassification.best.color,
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
