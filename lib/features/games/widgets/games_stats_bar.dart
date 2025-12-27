import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/colors.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/chess_game.dart';
import '../providers/games_provider.dart';

/// Stats bar showing games statistics with player info - matching the design
class GamesStatsBar extends ConsumerWidget {
  final GamePlatform? selectedPlatform;

  const GamesStatsBar({super.key, this.selectedPlatform});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(filteredGamesStatsProvider(selectedPlatform));
    final userProfile = ref.watch(userProfileProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
      child: Column(
        children: [
          // Stats row
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
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
                  valueColor: const Color(0xFFF59E0B), // Amber/yellow color
                  isDark: isDark,
                ),
              ],
            ),
          ),

          // Divider
          Divider(
            height: 1,
            thickness: 1,
            color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.grey.shade200,
            indent: 16,
            endIndent: 16,
          ),

          // Player info row
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Avatar
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey.shade800 : const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.person,
                    color: isDark ? Colors.white70 : AppColors.primary,
                    size: 24,
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
                          color: isDark ? Colors.grey.shade500 : Colors.grey.shade500,
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
                      size: 20,
                      color: AppColors.win,
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${(stats['winRate'] as double).toStringAsFixed(0)}%',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        Text(
                          'Win Rate',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? Colors.grey.shade500 : Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
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
            color: isDark ? Colors.grey.shade500 : Colors.grey.shade500,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}
