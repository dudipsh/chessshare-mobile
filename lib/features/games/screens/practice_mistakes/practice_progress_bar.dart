import 'package:flutter/material.dart';

import '../../../../app/theme/colors.dart';

class PracticeProgressBar extends StatelessWidget {
  final int currentIndex;
  final int total;
  final int correctCount;

  const PracticeProgressBar({
    super.key,
    required this.currentIndex,
    required this.total,
    required this.correctCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$correctCount correct',
                style: TextStyle(color: AppColors.success, fontWeight: FontWeight.w500),
              ),
              Text(
                '${total - currentIndex - 1} remaining',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: (currentIndex + 1) / total,
            backgroundColor: Colors.grey[300],
            valueColor: AlwaysStoppedAnimation(AppColors.primary),
          ),
        ],
      ),
    );
  }
}
