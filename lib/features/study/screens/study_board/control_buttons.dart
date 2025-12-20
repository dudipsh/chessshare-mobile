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
          _NavButton(
            icon: Icons.skip_previous_rounded,
            tooltip: 'Back',
            onPressed: moveIndex > 0 ? onBack : null,
            isDark: isDark,
          ),
          _ActionButton(
            icon: Icons.lightbulb_rounded,
            tooltip: 'Hint',
            color: Colors.amber,
            onPressed: isPlaying ? onHint : null,
            isDark: isDark,
          ),
          _ActionButton(
            icon: Icons.sync_rounded,
            tooltip: 'Flip',
            color: AppColors.primary,
            onPressed: onFlip,
            isDark: isDark,
          ),
          _ActionButton(
            icon: Icons.replay_rounded,
            tooltip: 'Reset',
            color: Colors.orange,
            onPressed: onReset,
            isDark: isDark,
          ),
          _NavButton(
            icon: Icons.skip_next_rounded,
            tooltip: 'Next',
            onPressed: moveIndex < totalMoves ? onForward : null,
            isDark: isDark,
          ),
        ],
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool isDark;

  const _NavButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
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
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final Color color;
  final VoidCallback? onPressed;
  final bool isDark;

  const _ActionButton({
    required this.icon,
    required this.tooltip,
    required this.color,
    required this.onPressed,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
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
