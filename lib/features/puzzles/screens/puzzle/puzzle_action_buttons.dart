import 'package:flutter/material.dart';

import '../../../../app/theme/colors.dart';

class PuzzleActionButtons extends StatelessWidget {
  final VoidCallback onTryAgain;
  final VoidCallback onDone;
  final VoidCallback? onNextPuzzle;

  const PuzzleActionButtons({
    super.key,
    required this.onTryAgain,
    required this.onDone,
    this.onNextPuzzle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Next Puzzle button - primary action when available
          if (onNextPuzzle != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: onNextPuzzle,
                  icon: const Icon(Icons.arrow_forward),
                  label: const Text('Next Puzzle'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ),
          // Secondary actions row
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onTryAgain,
                  child: const Text('Try Again'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: onDone,
                  child: const Text('Done'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
