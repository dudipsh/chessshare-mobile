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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isLoadingOrGenerating = state.isLoading || state.isGenerating;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: isLoadingOrGenerating
                  ? const Center(child: CircularProgressIndicator())
                  : Icon(
                      Icons.extension_outlined,
                      size: 40,
                      color: isDark ? Colors.grey[500] : Colors.grey[400],
                    ),
            ),
            const SizedBox(height: 24),
            Text(
              state.isLoading
                  ? 'Loading puzzles...'
                  : state.isGenerating
                      ? 'Generating puzzles...'
                      : 'No puzzles yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              state.isLoading
                  ? 'Fetching your puzzles from the server'
                  : state.isGenerating
                      ? 'Analyzing your game for tactical moments'
                      : 'Analyze a game to generate personalized puzzles from your missed tactics',
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            if (state.isGenerating) ...[
              const SizedBox(height: 24),
              SizedBox(
                width: 200,
                child: LinearProgressIndicator(
                  value: state.progress,
                  backgroundColor: isDark ? Colors.grey[800] : Colors.grey[200],
                  valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                ),
              ),
            ],
            if (state.error != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  state.error!,
                  style: const TextStyle(color: AppColors.error),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: () {
                context.pushNamed('games');
              },
              icon: const Icon(Icons.sports_esports, size: 18),
              label: const Text('Go to Games'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary),
              ),
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
              // Pass the full list and current index for "Next Puzzle" functionality
              context.pushNamed('puzzle', extra: {
                'puzzle': puzzle,
                'puzzlesList': puzzles,
                'currentIndex': index,
              });
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? Colors.grey[850] : Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            // Puzzle number
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  '#$puzzleNumber',
                  style: const TextStyle(
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
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: puzzle.sideToMove == Side.white ? Colors.white : Colors.black,
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${puzzle.sideToMove == Side.white ? "White" : "Black"} to move',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Rating
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: _getRatingColor(puzzle.rating).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.star, size: 14, color: _getRatingColor(puzzle.rating)),
                  const SizedBox(width: 4),
                  Text(
                    '${puzzle.rating}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: _getRatingColor(puzzle.rating),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.chevron_right,
              color: isDark ? Colors.grey[600] : Colors.grey[400],
            ),
          ],
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

