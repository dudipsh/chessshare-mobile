import 'package:flutter/material.dart';

import '../../../../app/theme/colors.dart';

class StudyProgressBar extends StatelessWidget {
  final int moveIndex;
  final int totalMoves;
  final double progress;
  final bool isCompleted;
  final bool isDark;

  const StudyProgressBar({
    super.key,
    required this.moveIndex,
    required this.totalMoves,
    required this.progress,
    this.isCompleted = false,
    this.isDark = false,
  });

  @override
  Widget build(BuildContext context) {
    final progressColor = isCompleted ? AppColors.success : AppColors.primary;

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
        children: [
          // Progress icon
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: progressColor.withValues(alpha: isDark ? 0.2 : 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              isCompleted ? Icons.check_circle : Icons.play_circle_outline,
              size: 18,
              color: progressColor,
            ),
          ),
          const SizedBox(width: 12),
          // Progress bar
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isCompleted ? 'Completed!' : 'Progress',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.white70 : Colors.black54,
                      ),
                    ),
                    Text(
                      '$moveIndex / $totalMoves',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: progressColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: isDark ? Colors.white12 : Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                    minHeight: 6,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
