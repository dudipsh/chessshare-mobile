import 'package:flutter/material.dart';

import '../../../app/theme/colors.dart';

class MoveList extends StatefulWidget {
  final List<String> moves;
  final int currentIndex;
  final Function(int) onMoveSelected;

  const MoveList({
    super.key,
    required this.moves,
    required this.currentIndex,
    required this.onMoveSelected,
  });

  @override
  State<MoveList> createState() => _MoveListState();
}

class _MoveListState extends State<MoveList> {
  final ScrollController _scrollController = ScrollController();

  @override
  void didUpdateWidget(MoveList oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Auto-scroll to current move
    if (widget.currentIndex != oldWidget.currentIndex) {
      _scrollToCurrentMove();
    }
  }

  void _scrollToCurrentMove() {
    if (widget.currentIndex < 0) return;

    // Calculate approximate position (each move pair row is ~40 pixels)
    final rowIndex = widget.currentIndex ~/ 2;
    final targetOffset = rowIndex * 40.0;

    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        targetOffset,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.moves.isEmpty) {
      return Center(
        child: Text(
          'No moves',
          style: TextStyle(color: Colors.white.withOpacity(0.5)),
        ),
      );
    }

    // Group moves into pairs (white move, black move)
    final movePairs = <_MovePair>[];
    for (var i = 0; i < widget.moves.length; i += 2) {
      movePairs.add(_MovePair(
        moveNumber: (i ~/ 2) + 1,
        whiteMove: widget.moves[i],
        whiteMoveIndex: i,
        blackMove: i + 1 < widget.moves.length ? widget.moves[i + 1] : null,
        blackMoveIndex: i + 1 < widget.moves.length ? i + 1 : null,
      ));
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Text(
                  'Moves',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Text(
                  '${widget.moves.length} moves',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.5),
                  ),
                ),
              ],
            ),
          ),

          // Move list
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: movePairs.length,
              itemBuilder: (context, index) {
                final pair = movePairs[index];
                return _buildMovePairRow(pair);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMovePairRow(_MovePair pair) {
    return Container(
      height: 40,
      margin: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          // Move number
          SizedBox(
            width: 40,
            child: Text(
              '${pair.moveNumber}.',
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),

          // White move
          Expanded(
            child: _buildMoveButton(
              move: pair.whiteMove,
              index: pair.whiteMoveIndex,
              isWhite: true,
            ),
          ),

          const SizedBox(width: 8),

          // Black move
          Expanded(
            child: pair.blackMove != null
                ? _buildMoveButton(
                    move: pair.blackMove!,
                    index: pair.blackMoveIndex!,
                    isWhite: false,
                  )
                : const SizedBox(),
          ),
        ],
      ),
    );
  }

  Widget _buildMoveButton({
    required String move,
    required int index,
    required bool isWhite,
  }) {
    final isSelected = index == widget.currentIndex;

    return GestureDetector(
      onTap: () => widget.onMoveSelected(index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.accent.withOpacity(0.2)
              : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(6),
          border: isSelected
              ? Border.all(color: AppColors.accent.withOpacity(0.5))
              : null,
        ),
        child: Row(
          children: [
            // Piece color indicator
            Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.only(right: 6),
              decoration: BoxDecoration(
                color: isWhite ? Colors.white : Colors.black,
                border: Border.all(
                  color: Colors.grey.shade600,
                  width: 0.5,
                ),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Move text
            Text(
              move,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? AppColors.accent : Colors.white,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MovePair {
  final int moveNumber;
  final String whiteMove;
  final int whiteMoveIndex;
  final String? blackMove;
  final int? blackMoveIndex;

  _MovePair({
    required this.moveNumber,
    required this.whiteMove,
    required this.whiteMoveIndex,
    this.blackMove,
    this.blackMoveIndex,
  });
}
