import 'package:flutter/material.dart';

import '../../../app/theme/colors.dart';
import '../models/insights_data.dart';
import 'insights_helpers.dart';

class OpeningsCard extends StatelessWidget {
  final List<OpeningStats> openings;

  const OpeningsCard({super.key, required this.openings});

  @override
  Widget build(BuildContext context) {
    if (openings.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final topOpenings = openings.take(5).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.menu_book, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(
                  'Top Openings',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...topOpenings.map((opening) => _OpeningRow(opening: opening)),
          ],
        ),
      ),
    );
  }
}

class _OpeningRow extends StatelessWidget {
  final OpeningStats opening;

  const _OpeningRow({required this.opening});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.book.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              opening.eco,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppColors.book,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  opening.name,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${opening.gamesCount} games',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${opening.winRate.toStringAsFixed(0)}%',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: getWinRateColor(opening.winRate),
                    ),
                  ),
                  Icon(
                    Icons.emoji_events,
                    size: 14,
                    color: getWinRateColor(opening.winRate),
                  ),
                ],
              ),
              Text(
                '${opening.wins}W/${opening.draws}D/${opening.losses}L',
                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
