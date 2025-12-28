import 'package:flutter/material.dart';

class PuzzleActionButtons extends StatelessWidget {
  final VoidCallback onTryAgain;
  final VoidCallback onDone;
  final VoidCallback? onNextPuzzle;

  const PuzzleActionButtons({
    super.key,
    required this.onTryAgain,
    required this.onDone,
    this.onNextPuzzle,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Next Puzzle button - primary action when available
          if (onNextPuzzle != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _ActionButton(
                icon: Icons.arrow_forward,
                label: 'Next Puzzle',
                onPressed: onNextPuzzle,
                gradientColors: [Colors.green.shade400, Colors.teal.shade600],
                isDark: isDark,
              ),
            ),
          // Secondary actions row
          Row(
            children: [
              Expanded(
                child: _ActionButton(
                  icon: Icons.refresh,
                  label: 'Try Again',
                  onPressed: onTryAgain,
                  gradientColors: [Colors.grey.shade400, Colors.grey.shade600],
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ActionButton(
                  icon: Icons.check,
                  label: 'Done',
                  onPressed: onDone,
                  gradientColors: [Colors.blue.shade400, Colors.blue.shade600],
                  isDark: isDark,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final List<Color> gradientColors;
  final bool isDark;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    required this.gradientColors,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final isEnabled = onPressed != null;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          height: 48,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: gradientColors
                    .map((c) => c.withValues(alpha: isEnabled ? 0.15 : 0.05))
                    .toList(),
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: isEnabled
                      ? gradientColors[1]
                      : (isDark ? Colors.white24 : Colors.grey.shade400),
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isEnabled
                        ? (isDark ? gradientColors[0] : gradientColors[1])
                        : (isDark ? Colors.white24 : Colors.grey.shade400),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
