import 'package:flutter/material.dart';

import '../../../app/theme/colors.dart';
import '../models/insights_data.dart';
import 'insights_helpers.dart';

class SummaryCard extends StatelessWidget {
  final InsightsSummary summary;

  const SummaryCard({super.key, required this.summary});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.analytics, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(
                  'Overview',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: StatItem(
                    label: 'Games Analyzed',
                    value: '${summary.totalGames}',
                    icon: Icons.sports_esports,
                  ),
                ),
                Expanded(
                  child: StatItem(
                    label: 'Overall Accuracy',
                    value: '${summary.overallAccuracy.toStringAsFixed(1)}%',
                    icon: Icons.gps_fixed,
                    valueColor: getAccuracyColor(summary.overallAccuracy),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
