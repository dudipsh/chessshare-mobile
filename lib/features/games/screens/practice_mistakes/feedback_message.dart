import 'package:flutter/material.dart';

import '../../../../app/theme/colors.dart';

enum PracticeState { ready, correct, wrong, showingSolution }

class FeedbackMessage extends StatelessWidget {
  final String message;
  final PracticeState state;
  final bool isDark;

  const FeedbackMessage({
    super.key,
    required this.message,
    required this.state,
    this.isDark = false,
  });

  @override
  Widget build(BuildContext context) {
    final isCorrect = state == PracticeState.correct;
    final isWrong = state == PracticeState.wrong || state == PracticeState.showingSolution;
    final color = isCorrect ? AppColors.success : isWrong ? AppColors.error : Colors.grey;

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
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withValues(alpha: isDark ? 0.2 : 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              isCorrect ? Icons.check_circle : isWrong ? Icons.close : Icons.info,
              size: 18,
              color: color,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
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
