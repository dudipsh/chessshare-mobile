import 'package:flutter/material.dart';

import '../../../app/theme/colors.dart';
import '../models/puzzle.dart';
import '../providers/puzzle_provider.dart';

Color getFeedbackColor(PuzzleState state) {
  switch (state) {
    case PuzzleState.correct:
    case PuzzleState.completed:
      return AppColors.success;
    case PuzzleState.incorrect:
      return AppColors.error;
    default:
      return Colors.grey;
  }
}

IconData getFeedbackIcon(PuzzleState state) {
  switch (state) {
    case PuzzleState.correct:
    case PuzzleState.completed:
      return Icons.check;
    case PuzzleState.incorrect:
      return Icons.close;
    default:
      return Icons.info;
  }
}

String getInstructions(PuzzleState state) {
  switch (state) {
    case PuzzleState.ready:
      return 'Loading puzzle...';
    case PuzzleState.playing:
      return 'Find the best move';
    case PuzzleState.correct:
      return 'Great! Keep going...';
    case PuzzleState.incorrect:
      return 'Try again';
    case PuzzleState.completed:
      return 'Puzzle solved! Claim your reward.';
  }
}

class PuzzleFeedbackBanner extends StatelessWidget {
  final PuzzleSolveState puzzleState;

  const PuzzleFeedbackBanner({super.key, required this.puzzleState});

  @override
  Widget build(BuildContext context) {
    if (puzzleState.feedback == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: getFeedbackColor(puzzleState.state),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              getFeedbackIcon(puzzleState.state),
              color: Colors.white,
            ),
            const SizedBox(width: 8),
            Text(
              puzzleState.feedback!,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
