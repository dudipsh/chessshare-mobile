import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/colors.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/chess_game.dart';
import '../providers/games_provider.dart';

/// Stats bar showing games statistics with player info - matching the design
class GamesStatsBar extends ConsumerWidget {
  final GamePlatform? selectedPlatform;
  final String? chessComUsername;
  final String? lichessUsername;
  final ValueChanged<GamePlatform?>? onPlatformSelected;

  const GamesStatsBar({
    super.key,
    this.selectedPlatform,
    this.chessComUsername,
    this.lichessUsername,
    this.onPlatformSelected,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(filteredGamesStatsProvider(selectedPlatform));
    final userProfile = ref.watch(userProfileProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final hasChessCom = chessComUsername != null && chessComUsername!.isNotEmpty;
    final hasLichess = lichessUsername != null && lichessUsername!.isNotEmpty;
    final hasBoth = hasChessCom && hasLichess;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.1),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Top section with gradient and stats
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isDark
                      ? [
                          const Color(0xFF2D3A2D),
                          const Color(0xFF1E2A1E),
                        ]
                      : [
                          const Color(0xFFE8F5E9),
                          const Color(0xFFF1F8E9),
                        ],
                ),
              ),
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _StatItem(
                    value: '${stats['total']}',
                    label: 'GAMES',
                    valueColor: isDark ? Colors.white : Colors.black87,
                    isDark: isDark,
                  ),
                  _StatItem(
                    value: '${stats['wins']}',
                    label: 'WINS',
                    valueColor: AppColors.win,
                    isDark: isDark,
                  ),
                  _StatItem(
                    value: '${stats['losses']}',
                    label: 'LOSSES',
                    valueColor: AppColors.loss,
                    isDark: isDark,
                  ),
                  _StatItem(
                    value: '${stats['draws']}',
                    label: 'DRAWS',
                    valueColor: const Color(0xFFF59E0B),
                    isDark: isDark,
                  ),
                ],
              ),
            ),

            // Bottom section with player info and platform filter
            Container(
              color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Player info row
                  Row(
                    children: [
                      // Avatar
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.grey.shade800
                              : const Color(0xFFE8F5E9),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          Icons.person,
                          color: isDark ? Colors.white70 : AppColors.primary,
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Player name
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'PLAYER',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade500,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              userProfile?.fullName ?? 'Player',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Win rate
                      Row(
                        children: [
                          Icon(
                            Icons.trending_up,
                            size: 22,
                            color: AppColors.win,
                          ),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '${(stats['winRate'] as double).toStringAsFixed(0)}%',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                              ),
                              Text(
                                'Win Rate',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),

                  // Platform filter (only show if we have accounts and callback)
                  if ((hasChessCom || hasLichess) && onPlatformSelected != null) ...[
                    const SizedBox(height: 16),
                    Divider(
                      height: 1,
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.1)
                          : Colors.grey.shade200,
                    ),
                    const SizedBox(height: 12),
                    _PlatformFilter(
                      chessComUsername: chessComUsername,
                      lichessUsername: lichessUsername,
                      selectedPlatform: selectedPlatform,
                      onPlatformSelected: onPlatformSelected!,
                      isDark: isDark,
                      hasBoth: hasBoth,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String value;
  final String label;
  final Color valueColor;
  final bool isDark;

  const _StatItem({
    required this.value,
    required this.label,
    required this.valueColor,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: valueColor,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w500,
            color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}

class _PlatformFilter extends StatelessWidget {
  final String? chessComUsername;
  final String? lichessUsername;
  final GamePlatform? selectedPlatform;
  final ValueChanged<GamePlatform?> onPlatformSelected;
  final bool isDark;
  final bool hasBoth;

  const _PlatformFilter({
    required this.chessComUsername,
    required this.lichessUsername,
    required this.selectedPlatform,
    required this.onPlatformSelected,
    required this.isDark,
    required this.hasBoth,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          // All filter - only show if both platforms are linked
          if (hasBoth) ...[
            _FilterChip(
              label: 'All',
              isSelected: selectedPlatform == null,
              isDark: isDark,
              onTap: () => onPlatformSelected(null),
            ),
            const SizedBox(width: 8),
          ],

          // Chess.com chip
          if (chessComUsername != null && chessComUsername!.isNotEmpty) ...[
            _FilterChip(
              label: chessComUsername!,
              icon: '♟',
              platformColor: const Color(0xFF769656),
              isSelected: !hasBoth || selectedPlatform == GamePlatform.chesscom,
              isDark: isDark,
              onTap: () => onPlatformSelected(GamePlatform.chesscom),
            ),
          ],

          if (hasBoth) const SizedBox(width: 8),

          // Lichess chip
          if (lichessUsername != null && lichessUsername!.isNotEmpty) ...[
            _FilterChip(
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
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final String? icon;
  final Color? platformColor;
  final bool isSelected;
  final bool isDark;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    this.icon,
    this.platformColor,
    required this.isSelected,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final activeColor = platformColor ?? AppColors.primary;

    return Material(
      color: isSelected
          ? activeColor.withValues(alpha: isDark ? 0.3 : 0.15)
          : (isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey.shade100),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Text(
                  icon!,
                  style: TextStyle(
                    fontSize: 14,
                    color: isSelected
                        ? (isDark ? Colors.white : activeColor)
                        : (isDark ? Colors.white60 : Colors.black45),
                  ),
                ),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected
                      ? (isDark ? Colors.white : activeColor)
                      : (isDark ? Colors.white60 : Colors.black45),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
