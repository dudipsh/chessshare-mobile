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

/// Compact inline move navigator with arrows
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
      height: 44,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          // Back button
          _NavButton(
            icon: Icons.chevron_left,
            enabled: canGoBack,
            onTap: () => onMoveSelected(currentIndex - 1),
          ),

          // Current move display
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
                child: Center(
                  child: Text(
                    _getCurrentMoveText(),
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
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

  String _getCurrentMoveText() {
    if (currentIndex < 0) return 'Start';
    if (currentIndex >= moves.length) return '';

    final moveNum = (currentIndex ~/ 2) + 1;
    final isWhite = currentIndex % 2 == 0;
    return '$moveNum${isWhite ? '.' : '...'} ${moves[currentIndex]}';
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
