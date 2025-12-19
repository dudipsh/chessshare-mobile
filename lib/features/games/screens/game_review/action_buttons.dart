import 'package:flutter/material.dart';

import '../../../../app/theme/colors.dart';
import '../../models/move_classification.dart';

class ReviewActionButtons extends StatelessWidget {
  final int mistakesCount;
  final VoidCallback? onPractice;
  final VoidCallback onPlayEngine;

  const ReviewActionButtons({
    super.key,
    required this.mistakesCount,
    this.onPractice,
    required this.onPlayEngine,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          // Practice button
          Expanded(
            child: SizedBox(
              height: 36,
              child: ElevatedButton.icon(
                onPressed: mistakesCount > 0 ? onPractice : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: MoveClassification.mistake.color,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                icon: const Icon(Icons.fitness_center, size: 16),
                label: Text(
                  'Practice ($mistakesCount)',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Play vs Engine button
          Expanded(
            child: SizedBox(
              height: 36,
              child: ElevatedButton.icon(
                onPressed: onPlayEngine,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                icon: const Icon(Icons.smart_toy, size: 16),
                label: const Text(
                  'Play Engine',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
