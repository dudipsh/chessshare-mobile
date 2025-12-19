import 'package:flutter/material.dart';

import '../../models/analyzed_move.dart';
import '../../widgets/move_markers.dart';

class MovesList extends StatelessWidget {
  final List<AnalyzedMove> moves;
  final int currentMoveIndex;
  final bool isDark;
  final ValueChanged<int> onMoveSelected;

  const MovesList({
    super.key,
    required this.moves,
    required this.currentMoveIndex,
    required this.isDark,
    required this.onMoveSelected,
  });

  @override
  Widget build(BuildContext context) {
    if (moves.isEmpty) return const SizedBox.shrink();

    // Group moves into pairs (white + black per row)
    final moveRows = <List<AnalyzedMove>>[];
    for (var i = 0; i < moves.length; i += 2) {
      final pair = <AnalyzedMove>[moves[i]];
      if (i + 1 < moves.length) {
        pair.add(moves[i + 1]);
      }
      moveRows.add(pair);
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      itemCount: moveRows.length,
      itemBuilder: (context, rowIndex) {
        final pair = moveRows[rowIndex];
        final moveNumber = rowIndex + 1;

        return Container(
          margin: const EdgeInsets.symmetric(vertical: 2),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: rowIndex.isEven
                ? (isDark ? Colors.white.withValues(alpha: 0.03) : Colors.grey.withValues(alpha: 0.05))
                : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            children: [
              // Move number
              SizedBox(
                width: 28,
                child: Text(
                  '$moveNumber.',
                  style: TextStyle(
                    color: isDark ? Colors.grey[500] : Colors.grey[600],
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              // White move
              Expanded(
                child: _MoveCell(
                  move: pair[0],
                  moveIndex: rowIndex * 2,
                  currentMoveIndex: currentMoveIndex,
                  isDark: isDark,
                  onTap: () => onMoveSelected(rowIndex * 2 + 1),
                ),
              ),
              const SizedBox(width: 4),
              // Black move
              Expanded(
                child: pair.length > 1
                    ? _MoveCell(
                        move: pair[1],
                        moveIndex: rowIndex * 2 + 1,
                        currentMoveIndex: currentMoveIndex,
                        isDark: isDark,
                        onTap: () => onMoveSelected(rowIndex * 2 + 2),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MoveCell extends StatelessWidget {
  final AnalyzedMove move;
  final int moveIndex;
  final int currentMoveIndex;
  final bool isDark;
  final VoidCallback onTap;

  const _MoveCell({
    required this.move,
    required this.moveIndex,
    required this.currentMoveIndex,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = moveIndex == currentMoveIndex - 1;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? move.classification.color.withValues(alpha: 0.25)
              : move.classification.color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(4),
          border: isSelected
              ? Border.all(color: move.classification.color, width: 1.5)
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: MoveMarker(
                classification: move.classification,
                size: 16,
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                move.san,
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  fontSize: 13,
                  color: isDark ? Colors.white : Colors.black87,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
