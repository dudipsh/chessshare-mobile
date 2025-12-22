import 'package:flutter/material.dart';

import '../../../../app/theme/colors.dart';

class ControlButtons extends StatelessWidget {
  final int moveIndex;
  final int totalMoves;
  final bool isPlaying;
  final VoidCallback onBack;
  final VoidCallback onForward;
  final VoidCallback? onHint;
  final VoidCallback onFlip;
  final VoidCallback onReset;
  final bool isDark;

  const ControlButtons({
    super.key,
    required this.moveIndex,
    required this.totalMoves,
    required this.isPlaying,
    required this.onBack,
    required this.onForward,
    this.onHint,
    required this.onFlip,
    required this.onReset,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildNavButton(Icons.skip_previous_rounded, 'Back', moveIndex > 0 ? onBack : null),
          _buildActionButton(Icons.lightbulb_rounded, 'Hint', Colors.amber, isPlaying ? onHint : null),
          _buildActionButton(Icons.sync_rounded, 'Flip', AppColors.primary, onFlip),
          _buildActionButton(Icons.replay_rounded, 'Reset', Colors.orange, onReset),
          _buildNavButton(Icons.skip_next_rounded, 'Next', moveIndex < totalMoves ? onForward : null),
        ],
      ),
    );
  }

  Widget _buildNavButton(IconData icon, String tooltip, VoidCallback? onPressed) {
    final isEnabled = onPressed != null;

    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: isEnabled
                  ? (isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.05))
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              size: 28,
              color: isEnabled
                  ? (isDark ? Colors.white : Colors.black87)
                  : (isDark ? Colors.white24 : Colors.grey.shade400),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton(IconData icon, String tooltip, Color color, VoidCallback? onPressed) {
    final isEnabled = onPressed != null;

    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isEnabled ? color.withValues(alpha: 0.15) : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              border: isEnabled ? Border.all(color: color.withValues(alpha: 0.3), width: 1) : null,
            ),
            child: Icon(
              icon,
              size: 22,
              color: isEnabled ? color : (isDark ? Colors.white24 : Colors.grey.shade400),
            ),
          ),
        ),
      ),
    );
  }
}
