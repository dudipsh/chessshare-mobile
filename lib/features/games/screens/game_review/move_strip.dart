import 'package:flutter/material.dart';

import '../../../../app/theme/colors.dart';
import '../../models/analyzed_move.dart';

class MoveStrip extends StatefulWidget {
  final List<AnalyzedMove> moves;
  final int currentMoveIndex;
  final bool isDark;
  final ValueChanged<int> onMoveSelected;

  const MoveStrip({
    super.key,
    required this.moves,
    required this.currentMoveIndex,
    required this.isDark,
    required this.onMoveSelected,
  });

  @override
  State<MoveStrip> createState() => _MoveStripState();
}

class _MoveStripState extends State<MoveStrip> {
  late ScrollController _scrollController;
  static const double _itemWidth = 52.0;
  static const double _itemSpacing = 4.0;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToCurrentMove());
  }

  @override
  void didUpdateWidget(MoveStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentMoveIndex != widget.currentMoveIndex) {
      _scrollToCurrentMove();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToCurrentMove() {
    if (!_scrollController.hasClients || widget.moves.isEmpty) return;

    final targetIndex = widget.currentMoveIndex - 1;
    if (targetIndex < 0) return;

    final itemOffset = targetIndex * (_itemWidth + _itemSpacing);
    final viewportWidth = _scrollController.position.viewportDimension;
    final centerOffset = itemOffset - (viewportWidth / 2) + (_itemWidth / 2);

    _scrollController.animateTo(
      centerOffset.clamp(0.0, _scrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.moves.isEmpty) return const SizedBox.shrink();

    return Container(
      height: 40,
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: widget.isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: widget.isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.08),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: ListView.builder(
          controller: _scrollController,
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          itemCount: widget.moves.length,
          itemBuilder: (context, index) {
            final move = widget.moves[index];
            final isSelected = index == widget.currentMoveIndex - 1;
            final moveNumber = (index ~/ 2) + 1;
            final isWhite = index % 2 == 0;

            return Center(
              child: Padding(
                padding: EdgeInsets.only(
                  left: index == 0 ? 0 : _itemSpacing / 2,
                  right: index < widget.moves.length - 1 ? _itemSpacing / 2 : 0,
                ),
                child: _MoveChip(
                  move: move,
                  moveNumber: moveNumber,
                  isWhite: isWhite,
                  isSelected: isSelected,
                  isDark: widget.isDark,
                  onTap: () => widget.onMoveSelected(index + 1),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _MoveChip extends StatelessWidget {
  final AnalyzedMove move;
  final int moveNumber;
  final bool isWhite;
  final bool isSelected;
  final bool isDark;
  final VoidCallback onTap;

  const _MoveChip({
    required this.move,
    required this.moveNumber,
    required this.isWhite,
    required this.isSelected,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasClassification = move.classification != MoveClassification.none;
    final classColor = hasClassification ? move.classification.color : AppColors.primary;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        height: 28,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? classColor.withValues(alpha: 0.2)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: isSelected
              ? Border.all(color: classColor.withValues(alpha: 0.6), width: 1.5)
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Move number (only for white moves)
            if (isWhite)
              Text(
                '$moveNumber.',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.grey[600] : Colors.grey[500],
                ),
              ),
            if (isWhite) const SizedBox(width: 2),
            // Move SAN
            Text(
              move.san,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected
                    ? classColor
                    : (isDark ? Colors.white.withValues(alpha: 0.9) : Colors.black87),
              ),
            ),
            // Classification indicator
            if (hasClassification) ...[
              const SizedBox(width: 3),
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: classColor,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
