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

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = getFeedbackColor(puzzleState.state);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withValues(alpha: isDark ? 0.2 : 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              getFeedbackIcon(puzzleState.state),
              size: 18,
              color: color,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              puzzleState.feedback!,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
