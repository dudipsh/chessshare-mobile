import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/colors.dart';
import '../providers/games_provider.dart';

/// Stats bar showing games statistics
class GamesStatsBar extends ConsumerWidget {
  const GamesStatsBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(gamesStatsProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        border: Border(
          bottom: BorderSide(color: theme.dividerColor),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _StatItem(
            value: '${stats['total']}',
            label: 'Games',
            color: isDark ? Colors.white70 : Colors.black87,
          ),
          _StatItem(
            value: '${stats['wins']}',
            label: 'Wins',
            color: AppColors.win,
          ),
          _StatItem(
            value: '${stats['losses']}',
            label: 'Losses',
            color: AppColors.loss,
          ),
          _StatItem(
            value: '${stats['draws']}',
            label: 'Draws',
            color: AppColors.draw,
          ),
          _StatItem(
            value: '${(stats['winRate'] as double).toStringAsFixed(0)}%',
            label: 'Win Rate',
            color: AppColors.accent,
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String value;
  final String label;
  final Color color;

  const _StatItem({
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: theme.colorScheme.onSurface.withOpacity(0.6),
          ),
        ),
      ],
    );
  }
}
