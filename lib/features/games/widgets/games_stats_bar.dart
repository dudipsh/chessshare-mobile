import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/colors.dart';
import '../models/chess_game.dart';
import '../providers/games_provider.dart';

/// Stats bar showing games statistics - styled to match Profile
class GamesStatsBar extends ConsumerWidget {
  final GamePlatform? selectedPlatform;

  const GamesStatsBar({super.key, this.selectedPlatform});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(filteredGamesStatsProvider(selectedPlatform));
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[850] : Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _StatItem(
            value: '${stats['total']}',
            label: 'Games',
            icon: Icons.sports_esports,
            iconColor: AppColors.primary,
            isDark: isDark,
          ),
          _StatItem(
            value: '${stats['wins']}',
            label: 'Wins',
            icon: Icons.emoji_events,
            iconColor: AppColors.win,
            isDark: isDark,
          ),
          _StatItem(
            value: '${stats['losses']}',
            label: 'Losses',
            icon: Icons.close,
            iconColor: AppColors.loss,
            isDark: isDark,
          ),
          _StatItem(
            value: '${stats['draws']}',
            label: 'Draws',
            icon: Icons.balance,
            iconColor: AppColors.draw,
            isDark: isDark,
          ),
          _StatItem(
            value: '${(stats['winRate'] as double).toStringAsFixed(0)}%',
            label: 'Win Rate',
            icon: Icons.trending_up,
            iconColor: AppColors.accent,
            isDark: isDark,
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  final Color iconColor;
  final bool isDark;

  const _StatItem({
    required this.value,
    required this.label,
    required this.icon,
    required this.iconColor,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: iconColor, size: 18),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: isDark ? Colors.grey[400] : Colors.grey[600],
          ),
        ),
      ],
    );
  }
}
