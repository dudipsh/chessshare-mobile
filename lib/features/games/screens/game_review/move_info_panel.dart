import 'package:flutter/material.dart';

import '../../models/analyzed_move.dart';

class MoveInfoPanel extends StatelessWidget {
  final AnalyzedMove move;
  final bool isDark;

  const MoveInfoPanel({
    super.key,
    required this.move,
    required this.isDark,
  });

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
          // Move notation
          Text(
            move.displayString,
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
                Text(
                  'Best: ${move.bestMove}',
                  style: TextStyle(
                    fontSize: 14,
                    color: MoveClassification.best.color,
                    fontWeight: FontWeight.w500,
                  ),
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
