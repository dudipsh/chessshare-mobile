import 'package:flutter/material.dart';

class GameActionButtons extends StatelessWidget {
  final bool canUndo;
  final VoidCallback onUndo;
  final VoidCallback onReset;
  final VoidCallback? onResign;

  const GameActionButtons({
    super.key,
    required this.canUndo,
    required this.onUndo,
    required this.onReset,
    required this.onResign,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: _ActionButton(
              icon: Icons.undo,
              label: 'Undo',
              onPressed: canUndo ? onUndo : null,
              gradientColors: [Colors.grey.shade400, Colors.grey.shade600],
              isDark: isDark,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _ActionButton(
              icon: Icons.refresh,
              label: 'Reset',
              onPressed: onReset,
              gradientColors: [Colors.blue.shade400, Colors.blue.shade600],
              isDark: isDark,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _ActionButton(
              icon: Icons.flag,
              label: 'Resign',
              onPressed: onResign,
              gradientColors: [Colors.red.shade400, Colors.red.shade600],
              isDark: isDark,
            ),
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
