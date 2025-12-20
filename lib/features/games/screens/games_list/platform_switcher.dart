import 'package:flutter/material.dart';

import '../../models/chess_game.dart';

class PlatformSwitcher extends StatelessWidget {
  final String? chessComUsername;
  final String? lichessUsername;
  final GamePlatform? selectedPlatform;
  final ValueChanged<GamePlatform?> onPlatformSelected;

  const PlatformSwitcher({
    super.key,
    required this.chessComUsername,
    required this.lichessUsername,
    required this.selectedPlatform,
    required this.onPlatformSelected,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          _PlatformChip(
            label: 'All',
            isSelected: selectedPlatform == null,
            isDark: isDark,
            onTap: () => onPlatformSelected(null),
          ),
          const SizedBox(width: 8),
          _PlatformChip(
            label: chessComUsername ?? 'Chess.com',
            icon: '\u265f',
            isSelected: selectedPlatform == GamePlatform.chesscom,
            isDark: isDark,
            onTap: () => onPlatformSelected(GamePlatform.chesscom),
          ),
          const SizedBox(width: 8),
          _PlatformChip(
            label: lichessUsername ?? 'Lichess',
            icon: '\u265e',
            isSelected: selectedPlatform == GamePlatform.lichess,
            isDark: isDark,
            onTap: () => onPlatformSelected(GamePlatform.lichess),
          ),
        ],
      ),
    );
  }
}

class _PlatformChip extends StatelessWidget {
  final String label;
  final String? icon;
  final bool isSelected;
  final bool isDark;
  final VoidCallback onTap;

  const _PlatformChip({
    required this.label,
    this.icon,
    required this.isSelected,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Material(
      color: isSelected
          ? primaryColor.withValues(alpha: 0.2)
          : (isDark ? Colors.white10 : Colors.grey.shade200),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Text(
                  icon!,
                  style: TextStyle(
                    fontSize: 14,
                    color: isSelected ? primaryColor : (isDark ? Colors.white70 : Colors.black54),
                  ),
                ),
                const SizedBox(width: 4),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected ? primaryColor : (isDark ? Colors.white70 : Colors.black54),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
