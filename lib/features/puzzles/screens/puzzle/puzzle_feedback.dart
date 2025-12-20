import 'package:flutter/material.dart';

import '../../../../app/theme/colors.dart';
import '../../models/puzzle.dart';

class PuzzleFeedback extends StatelessWidget {
  final String feedback;
  final PuzzleState state;

  const PuzzleFeedback({
    super.key,
    required this.feedback,
    required this.state,
  });

  Color _getFeedbackColor() {
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

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: Text(
        feedback,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: _getFeedbackColor(),
        ),
      ),
    );
  }
}

class PuzzleInstructions extends StatelessWidget {
  final PuzzleState state;

  const PuzzleInstructions({super.key, required this.state});

  String _getInstructions() {
    switch (state) {
      case PuzzleState.ready:
        return 'Loading puzzle...';
      case PuzzleState.playing:
        return 'Find the best move';
      case PuzzleState.correct:
        return 'Keep going!';
      case PuzzleState.incorrect:
        return 'That\'s not quite right. Try again!';
      case PuzzleState.completed:
        return 'Puzzle solved!';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Text(
        _getInstructions(),
        style: TextStyle(
          fontSize: 15,
          color: isDark ? Colors.white70 : Colors.grey.shade700,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}
