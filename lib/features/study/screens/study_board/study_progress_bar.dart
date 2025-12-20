import 'package:flutter/material.dart';

import '../../../../app/theme/colors.dart';

class StudyProgressBar extends StatelessWidget {
  final int moveIndex;
  final int totalMoves;
  final double progress;
  final bool isCompleted;

  const StudyProgressBar({
    super.key,
    required this.moveIndex,
    required this.totalMoves,
    required this.progress,
    this.isCompleted = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Text('$moveIndex/$totalMoves', style: const TextStyle(fontSize: 12)),
          const SizedBox(width: 8),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: Colors.grey.shade300,
                valueColor: AlwaysStoppedAnimation<Color>(
                  isCompleted ? AppColors.success : AppColors.primary,
                ),
                minHeight: 6,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
