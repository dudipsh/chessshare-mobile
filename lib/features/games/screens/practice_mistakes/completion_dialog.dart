import 'package:flutter/material.dart';

import '../../../../app/theme/colors.dart';

void showPracticeCompletionDialog({
  required BuildContext context,
  required int correctCount,
  required int total,
  required VoidCallback onTryAgain,
  required VoidCallback onDone,
}) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      title: const Text('Practice Complete!'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.emoji_events, size: 64, color: AppColors.primary),
          const SizedBox(height: 16),
          Text(
            '$correctCount / $total correct',
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Accuracy: ${(correctCount / total * 100).toStringAsFixed(0)}%',
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: onTryAgain, child: const Text('Try Again')),
        ElevatedButton(onPressed: onDone, child: const Text('Done')),
      ],
    ),
  );
}
