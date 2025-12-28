import 'package:flutter/material.dart';

import '../../../../app/theme/colors.dart';

/// Control buttons for Study board with modern card design.
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
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _NavButton(
            icon: Icons.keyboard_double_arrow_left,
            onPressed: moveIndex > 0 ? onBack : null,
            isDark: isDark,
          ),
          _NavButton(
            icon: Icons.lightbulb_outline,
            onPressed: isPlaying ? onHint : null,
            isDark: isDark,
            activeColor: Colors.amber,
          ),
          // Progress counter
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary.withValues(alpha: isDark ? 0.3 : 0.15),
                  AppColors.primaryLight.withValues(alpha: isDark ? 0.2 : 0.08),
                ],
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$moveIndex / $totalMoves',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : AppColors.primary,
              ),
            ),
          ),
          _NavButton(
            icon: Icons.sync_rounded,
            onPressed: onFlip,
            isDark: isDark,
          ),
          _NavButton(
            icon: Icons.keyboard_double_arrow_right,
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
  final VoidCallback? onPressed;
  final bool isDark;
  final Color? activeColor;

  const _NavButton({
    required this.icon,
    this.onPressed,
    required this.isDark,
    this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    final isEnabled = onPressed != null;
    final color = activeColor ?? (isDark ? Colors.white : Colors.black87);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: isEnabled ? 0.1 : 0.05)
                : Colors.grey.withValues(alpha: isEnabled ? 0.1 : 0.05),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            size: 22,
            color: isEnabled
                ? color
                : (isDark ? Colors.white24 : Colors.black26),
          ),
        ),
      ),
    );
  }
}
