import 'package:flutter/material.dart';

/// Horizontal move strip with swipe navigation
class MoveStrip extends StatefulWidget {
  final List<String> moves;
  final int currentIndex;
  final ValueChanged<int> onMoveSelected;

  const MoveStrip({
    super.key,
    required this.moves,
    required this.currentIndex,
    required this.onMoveSelected,
  });

  @override
  State<MoveStrip> createState() => _MoveStripState();
}

class _MoveStripState extends State<MoveStrip> {
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(
      initialPage: widget.currentIndex + 1, // +1 for start position
      viewportFraction: 0.3,
    );
  }

  @override
  void didUpdateWidget(MoveStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentIndex != widget.currentIndex) {
      _pageController.animateToPage(
        widget.currentIndex + 1,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Total items: Start + all moves
    final totalItems = widget.moves.length + 1;

    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? Colors.white12 : Colors.grey.shade200,
          ),
          bottom: BorderSide(
            color: isDark ? Colors.white12 : Colors.grey.shade200,
          ),
        ),
      ),
      child: GestureDetector(
        onHorizontalDragEnd: (details) {
          if (details.primaryVelocity == null) return;

          if (details.primaryVelocity! < -200) {
            // Swipe left - go forward
            if (widget.currentIndex < widget.moves.length - 1) {
              widget.onMoveSelected(widget.currentIndex + 1);
            }
          } else if (details.primaryVelocity! > 200) {
            // Swipe right - go back
            if (widget.currentIndex >= 0) {
              widget.onMoveSelected(widget.currentIndex - 1);
            }
          }
        },
        child: PageView.builder(
          controller: _pageController,
          itemCount: totalItems,
          onPageChanged: (page) {
            widget.onMoveSelected(page - 1);
          },
          itemBuilder: (context, index) {
            final isStart = index == 0;
            final moveIndex = index - 1;
            final isSelected = moveIndex == widget.currentIndex;

            return _MoveItem(
              text: isStart ? 'Start' : _formatMove(moveIndex),
              isSelected: isSelected,
              onTap: () => widget.onMoveSelected(moveIndex),
            );
          },
        ),
      ),
    );
  }

  String _formatMove(int index) {
    if (index < 0 || index >= widget.moves.length) return '';
    final moveNum = (index ~/ 2) + 1;
    final isWhite = index % 2 == 0;
    return '$moveNum${isWhite ? '.' : '...'} ${widget.moves[index]}';
  }
}

class _MoveItem extends StatelessWidget {
  final String text;
  final bool isSelected;
  final VoidCallback onTap;

  const _MoveItem({
    required this.text,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Center(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? theme.colorScheme.primary.withValues(alpha: 0.15)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            text,
            style: TextStyle(
              fontSize: isSelected ? 16 : 14,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              color: isSelected
                  ? theme.colorScheme.primary
                  : (isDark ? Colors.white60 : Colors.grey.shade600),
            ),
          ),
        ),
      ),
    );
  }
}

/// Compact inline move navigator with 3-move carousel
class CompactMoveNavigator extends StatelessWidget {
  final List<String> moves;
  final int currentIndex;
  final ValueChanged<int> onMoveSelected;

  const CompactMoveNavigator({
    super.key,
    required this.moves,
    required this.currentIndex,
    required this.onMoveSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final canGoBack = currentIndex >= 0;
    final canGoForward = currentIndex < moves.length - 1;

    return Container(
      height: 52,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.white12 : Colors.grey.shade200,
        ),
      ),
      child: Row(
        children: [
          // Back button
          _NavButton(
            icon: Icons.chevron_left,
            enabled: canGoBack,
            onTap: () => onMoveSelected(currentIndex - 1),
          ),

          // 3-move carousel
          Expanded(
            child: GestureDetector(
              onHorizontalDragEnd: (details) {
                if (details.primaryVelocity == null) return;
                if (details.primaryVelocity! < -200 && canGoForward) {
                  onMoveSelected(currentIndex + 1);
                } else if (details.primaryVelocity! > 200 && canGoBack) {
                  onMoveSelected(currentIndex - 1);
                }
              },
              child: Container(
                color: Colors.transparent,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Previous move
                    Expanded(
                      child: _MoveChip(
                        text: _getMoveText(currentIndex - 1),
                        isActive: false,
                        onTap: canGoBack ? () => onMoveSelected(currentIndex - 1) : null,
                      ),
                    ),
                    const SizedBox(width: 4),
                    // Current move (highlighted)
                    Expanded(
                      flex: 2,
                      child: _MoveChip(
                        text: _getMoveText(currentIndex),
                        isActive: true,
                        onTap: null,
                      ),
                    ),
                    const SizedBox(width: 4),
                    // Next move
                    Expanded(
                      child: _MoveChip(
                        text: _getMoveText(currentIndex + 1),
                        isActive: false,
                        onTap: canGoForward ? () => onMoveSelected(currentIndex + 1) : null,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Forward button
          _NavButton(
            icon: Icons.chevron_right,
            enabled: canGoForward,
            onTap: () => onMoveSelected(currentIndex + 1),
          ),
        ],
      ),
    );
  }

  String _getMoveText(int index) {
    if (index < -1) return '';
    if (index == -1) return 'Start';
    if (index >= moves.length) return '';

    final moveNum = (index ~/ 2) + 1;
    final isWhite = index % 2 == 0;
    return '$moveNum${isWhite ? '.' : '...'} ${moves[index]}';
  }
}

class _MoveChip extends StatelessWidget {
  final String text;
  final bool isActive;
  final VoidCallback? onTap;

  const _MoveChip({
    required this.text,
    required this.isActive,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (text.isEmpty) {
      return const SizedBox.shrink();
    }

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: isActive
              ? theme.colorScheme.primary.withOpacity(0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: isActive
              ? Border.all(color: theme.colorScheme.primary.withOpacity(0.3))
              : null,
        ),
        child: Center(
          child: Text(
            text,
            style: TextStyle(
              fontSize: isActive ? 14 : 12,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
              color: isActive
                  ? theme.colorScheme.primary
                  : (isDark ? Colors.white54 : Colors.grey.shade500),
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  const _NavButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          child: Icon(
            icon,
            size: 28,
            color: enabled
                ? theme.colorScheme.primary
                : theme.disabledColor,
          ),
        ),
      ),
    );
  }
}
