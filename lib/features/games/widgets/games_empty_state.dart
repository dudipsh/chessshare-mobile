import 'package:flutter/material.dart';

import '../../../app/theme/colors.dart';

/// Empty state shown when user has no games
class GamesEmptyState extends StatelessWidget {
  final VoidCallback onImportPressed;

  const GamesEmptyState({
    super.key,
    required this.onImportPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: AppColors.accent.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.sports_esports_outlined,
                size: 50,
                color: AppColors.accent,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No games yet',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Import your games from Chess.com or Lichess to start analyzing',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: onImportPressed,
              icon: const Icon(Icons.add),
              label: const Text('Import Games'),
            ),
          ],
        ),
      ),
    );
  }
}

/// State shown when filter returns no results
class GamesNoResultsState extends StatelessWidget {
  final VoidCallback onClearFilters;

  const GamesNoResultsState({
    super.key,
    required this.onClearFilters,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: Colors.white.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'No games match your filters',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: onClearFilters,
              child: const Text('Clear Filters'),
            ),
          ],
        ),
      ),
    );
  }
}
