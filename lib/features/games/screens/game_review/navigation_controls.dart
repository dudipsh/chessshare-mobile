import 'package:flutter/material.dart';

import '../../../../app/theme/colors.dart';

class NavigationControls extends StatelessWidget {
  final int currentMoveIndex;
  final int totalMoves;
  final VoidCallback onFirst;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onLast;
  final VoidCallback? onPlay;
  final bool isPlaying;

  const NavigationControls({
    super.key,
    required this.currentMoveIndex,
    required this.totalMoves,
    required this.onFirst,
    required this.onPrevious,
    required this.onNext,
    required this.onLast,
    this.onPlay,
    this.isPlaying = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
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
            onPressed: onFirst,
            isDark: isDark,
            isEnabled: currentMoveIndex > 0,
          ),
          _NavButton(
            icon: Icons.chevron_left,
            onPressed: onPrevious,
            isDark: isDark,
            isEnabled: currentMoveIndex > 0,
            isLarge: true,
          ),
          // Play/Pause button
          _PlayButton(
            isPlaying: isPlaying,
            onTap: onPlay,
            isDark: isDark,
          ),
          _NavButton(
            icon: Icons.chevron_right,
            onPressed: onNext,
            isDark: isDark,
            isEnabled: currentMoveIndex < totalMoves,
            isLarge: true,
          ),
          _NavButton(
            icon: Icons.keyboard_double_arrow_right,
            onPressed: onLast,
            isDark: isDark,
            isEnabled: currentMoveIndex < totalMoves,
          ),
        ],
      ),
    );
  }
}

class _PlayButton extends StatelessWidget {
  final bool isPlaying;
  final VoidCallback? onTap;
  final bool isDark;

  const _PlayButton({
    required this.isPlaying,
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 56,
          height: 40,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isPlaying
                  ? [
                      Colors.orange.withValues(alpha: isDark ? 0.3 : 0.2),
                      Colors.deepOrange.withValues(alpha: isDark ? 0.2 : 0.12),
                    ]
                  : [
                      AppColors.primary.withValues(alpha: isDark ? 0.3 : 0.15),
                      AppColors.primaryLight.withValues(alpha: isDark ? 0.2 : 0.08),
                    ],
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(
            isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
            size: 28,
            color: isPlaying
                ? (isDark ? Colors.orange.shade300 : Colors.deepOrange)
                : (isDark ? Colors.white : AppColors.primary),
          ),
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final bool isDark;
  final bool isEnabled;
  final bool isLarge;

  const _NavButton({
    required this.icon,
    required this.onPressed,
    required this.isDark,
    this.isEnabled = true,
    this.isLarge = false,
  });

  @override
  Widget build(BuildContext context) {
    final size = isLarge ? 40.0 : 36.0;
    final iconSize = isLarge ? 26.0 : 20.0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isEnabled ? onPressed : null,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: isEnabled ? 0.1 : 0.05)
                : Colors.grey.withValues(alpha: isEnabled ? 0.1 : 0.05),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            size: iconSize,
            color: isEnabled
                ? (isDark ? Colors.white : Colors.black87)
                : (isDark ? Colors.white24 : Colors.black26),
          ),
        ),
      ),
    );
  }
}
