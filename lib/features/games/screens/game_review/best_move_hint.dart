import 'package:flutter/material.dart';

import '../../../../core/widgets/piece_icon.dart';
import '../../models/analyzed_move.dart';
import '../../models/move_classification.dart';
import '../../utils/chess_position_utils.dart';

class BestMoveHint extends StatelessWidget {
  final AnalyzedMove move;
  final bool isDark;

  const BestMoveHint({
    super.key,
    required this.move,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    if (move.bestMove == null) return const SizedBox.shrink();

    // Only show if current move wasn't the best
    final isBestMove = move.classification == MoveClassification.best ||
        move.classification == MoveClassification.brilliant ||
        move.classification == MoveClassification.great;
    if (isBestMove) return const SizedBox.shrink();

    // Validate that best move is actually legal for this position
    if (move.fen.isNotEmpty) {
      final validatedSan = ChessPositionUtils.validateMove(
        move.fen,
        move.bestMoveUci ?? move.bestMove!,
      );
      if (validatedSan == null) {
        return const SizedBox.shrink();
      }
    }

    // Get the best move in SAN notation
    final isWhite = move.color == 'white';
    String? bestMoveSan;
    if (move.bestMoveUci != null && move.bestMoveUci!.isNotEmpty && move.fen.isNotEmpty) {
      bestMoveSan = ChessPositionUtils.uciToSan(move.fen, move.bestMoveUci!);
    }
    bestMoveSan ??= move.bestMove;

    if (bestMoveSan == null || bestMoveSan.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.green.withValues(alpha: 0.15)
            : Colors.green.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.green.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.lightbulb_outline, size: 18, color: Colors.green[isDark ? 400 : 600]),
          const SizedBox(width: 8),
          Text(
            'Best: ',
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
          MoveWithPieceIcon(
            san: bestMoveSan,
            isWhite: isWhite,
            fontSize: 14,
            pieceSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.green[isDark ? 400 : 700],
          ),
          const Spacer(),
          Text(
            'Tap to explore',
            style: TextStyle(
              fontSize: 11,
              color: isDark ? Colors.grey[500] : Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }
}
