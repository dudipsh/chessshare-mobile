import 'package:dartchess/dartchess.dart' show Side;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/colors.dart';
import '../models/puzzle.dart';
import '../providers/puzzle_generator_provider.dart';

class PuzzlesListScreen extends ConsumerWidget {
  const PuzzlesListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final generatorState = ref.watch(puzzleGeneratorProvider);
    final puzzles = generatorState.puzzles;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Puzzles'),
        actions: [
          if (generatorState.isGenerating || generatorState.isLoading)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'refresh') {
                  ref.read(puzzleGeneratorProvider.notifier).clearCacheAndRefresh();
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'refresh',
                  child: Row(
                    children: [
                      Icon(Icons.refresh),
                      SizedBox(width: 8),
                      Text('Reload from server'),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      body: puzzles.isEmpty
          ? _buildEmptyState(context, generatorState)
          : _buildPuzzlesList(context, ref, puzzles),
    );
  }

  Widget _buildEmptyState(BuildContext context, PuzzleGeneratorState state) {
    final theme = Theme.of(context);
    final isLoadingOrGenerating = state.isLoading || state.isGenerating;

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
              child: isLoadingOrGenerating
                  ? const CircularProgressIndicator()
                  : const Icon(
                      Icons.extension_outlined,
                      size: 50,
                      color: AppColors.accent,
                    ),
            ),
            const SizedBox(height: 24),
            Text(
              state.isLoading
                  ? 'Loading puzzles...'
                  : state.isGenerating
                      ? 'Generating puzzles...'
                      : 'No puzzles yet',
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              state.isLoading
                  ? 'Fetching your puzzles from the server'
                  : state.isGenerating
                      ? 'Analyzing your game for tactical moments'
                      : 'Analyze a game to generate personalized puzzles from your missed tactics',
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            if (state.isGenerating) ...[
              const SizedBox(height: 24),
              SizedBox(
                width: 200,
                child: LinearProgressIndicator(
                  value: state.progress,
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                ),
              ),
            ],
            if (state.error != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.error.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  state.error!,
                  style: const TextStyle(color: AppColors.error),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () {
                context.pushNamed('games');
              },
              icon: const Icon(Icons.sports_esports),
              label: const Text('Go to Games'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPuzzlesList(
    BuildContext context,
    WidgetRef ref,
    List<Puzzle> puzzles,
  ) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: puzzles.length,
      itemBuilder: (context, index) {
        final puzzle = puzzles[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _PuzzleCard(
            puzzle: puzzle,
            puzzleNumber: index + 1,
            onTap: () {
              context.pushNamed('puzzle', extra: puzzle);
            },
          ),
        );
      },
    );
  }
}

class _PuzzleCard extends StatelessWidget {
  final Puzzle puzzle;
  final int puzzleNumber;
  final VoidCallback onTap;

  const _PuzzleCard({
    required this.puzzle,
    required this.puzzleNumber,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isDark ? Colors.white12 : Colors.grey.shade200,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Puzzle number
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    '#$puzzleNumber',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // Puzzle info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      puzzle.theme.displayName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${puzzle.sideToMove == Side.white ? "White" : "Black"} to move',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.white60 : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              // Rating
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: _getRatingColor(puzzle.rating).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${puzzle.rating}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: _getRatingColor(puzzle.rating),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right,
                color: isDark ? Colors.white38 : Colors.grey.shade400,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getRatingColor(int rating) {
    if (rating < 1300) return Colors.green;
    if (rating < 1500) return Colors.orange;
    if (rating < 1700) return Colors.deepOrange;
    return Colors.red;
  }
}

