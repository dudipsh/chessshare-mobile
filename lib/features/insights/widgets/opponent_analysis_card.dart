import 'package:flutter/material.dart';

import '../../../app/theme/colors.dart';
import '../models/insights_data.dart';
import 'insights_helpers.dart';

class OpponentAnalysisCard extends StatelessWidget {
  final List<OpponentPerformance> opponentPerformance;

  const OpponentAnalysisCard({super.key, required this.opponentPerformance});

  @override
  Widget build(BuildContext context) {
    if (opponentPerformance.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.people, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(
                  'Performance vs Opponents',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...opponentPerformance.map((perf) => _OpponentRow(performance: perf)),
          ],
        ),
      ),
    );
  }
}

class _OpponentRow extends StatelessWidget {
  final OpponentPerformance performance;

  const _OpponentRow({required this.performance});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(_getCategoryIcon(), size: 20, color: _getCategoryColor()),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _getCategoryLabel(),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  '${performance.gamesCount} games',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${performance.winRate.toStringAsFixed(0)}%',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: getWinRateColor(performance.winRate),
                ),
              ),
              Text(
                '${performance.wins}W/${performance.draws}D/${performance.losses}L',
                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _getCategoryLabel() {
    switch (performance.category) {
      case 'lower':
        return 'Lower Rated (-100+)';
      case 'similar':
        return 'Similar Rating (±100)';
      case 'higher':
        return 'Higher Rated (+100+)';
      default:
        return performance.category;
    }
  }

  IconData _getCategoryIcon() {
    switch (performance.category) {
      case 'lower':
        return Icons.arrow_downward;
      case 'similar':
        return Icons.remove;
      case 'higher':
        return Icons.arrow_upward;
      default:
        return Icons.person;
    }
  }

  Color _getCategoryColor() {
    switch (performance.category) {
      case 'lower':
        return AppColors.success;
      case 'similar':
        return AppColors.warning;
      case 'higher':
        return AppColors.error;
      default:
        return Colors.grey;
    }
  }
}
