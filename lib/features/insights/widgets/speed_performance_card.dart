import 'package:flutter/material.dart';

import '../../../app/theme/colors.dart';
import '../models/insights_data.dart';
import 'insights_helpers.dart';

class SpeedPerformanceCard extends StatelessWidget {
  final List<PerformanceStats> speedPerformance;

  const SpeedPerformanceCard({super.key, required this.speedPerformance});

  @override
  Widget build(BuildContext context) {
    if (speedPerformance.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.speed, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(
                  'Performance by Time Control',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...speedPerformance.map((stats) => _SpeedStatRow(stats: stats)),
          ],
        ),
      ),
    );
  }
}

class _SpeedStatRow extends StatelessWidget {
  final PerformanceStats stats;

  const _SpeedStatRow({required this.stats});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(_getSpeedIcon(stats.category), size: 20, color: Colors.grey[600]),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _formatSpeedName(stats.category),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  '${stats.gamesCount} games',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${stats.avgAccuracy.toStringAsFixed(1)}%',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: getAccuracyColor(stats.avgAccuracy),
                ),
              ),
              Text(
                '${stats.winRate.toStringAsFixed(0)}% win',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ),
        ],
      ),
    );
  }

  IconData _getSpeedIcon(String category) {
    switch (category) {
      case 'bullet':
        return Icons.bolt;
      case 'blitz':
        return Icons.flash_on;
      case 'rapid':
        return Icons.timer;
      case 'classical':
        return Icons.hourglass_bottom;
      default:
        return Icons.schedule;
    }
  }

  String _formatSpeedName(String category) {
    return category[0].toUpperCase() + category.substring(1);
  }
}
