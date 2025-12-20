import 'package:flutter/material.dart';

import '../../../../app/theme/colors.dart';

enum PracticeState { ready, correct, wrong, showingSolution }

class FeedbackMessage extends StatelessWidget {
  final String message;
  final PracticeState state;

  const FeedbackMessage({
    super.key,
    required this.message,
    required this.state,
  });

  @override
  Widget build(BuildContext context) {
    final isCorrect = state == PracticeState.correct;
    final isWrong = state == PracticeState.wrong || state == PracticeState.showingSolution;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: isCorrect
            ? AppColors.success.withValues(alpha: 0.15)
            : isWrong
                ? AppColors.error.withValues(alpha: 0.15)
                : Colors.grey.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            isCorrect ? Icons.check_circle : isWrong ? Icons.error : Icons.info,
            color: isCorrect ? AppColors.success : isWrong ? AppColors.error : Colors.grey,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: isCorrect ? AppColors.success : isWrong ? AppColors.error : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
