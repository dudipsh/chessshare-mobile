import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/colors.dart';
import '../../../../core/widgets/piece_icon.dart';
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
  static const double _itemWidth = 56.0;
  static const double _itemSpacing = 6.0;

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
      height: 44,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      decoration: BoxDecoration(
        color: widget.isDark ? const Color(0xFF1C1C1E) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: widget.isDark ? 0.3 : 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: ListView.builder(
          controller: _scrollController,
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          itemCount: widget.moves.length,
          itemBuilder: (context, index) {
            final move = widget.moves[index];
            final isSelected = index == widget.currentMoveIndex - 1;
            final moveNumber = (index ~/ 2) + 1;
            final isWhite = index % 2 == 0;

            return Padding(
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
            );
          },
        ),
      ),
    );
  }
}

class _MoveChip extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final hasClassification = move.classification != MoveClassification.none;
    final classColor = hasClassification ? move.classification.color : AppColors.primary;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? classColor.withValues(alpha: isDark ? 0.3 : 0.15)
              : (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade100),
          borderRadius: BorderRadius.circular(10),
          border: isSelected
              ? Border.all(color: classColor.withValues(alpha: 0.7), width: 2)
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
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.grey.shade500 : Colors.grey.shade500,
                ),
              ),
            if (isWhite) const SizedBox(width: 3),
            // Move SAN with piece icon
            MoveWithPieceIcon(
              san: move.san,
              isWhite: isWhite,
              fontSize: 13,
              pieceSize: 16,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected
                  ? classColor
                  : (isDark ? Colors.white.withValues(alpha: 0.9) : Colors.black87),
            ),
            // Classification indicator
            if (hasClassification) ...[
              const SizedBox(width: 4),
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: classColor,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: classColor.withValues(alpha: 0.5),
                      blurRadius: 4,
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
