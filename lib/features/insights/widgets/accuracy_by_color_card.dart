import 'package:flutter/material.dart';

import '../../../app/theme/colors.dart';
import '../models/insights_data.dart';
import 'insights_helpers.dart';

class AccuracyByColorCard extends StatelessWidget {
  final List<PerformanceStats> colorPerformance;

  const AccuracyByColorCard({super.key, required this.colorPerformance});

  @override
  Widget build(BuildContext context) {
    if (colorPerformance.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final white = colorPerformance.where((p) => p.category == 'white').firstOrNull;
    final black = colorPerformance.where((p) => p.category == 'black').firstOrNull;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.contrast, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(
                  'Performance by Color',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                if (white != null)
                  Expanded(child: _ColorStatCard(stats: white, isWhite: true)),
                if (white != null && black != null) const SizedBox(width: 12),
                if (black != null)
                  Expanded(child: _ColorStatCard(stats: black, isWhite: false)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ColorStatCard extends StatelessWidget {
  final PerformanceStats stats;
  final bool isWhite;

  const _ColorStatCard({required this.stats, required this.isWhite});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isWhite
            ? (isDark ? Colors.grey[800] : Colors.grey[100])
            : (isDark ? Colors.grey[900] : Colors.grey[800]),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.grey.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: isWhite ? Colors.white : Colors.black,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.grey),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            isWhite ? 'White' : 'Black',
            style: TextStyle(
              color: isWhite
                  ? (isDark ? Colors.white : Colors.black)
                  : (isDark ? Colors.white70 : Colors.white),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${stats.avgAccuracy.toStringAsFixed(1)}%',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: getAccuracyColor(stats.avgAccuracy),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${stats.wins}W / ${stats.draws}D / ${stats.losses}L',
            style: TextStyle(
              fontSize: 12,
              color: isWhite
                  ? (isDark ? Colors.white60 : Colors.black54)
                  : (isDark ? Colors.white54 : Colors.white70),
            ),
          ),
        ],
      ),
    );
  }
}
