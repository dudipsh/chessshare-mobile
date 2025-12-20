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
    final hasChessCom = chessComUsername != null && chessComUsername!.isNotEmpty;
    final hasLichess = lichessUsername != null && lichessUsername!.isNotEmpty;
    final hasBoth = hasChessCom && hasLichess;

    // Don't show if no accounts
    if (!hasChessCom && !hasLichess) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            // All filter - only show if both platforms are linked
            if (hasBoth) ...[
              _PlatformChip(
                label: 'All',
                isSelected: selectedPlatform == null,
                isDark: isDark,
                onTap: () => onPlatformSelected(null),
              ),
              const SizedBox(width: 8),
            ],

            // Chess.com chip
            if (hasChessCom) ...[
              _PlatformChip(
                label: chessComUsername!,
                icon: '♟',
                platformColor: const Color(0xFF769656),
                isSelected: !hasBoth || selectedPlatform == GamePlatform.chesscom,
                isDark: isDark,
                onTap: () => onPlatformSelected(GamePlatform.chesscom),
              ),
            ],

            if (hasChessCom && hasLichess) const SizedBox(width: 8),

            // Lichess chip
            if (hasLichess) ...[
              _PlatformChip(
                label: lichessUsername!,
                icon: '♞',
                platformColor: Colors.white,
                isSelected: !hasBoth || selectedPlatform == GamePlatform.lichess,
                isDark: isDark,
                onTap: () => onPlatformSelected(GamePlatform.lichess),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PlatformChip extends StatelessWidget {
  final String label;
  final String? icon;
  final Color? platformColor;
  final bool isSelected;
  final bool isDark;
  final VoidCallback onTap;

  const _PlatformChip({
    required this.label,
    this.icon,
    this.platformColor,
    required this.isSelected,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final activeColor = platformColor ?? primaryColor;

    return Material(
      color: isSelected
          ? activeColor.withValues(alpha: 0.2)
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
                    color: isSelected ? activeColor : (isDark ? Colors.white70 : Colors.black54),
                  ),
                ),
                const SizedBox(width: 4),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected ? activeColor : (isDark ? Colors.white70 : Colors.black54),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
