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

  String? _getBestMoveSan() {
    final bestMove = move.bestMove;
    final bestMoveUci = move.bestMoveUci;

    if (bestMove == null || bestMove.isEmpty) {
      return null;
    }

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
    final classColor = move.classification.color;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: classColor.withValues(alpha: 0.4),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: classColor.withValues(alpha: isDark ? 0.15 : 0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Classification badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  classColor,
                  classColor.withValues(alpha: 0.8),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: classColor.withValues(alpha: 0.4),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(move.classification.icon, size: 18, color: Colors.white),
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
          const SizedBox(width: 14),
          // Move notation with piece icon
          Expanded(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isWhite ? '${move.fullMoveNumber}. ' : '${move.fullMoveNumber}... ',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                ),
                MoveWithPieceIcon(
                  san: move.san,
                  isWhite: isWhite,
                  fontSize: 18,
                  pieceSize: 22,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ],
            ),
          ),
          // Best move suggestion if different
          if (bestMoveSan != null && bestMoveSan != move.san && !move.classification.isGood)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: MoveClassification.best.color.withValues(alpha: isDark ? 0.2 : 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: MoveClassification.best.color.withValues(alpha: 0.4),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Best: ',
                        style: TextStyle(
                          fontSize: 12,
                          color: MoveClassification.best.color,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      MoveWithPieceIcon(
                        san: bestMoveSan,
                        isWhite: isWhite,
                        fontSize: 13,
                        pieceSize: 16,
                        fontWeight: FontWeight.bold,
                        color: MoveClassification.best.color,
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    move.evalAfterDisplay,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
